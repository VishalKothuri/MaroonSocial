import Foundation
import MaroonCore

struct SocialLibraryQuery: Hashable {
  enum Kind: String { case posts, comments, saved, post }
  var kind: Kind
  var offset = 0
  var postID: String? = nil
  var payload: [String: Any] {
    var value: [String: Any] = ["kind": kind.rawValue, "offset": offset]
    if let postID { value["post_id"] = postID }
    return value
  }
}
struct PersonalComment: Decodable, Identifiable, Equatable {
  var id: String
  var postID: String
  var text: String
  var created: Date
  var score: Int
  var anonymous: Bool
  var postText: String
}
struct SocialLibraryPage {
  var query: SocialLibraryQuery
  var posts: [Post] = []
  var comments: [PersonalComment] = []
  var hasMore = false
  var error: String? = nil
  var loadedAt: Date = .now
}
@MainActor final class LibraryPostLease {
  let id: UUID
  let query: SocialLibraryQuery
  private let release: @MainActor @Sendable (UUID) -> Void
  init(id: UUID, query: SocialLibraryQuery, release: @escaping @MainActor @Sendable (UUID) -> Void) {
    self.id = id; self.query = query; self.release = release
  }
  deinit {
    let id = id; let release = release
    Task { @MainActor in release(id) }
  }
}

enum AccountUsernameRules {
  static func normalized(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
  static func valid(_ value: String) -> Bool { normalized(value).range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil }
}
