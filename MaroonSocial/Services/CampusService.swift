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
  private var lastAttempt: Date?
  private var cache: URL { URL.cachesDirectory.appending(path: "campus.json") }
  init() {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let url =
      FileManager.default.fileExists(atPath: cache.path)
      ? cache : Bundle.main.url(forResource: "campus-data", withExtension: "json")
    if let url, let data = try? Data(contentsOf: url),
      let snapshot = try? decoder.decode(CampusSnapshot.self, from: data)
    {
      apply(snapshot)
    }
  }
  private func apply(_ s: CampusSnapshot) {
    events = s.events
    routes = s.routes
    stops = s.stops
    fetchedAt = s.fetchedAt
    warnings = s.warnings ?? []
    transitFetchedAt = s.transitFetchedAt ?? s.fetchedAt
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
}
struct CampusGateway {
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
