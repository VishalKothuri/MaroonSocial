import Foundation
import MaroonCore
import Observation

struct SportsMarketQuote: Codable, Equatable {
  let ticker: String
  let title: String
  let bid: Double?
  let ask: Double?
  let last: Double?
  let updatedAt: Date
  let sourceURL: String
  var priceText: String {
    func cents(_ value: Double) -> String { "\(Int((value * 100).rounded()))¢" }
    if let bid, let ask { return "\(cents(bid)) bid · \(cents(ask)) ask" }
    if let bid { return "\(cents(bid)) bid" }
    if let ask { return "\(cents(ask)) ask" }
    return last.map { "\(cents($0)) last trade" } ?? "No current quote"
  }
}
struct SportsGame: Codable, Equatable, Identifiable {
  let id: String
  let sport: String
  let sportSlug: String
  let opponent: String
  let starts: Date
  let timeTBA: Bool
  let homeAway: String
  let status: String
  let aggieScore: Double?
  let opponentScore: Double?
  let result: String?
  let sourceURL: String
  let trackerURL: String?
  let quote: SportsMarketQuote?
  var statusText: String {
    switch status { case "final": "Final"; case "cancelled": "Cancelled"; case "postponed": "Postponed"; default: "Scheduled" }
  }
  var hasScore: Bool { status == "final" && aggieScore != nil && opponentScore != nil }
  var source: URL? { Self.safeURL(sourceURL, hosts: ["12thman.com"]) }
  var tracker: URL? { trackerURL.flatMap { Self.safeURL($0, hosts: ["statb.us", "stats.statbroadcast.com", "www.statbroadcast.com", "12thman.com"]) } }
  static func safeURL(_ value: String, hosts: Set<String>) -> URL? {
    guard let url = URL(string: value), url.scheme == "https", url.user == nil, url.password == nil,
          let host = url.host?.lowercased(), hosts.contains(host) else { return nil }
    return url
  }
}
struct SportsSnapshot: Codable {
  let games: [SportsGame]
  let fetchedAt: Date
  let source: String
  let sourceURL: String
  let livePlayAvailable: Bool
  let warnings: [String]
  /// The campus calendar and athletics are different sources. Ambiguity must
  /// show an unmatched state instead of another team's score.
  func game(for event: CampusEvent) -> SportsGame? {
    guard event.category == "Sports" else { return nil }
    func normalized(_ text: String) -> String {
      text.lowercased().replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)
    }
    let title = " " + normalized(event.title) + " "
    let candidates = games.filter { game in
      let opponent = " " + normalized(game.opponent) + " "
      let sport = " " + normalized(game.sport) + " "
      return title.contains(opponent) && title.contains(sport)
        && abs(game.starts.timeIntervalSince(event.starts)) <= 3 * 3600
    }
    return candidates.count == 1 ? candidates[0] : nil
  }
}
@Observable @MainActor final class SportsService {
  typealias Transport = @MainActor () async throws -> Data
  var snapshot: SportsSnapshot?
  var loading = false
  var error: String?
  private let transport: Transport
  private var lastAttempt: Date?
  init(transport: @escaping Transport) { self.transport = transport }
  convenience init(social: SocialService) {
    self.init { try await social.sendData(endpoint: "sports", action: "snapshot") }
  }
  func refresh(force: Bool = false) async {
    guard !loading, force || lastAttempt == nil || Date.now.timeIntervalSince(lastAttempt!) >= 120 else { return }
    loading = true; lastAttempt = .now
    defer { loading = false }
    do {
      let data = try await transport()
      guard !Task.isCancelled else { return }
      let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
      let value = try decoder.decode(SportsSnapshot.self, from: data)
      guard value.games.count <= 200 else { throw URLError(.cannotParseResponse) }
      snapshot = value; error = nil
    } catch is CancellationError { lastAttempt = nil }
    catch { self.error = "Couldn’t refresh official scores. Try again, or open Texas A&M Athletics." }
  }
}
