import Foundation
import MaroonCore
import Observation

struct CampusSnapshot: Codable {
  var events: [CampusEvent]
  var routes: [BusRoute]
  var stops: [BusStop]
  var fetchedAt: Date
  var transitFetchedAt: Date?
  var warnings: [String]?
}
@Observable @MainActor final class CampusService {
  var events: [CampusEvent] = []
  var routes: [BusRoute] = []
  var stops: [BusStop] = []
  var fetchedAt: Date?
  var loading = false
  var warnings: [String] = []
  var transitFetchedAt: Date?
  var error: String?
  var transitError: String?
  var transitLoading = false
  private var lastTransitAttempt: Date?
  private var lastAttempt: Date?
  private var cache: URL { URL.cachesDirectory.appending(path: "campus.json") }
  init() {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    // A damaged cache must not hide the bundled offline campus snapshot.
    let candidates = [cache, Bundle.main.url(forResource: "campus-data", withExtension: "json")]
    for case let url? in candidates {
      if let data = try? Data(contentsOf: url),
         let snapshot = try? decoder.decode(CampusSnapshot.self, from: data) {
        apply(snapshot)
        break
      }
    }
  }
  private func apply(_ s: CampusSnapshot) {
    events = Self.normalizedEvents(s.events)
    let incomingTransit = s.transitFetchedAt ?? s.fetchedAt
    if transitFetchedAt == nil || incomingTransit >= transitFetchedAt! {
      routes = s.routes
      stops = s.stops
      transitFetchedAt = incomingTransit
    }
    fetchedAt = s.fetchedAt
    warnings = s.warnings ?? []
  }
  static func normalizedEvents(_ events: [CampusEvent]) -> [CampusEvent] {
    events.map { event in
      var event = event
      // LiveWhale sometimes publishes cancellation only in the title.
      event.cancelled = event.cancelled || event.title.range(
        of: #"(?i)(?:^\s*cancel(?:l)?ed(?:\s*[:–—-]|\s*$)|[\[(]\s*cancel(?:l)?ed\s*[\])]|[–—-]\s*cancel(?:l)?ed\s*$)"#,
        options: .regularExpression) != nil
      return event
    }
  }
  func displayEvents(savedIDs: Set<String> = []) -> [CampusEvent] {
    // Keep all source IDs in the cache for existing bookmarks and sports rooms.
    // Only the agenda collapses exact duplicate university listings; a saved
    // listing is the representative so it can still be opened and unsaved.
    var representatives: [CampusDisplayKey: CampusEvent] = [:]
    for event in events {
      let key = CampusDisplayKey(event)
      guard let existing = representatives[key] else { representatives[key] = event; continue }
      let saved = savedIDs.contains(event.id), existingSaved = savedIDs.contains(existing.id)
      if (saved && !existingSaved) || (saved == existingSaved && event.id < existing.id) {
        representatives[key] = event
      }
    }
    return representatives.values.sorted { $0.starts == $1.starts ? $0.id < $1.id : $0.starts < $1.starts }
  }
  func refresh(force: Bool = false) async {
    guard !loading, force || lastAttempt == nil || Date.now.timeIntervalSince(lastAttempt!) > 900
    else { return }
    loading = true
    lastAttempt = .now
    defer { loading = false }
    do {
      // Production reads one shared Supabase cache instead of scraping once per student.
      let snapshot = try await CampusGateway.fetch()
      apply(snapshot)
      error = nil
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .secondsSince1970
      try? encoder.encode(snapshot).write(to: cache, options: .atomic)
    } catch { self.error = "Couldn’t refresh. Showing the most recent saved campus data." }
  }
  func refreshTransit(force: Bool = false) async {
    guard !transitLoading, force || lastTransitAttempt == nil || Date.now.timeIntervalSince(lastTransitAttempt!) > 900 else { return }
    transitLoading = true
    lastTransitAttempt = .now
    defer { transitLoading = false }
    do {
      async let routeRows: [OfficialRoute] = CampusGateway.officialFeed("https://aggiespirit.ts.tamu.edu/News/GetRoutes")
      async let stopRows: [OfficialStop] = CampusGateway.officialFeed("https://aggiespirit.ts.tamu.edu/Home/GetAllBusStops")
      let (newRoutes, newStops) = try await (routeRows, stopRows)
      guard !newRoutes.isEmpty, !newStops.isEmpty else { throw URLError(.zeroByteResource) }
      routes = newRoutes.map { BusRoute(id: $0.routeNumber, name: $0.routeName) }
        .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
      stops = Dictionary(grouping: newStops.filter { (-90...90).contains($0.latitude) && (-180...180).contains($0.longitude) }, by: \.stopCode)
        .compactMap { _, rows in rows.first.map { BusStop(id: $0.stopCode, name: $0.stopName, latitude: $0.latitude, longitude: $0.longitude) } }
        .sorted { $0.name < $1.name }
      transitFetchedAt = .now
      transitError = nil
      warnings.removeAll { $0 == "Routes" || $0 == "Stops" }
      let snapshot = CampusSnapshot(events: events, routes: routes, stops: stops, fetchedAt: fetchedAt ?? .now,
                                    transitFetchedAt: transitFetchedAt, warnings: warnings)
      let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
      try? encoder.encode(snapshot).write(to: cache, options: .atomic)
    } catch {
      transitError = "Couldn’t update routes. Showing the saved catalog; check the live map for service changes."
    }
  }

}
private struct CampusDisplayKey: Hashable {
  var title: String; var category: String; var starts: Date; var ends: Date?
  var allDay: Bool; var location: String; var details: String; var url: String
  var imageURL: String?; var source: String; var cancelled: Bool
  init(_ event: CampusEvent) {
    func whitespace(_ text: String) -> String {
      text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    title = whitespace(event.title); category = event.category; starts = event.starts; ends = event.ends
    allDay = event.allDay; location = whitespace(event.location); details = whitespace(event.details)
    imageURL = event.imageURL; source = event.source; cancelled = event.cancelled
    url = event.url
    // Do not infer equality from a truncated description, unrelated URL, or a
    // different official event slug. These may contain meaningful differences.
    if event.details.count < 1200, var components = URLComponents(string: event.url),
       components.host?.lowercased() == "calendar.tamu.edu" {
      components.path = components.path.replacingOccurrences(
        of: #"(?<=/event/)[0-9]+(?=-|/|$)"#, with: "event", options: .regularExpression)
      url = components.string ?? event.url
    }
  }
}
struct CampusGateway {
  static func officialFeed<T: Decodable>(_ address: String) async throws -> T {
    guard let url = URL(string: address) else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.timeoutInterval = 18
    request.setValue("MaroonSocial/1.0 public transit catalog", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    return try JSONDecoder().decode(T.self, from: data)
  }
  static func fetch() async throws -> CampusSnapshot {
    guard let url = Bundle.main.url(forResource: "Backend", withExtension: "json") else {
      throw URLError(.badURL)
    }
    let config = try JSONDecoder().decode(BackendConfig.self, from: Data(contentsOf: url))
    var request = URLRequest(
      url: config.url.appending(path: "rest/v1/campus_cache").appending(queryItems: [
        URLQueryItem(name: "id", value: "eq.current"),
        URLQueryItem(name: "select", value: "payload"),
      ]))
    request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
    request.timeoutInterval = 15
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }
    struct Row: Decodable { let payload: CampusSnapshot }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    guard let row = try decoder.decode([Row].self, from: data).first else {
      throw URLError(.zeroByteResource)
    }
    return row.payload
  }
}
struct BackendConfig: Codable {
  var url: URL
  var publishableKey: String
}

private struct OfficialRoute: Decodable { let routeNumber: String; let routeName: String }
private struct OfficialStop: Decodable { let stopCode: String; let stopName: String; let latitude: Double; let longitude: Double }
