import Foundation
import MaroonCore
import SwiftUI
import UIKit

/// Any JSON value, kept exactly as the server sent it. Paging cursors of `posts.search` and
/// `feed.top` are opaque: the client sends them back verbatim and never reads them.
enum JSONValue: Codable, Hashable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() { self = .null }
    else if let value = try? container.decode(Bool.self) { self = .bool(value) }
    else if let value = try? container.decode(Double.self) { self = .number(value) }
    else if let value = try? container.decode(String.self) { self = .string(value) }
    else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
    else { self = .object(try container.decode([String: JSONValue].self)) }
  }
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null: try container.encodeNil()
    case .bool(let value): try container.encode(value)
    case .number(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    }
  }
  /// The value as `JSONSerialization` writes it (request payloads).
  var foundation: Any {
    switch self {
    case .null: return NSNull()
    case .bool(let value): return value
    case .number(let value):
      // Whole numbers go back as integers, so an offset cursor reads `30`, not `30.0`.
      if value.rounded() == value, abs(value) < 1e15 { return Int(value) }
      return value
    case .string(let value): return value
    case .array(let value): return value.map(\.foundation)
    case .object(let value): return value.mapValues(\.foundation)
    }
  }
  var isObject: Bool { if case .object = self { return true }; return false }
}

/// One page of `posts.search` or `feed.top`: posts built like the feed's, whether more exist and
/// the opaque cursor that asks for them.
struct SocialPostsPage: Decodable {
  var posts: [Post]
  var more: Bool
  var cursor: JSONValue?
  init(posts: [Post], more: Bool, cursor: JSONValue?) { self.posts = posts; self.more = more; self.cursor = cursor }
  enum CodingKeys: String, CodingKey { case posts, more, cursor }
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    posts = try values.decode([Post].self, forKey: .posts)
    more = try values.decodeIfPresent(Bool.self, forKey: .more) ?? false
    let cursor = try values.decodeIfPresent(JSONValue.self, forKey: .cursor)
    // The contract's cursor is an object or null; anything else ends paging.
    self.cursor = cursor?.isObject == true ? cursor : nil
  }
  /// Another page can be asked for.
  var hasNext: Bool { more && cursor != nil }
}

/// Top's time windows (`feed.top window`).
enum TopWindow: String, CaseIterable, Identifiable, Sendable {
  case day, week, all
  var id: String { rawValue }
  var title: String {
    switch self {
    case .day: return "Today"
    case .week: return "This week"
    case .all: return "All time"
    }
  }
  /// How far back the window reaches (nil: all time).
  var span: TimeInterval? {
    switch self {
    case .day: return 86_400
    case .week: return 7 * 86_400
    case .all: return nil
    }
  }
}

enum PostSearchRules {
  static let minimumLength = 2
  static let maximumLength = 80
  static let pageSize = 30
  /// A query's length as the server measures it (`char_length`: Unicode code points). An emoji with
  /// a skin tone, a flag or a letter with a combining accent is one character on screen but several
  /// code points, so the field and the server must count the same unit.
  static func length(_ text: String) -> Int { text.unicodeScalars.count }
  /// The trimmed query the server accepts (2–80 code points), else nil.
  static func query(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return (minimumLength...maximumLength).contains(length(trimmed)) ? trimmed : nil
  }
  /// What the search field keeps: at most 80 code points (the server's limit), cut between whole
  /// characters so an emoji or accented letter is never split.
  static func clamped(_ text: String) -> String {
    guard length(text) > maximumLength else { return text }
    var result = "", count = 0
    for character in text {
      let size = character.unicodeScalars.count
      if count + size > maximumLength { break }
      result.append(character); count += size
    }
    return result
  }
  /// The fallback filter over loaded posts (servers without `posts.search`): body or poll question.
  static func locallyMatches(_ post: Post, _ text: String) -> Bool {
    text.isEmpty || post.text.localizedCaseInsensitiveContains(text) || (post.poll?.question.localizedCaseInsensitiveContains(text) ?? false)
  }
}

