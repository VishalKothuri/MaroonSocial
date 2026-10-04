import Foundation

/// Content-context requests never use a caller-supplied username or anonymity flag.
/// The server resolves the author from the source ID and enforces the same rule.
enum MessageRequestScope: Equatable {
  case post(String), reply(String), organization(String), username
  var anonymous: Bool { switch self { case .post, .reply: return true; default: return false } }
  var requiresUsername: Bool { self == .username }
  var action: String { if case .organization = self { return "organization.message" }; return "dm.request" }
  func payload(text: String, username: String, nonce: String) -> [String: Any] {
    var payload: [String: Any] = ["text": text.trimmingCharacters(in: .whitespacesAndNewlines), "nonce": nonce]
    switch self {
    case .post(let id): payload["post_id"] = id
    case .reply(let id): payload["comment_id"] = id
    case .organization(let id): payload["organization_id"] = id
    case .username: payload["username"] = username.lowercased().replacingOccurrences(of: "@", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return payload
  }
}

enum ChatParticipantLabel {
  static func name(author: String, mine: Bool, anonymous: Bool) -> String {
    if anonymous { return mine ? "You" : "Them" }
    return mine ? "You" : "@\(author)"
  }
}
