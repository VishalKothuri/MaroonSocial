import Foundation
import Observation

struct CampusCommunity: Decodable, Identifiable, Equatable {
  let id: String
  let title: String
  let description: String
  let category: String
  let capacity: Int
  let memberCount: Int
  let joined: Bool
  let owner: Bool
  let closed: Bool
  let isPublic: Bool
  let inviteCode: String?
  let createdAt: Date
  let avatar: String?
  let myAlias: String?
  let myAvatar: String?
  let invited: Bool?
}
struct CommunityMember: Decodable, Identifiable {
  let username: String // Legacy wire compatibility only; never an account identifier in group UI.
  let alias: String?
  let memberKey: String?
  let avatar: String?
  let isMe: Bool?
  let role: String
  var id: String { memberKey ?? username }
  var displayName: String { alias ?? "Group member" }
  enum CodingKeys: String, CodingKey { case username, alias, memberKey, avatar, isMe, role }
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    username = try values.decodeIfPresent(String.self, forKey: .username) ?? ""
    alias = try values.decodeIfPresent(String.self, forKey: .alias)
    memberKey = try values.decodeIfPresent(String.self, forKey: .memberKey)
    avatar = try values.decodeIfPresent(String.self, forKey: .avatar)
    isMe = try values.decodeIfPresent(Bool.self, forKey: .isMe)
    role = try values.decode(String.self, forKey: .role)
  }
}

struct CommunityInvitation: Decodable, Identifiable {
  let username: String
  let invitationKey: String
  var id: String { invitationKey }
}

enum GroupFormRules {
  static let purposes = ["Class", "Major", "Dorm or House", "Study Group", "Friends", "People on app", "Other"]
  static let avatars = ["maroon", "gold", "sage", "sky", "violet", "coral", "slate", "rose"]
  static func randomIdentity() -> (alias: String, avatar: String) {
    let first = ["Maroon", "Quiet", "Midnight", "Sunny", "Cedar", "Golden"].randomElement()!
    let second = ["Fox", "Owl", "Otter", "Star", "Elm", "Comet"].randomElement()!
    return (first + second + String(Int.random(in: 100...999)), avatars.randomElement()!)
  }
  static func validAlias(_ value: String) -> Bool {
    let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.range(of: "^[A-Za-z0-9_]{3,24}$", options: .regularExpression) != nil
  }
  static func usernames(_ raw: String) throws -> [String] {
    var result: [String] = []
    for part in raw.split(whereSeparator: { $0 == "," || $0.isWhitespace }) {
      var value = part.lowercased(); if value.hasPrefix("@") { value.removeFirst() }
      guard value.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil else { throw Failure.username }
      if !result.contains(value) { result.append(value) }
    }
    guard result.count <= 20 else { throw Failure.tooManyInvites }
    return result
  }
  enum Failure: LocalizedError {
    case username, tooManyInvites
    var errorDescription: String? {
      switch self {
      case .username: "Enter account usernames using 3–20 letters, numbers, or underscores. Separate people with commas or spaces."
      case .tooManyInvites: "Invite up to 20 people at a time. You can invite more from group settings."
      }
    }
  }
}

private struct CommunitiesResponse: Decodable {
  let communities: [CampusCommunity]?
  let community: CampusCommunity?
  let members: [CommunityMember]?
  let bans: [CommunityMember]?
  let pending: [CommunityInvitation]?
  let roomId: String?
  let hasMore: Bool?
}
@Observable @MainActor final class CommunitiesService {
  typealias Transport = @MainActor (String, [String: Any]) async throws -> Data
  static let categories = GroupFormRules.purposes
  private let transport: Transport
  var communities: [CampusCommunity] = []
  var community: CampusCommunity?
  var members: [CommunityMember] = []
  var bans: [CommunityMember] = []
  var pending: [CommunityInvitation] = []
  var busy = false
  var loaded = false
  var error: String?
  var hasMore = false
  private var generation = 0
  convenience init(social: SocialService, fixtureMode: Bool = false) {
    self.init { action, payload in
      if fixtureMode {
        if action == "list" { return Data(#"{"communities":[],"has_more":false}"#.utf8) }
        throw SocialServiceError(error: "Community changes are unavailable in this test session.", code: "unavailable")
      }
      return try await social.sendData(endpoint: "communities", action: action, payload: payload)
    }
  }
  init(transport: @escaping Transport) { self.transport = transport }
  func list(search: String, category: String, joinedOnly: Bool, more: Bool = false) async {
    guard !more || !busy else { return }
    generation += 1
    let request = generation
    busy = true; error = nil
    defer { if request == generation { busy = false } }
    do {
      let response = try await send("list", ["search": search, "category": category, "joined_only": joinedOnly, "offset": more ? communities.count : 0])
      guard request == generation, !Task.isCancelled else { return }
      let values = response.communities ?? []
      if more { communities += values.filter { value in !communities.contains { $0.id == value.id } } }
      else { communities = values }
      hasMore = response.hasMore ?? false; loaded = true
    } catch { if request == generation { failure(error) } }
  }
  @discardableResult func act(_ action: String, _ payload: [String: Any] = [:]) async -> String? {
    guard !busy else { return nil }
    busy = true; error = nil
    defer { busy = false }
    do {
      let response = try await send(action, payload)
      if let value = response.community { community = value }
      if let value = response.members { members = value }
      if let value = response.bans { bans = value }
      if let value = response.pending { pending = value }
      if let value = response.community {
        if !value.owner { bans = []; pending = [] }
        if !value.joined { members = []; bans = []; pending = [] }
      }
      if action == "leave" { community = nil; members = []; bans = []; pending = [] }
      loaded = true
      return response.roomId ?? response.community?.id ?? "ok"
    } catch { failure(error); return nil }
  }
  private func send(_ action: String, _ payload: [String: Any]) async throws -> CommunitiesResponse {
    let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .secondsSince1970
    return try decoder.decode(CommunitiesResponse.self, from: await transport(action, payload))
  }
  private func failure(_ failure: Error) {
    guard !(failure is CancellationError) else { return }
    error = failure.localizedDescription
    if let code = (failure as? SocialServiceError)?.code, ["unauthorized", "forbidden", "account_deleted", "verification_required", "unavailable"].contains(code) {
      communities = []; community = nil; members = []; bans = []; pending = []; loaded = false; hasMore = false
    }
  }
}