/// Share links. The shared text never carries the post's body, author or alias.
enum PostLinks {
  static let host = "maroonsocial.chat"
  static let scheme = "maroonsocial"
  static let shareLine = "See this on Maroon Social"
  /// The share sheet's preview icon: a bundled copy of the app icon (an app icon set cannot be
  /// loaded by name, and a symbol draws white on the sheet's white tile). Never anything from the post.
  static var shareIcon: Image { Image("ShareIcon") }
  static func shareURL(for postID: String) -> URL { URL(string: "https://\(host)/p/\(postID.lowercased())")! }
  /// The post a link opens: `maroonsocial://post/<uuid>` or `https://maroonsocial.chat/p/<uuid>`
  /// (also `www.`). Anything else is not a post link.
  static func postID(from url: URL) -> String? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let scheme = components.scheme?.lowercased() else { return nil }
    let parts = components.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    let candidate: String?
    switch scheme {
    case Self.scheme:
      // maroonsocial://post/<id> parses as host "post", path "/<id>".
      if components.host?.lowercased() == "post", parts.count == 1 { candidate = parts[0] }
      else if (components.host ?? "").isEmpty, parts.count == 2, parts[0].lowercased() == "post" { candidate = parts[1] }
      else { candidate = nil }
    case "https":
      guard let host = components.host?.lowercased(), [Self.host, "www." + Self.host].contains(host),
        parts.count == 2, parts[0] == "p" else { return nil }
      candidate = parts[1]
    default: candidate = nil
    }
    guard let candidate, let uuid = UUID(uuidString: candidate) else { return nil }
    return uuid.uuidString.lowercased()
  }
}

extension SocialServiceError {
  /// A server that predates an action answers "Unknown social action." (code invalid).
  var isUnknownAction: Bool { code == "not_found" || (code == "invalid" && error.trimmingCharacters(in: .whitespaces).hasPrefix("Unknown social action")) }
}
extension Error {
  var isUnknownSocialAction: Bool { (self as? SocialServiceError)?.isUnknownAction == true }
  var isCancellation: Bool { self is CancellationError || (self as? URLError)?.code == .cancelled }
  /// No answer from the service itself: the network, a malformed response, or the gateway's
  /// "temporarily unavailable" (503). A refusal the server explained (invalid, rate_limit…) is not.
  var isTransportFailure: Bool {
    guard let failure = self as? SocialServiceError else { return !isCancellation }
    return failure.code == "unavailable"
  }
}

extension SocialService {
  private static let pageDecoder: JSONDecoder = {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
  }()
  /// `posts.search`: posts of `community` (and `topic`) matching `query`, most relevant and newest
  /// first. Reads skip the mutation queue, so a newer keystroke can cancel the request in flight.
  func searchPosts(community: Community, query: String, topic: String? = nil, cursor: JSONValue? = nil, limit: Int = PostSearchRules.pageSize) async throws -> SocialPostsPage {
    guard let query = PostSearchRules.query(query) else { throw SocialServiceError(error: "Search for 2 to 80 characters.", code: "invalid") }
    var payload: [String: Any] = ["community": community.rawValue, "query": query, "limit": min(30, max(1, limit))]
    if let topic { payload["topic"] = topic }
    if let cursor { payload["cursor"] = cursor.foundation }
    return try await postsPage("posts.search", payload: payload, topic: topic, community: community)
  }
  /// `feed.top`: the highest-scored posts of `community` (and `topic`) in `window`.
  func topPosts(community: Community, window: TopWindow, topic: String? = nil, cursor: JSONValue? = nil, limit: Int = 30) async throws -> SocialPostsPage {
    var payload: [String: Any] = ["community": community.rawValue, "window": window.rawValue, "limit": min(30, max(1, limit))]
    if let topic { payload["topic"] = topic }
    if let cursor { payload["cursor"] = cursor.foundation }
    return try await postsPage("feed.top", payload: payload, topic: topic, community: community)
  }
  private func postsPage(_ action: String, payload: [String: Any], topic: String?, community: Community) async throws -> SocialPostsPage {
    let data = try await sendData(endpoint: "social", action: action, payload: payload)
    try Task.checkCancellation()
    let page = try Self.pageDecoder.decode(SocialPostsPage.self, from: data)
    guard page.posts.count <= 30, page.posts.allSatisfy({ $0.community == community }),
      topic == nil || page.posts.allSatisfy({ $0.deleted == true || $0.topic == topic }) else { throw URLError(.badServerResponse) }
    return page
  }
}
