import Foundation
import MaroonCore
import Observation
import Security

struct SocialGroupMember: Codable, Equatable {
  var username: String
  var role: String
  var status: String
  var memberKey: String? = nil
  var avatar: String? = nil
  var isMe: Bool? = nil
}
/// Where a direct message started. The server keeps the origin in room meta, so the
/// tag outlives the post: once it is deleted only the excerpt goes away. Never the author.
struct SourcePostContext: Codable, Equatable {
  var postID: String
  var excerpt: String? = nil
  var deleted = false
  var fromReply = false
  init(postID: String, excerpt: String? = nil, deleted: Bool = false, fromReply: Bool = false) {
    self.postID = postID; self.excerpt = excerpt; self.deleted = deleted; self.fromReply = fromReply
  }
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    postID = try container.decode(String.self, forKey: .postID)
    excerpt = try container.decodeIfPresent(String.self, forKey: .excerpt)
    deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
    fromReply = try container.decodeIfPresent(Bool.self, forKey: .fromReply) ?? false
  }
}
struct SocialConversationMeta: Codable, Equatable {
  var id: String
  var kind: String
  var status: String
  var role: String
  var canSend: Bool
  var unread: Int
  var lastRead: Int
  var pendingOutgoing: Bool
  var typing: [String]?
  var members: [SocialGroupMember]?
  var call: RoomCallSummary?
  var avatar: String? = nil
  var category: String? = nil
  var myAlias: String? = nil
  var myAvatar: String? = nil
  var sourcePost: SourcePostContext? = nil
}
struct SocialAttachmentReference: Codable, Identifiable, Equatable {
  var id: String
  var kind: String
  var mime: String
  var size: Int
  var roomID: String?
  var messageID: String?
  var postID: String?
}
struct SocialOrganization: Codable, Identifiable, Equatable {
  var id: String
  var name: String
  var about: String
  var status: String
  var followed: Bool
  var canManage: Bool
}
struct SocialSnapshot: Codable {
  var username: String
  var feedCommunity: Community? = nil
  var karma: Int? = nil
  var nsfwEnabled: Bool
  var posts: [Post]
  var courses: [Course]
  var activities: [Activity]
  var conversations: [Conversation]
  var ownPostIDs: [String]
  var ownCommentIDs: [String]
  var ownMessageIDs: [String]
  var conversationMeta: [SocialConversationMeta]
  var attachments: [SocialAttachmentReference]
  var organizations: [SocialOrganization]
  var savedEvents: [String]
  /// Cursor after the first feed page the snapshot carries; nil when that page is the whole feed.
  var feedNext: SocialPageCursor? = nil
  /// Server clock (with overlap) to start `feed.delta` from. Absent on older servers.
  var serverNow: Double? = nil
}
/// Keyset position: everything strictly older than (before_created, before_id).
/// `beforeCreated` is the server's own epoch value, kept as received so no rounding moves it.
struct SocialPageCursor: Codable, Equatable {
  var beforeCreated: Double
  var beforeID: String
  enum CodingKeys: String, CodingKey { case beforeCreated = "before_created", beforeID = "before_id" }
  var payload: [String: Any] { ["before_created": beforeCreated, "before_id": beforeID] }
}
struct SocialFeedPage: Decodable {
  var posts: [Post]
  var next: SocialPageCursor?
}
struct SocialFeedDelta: Decodable {
  var changed: [Post]
  var removed: [String]
  var now: Double
  var truncated: Bool? = nil
  /// Something only this member sees changed (a block, a hidden post, their own rename):
  /// the held posts are refetched with `feed.posts`.
  var resync: Bool? = nil
}
/// `feed.posts`: current copies of held posts, and the requested ids that are gone.
struct SocialFeedPosts: Decodable {
  var posts: [Post]
  var removed: [String]
}
struct SocialCommentsPage: Decodable {
  var comments: [Comment]
  var next: SocialPageCursor?
  var commentCount: Int?
}
struct SocialRoomMessages: Decodable {
  var roomID: String
  var messages: [Message]
  var meta: SocialConversationMeta?
  var more: Bool?
  /// Held messages (up to `after_seq`) deleted, edited or reacted to after `changed_since`.
  var changed: [Message]? = nil
  /// Server clock (with overlap) for the next `changed_since`.
  var now: Double? = nil
  enum CodingKeys: String, CodingKey { case roomID = "room_id", messages, meta, more, changed, now }
}
struct SocialTagQuery: Hashable {
  let tag: String
  let community: Community
}
struct SocialTagPage {
  let query: SocialTagQuery
  var posts: [Post]
  var error: String? = nil
  var loadedAt: Date = .now
}
struct SocialResponse: Decodable {
  var snapshot: SocialSnapshot?
  var resourceID: String?
  var token: String?
  var attachmentID: String?
  var mediaData: String?
  var externalMedia: KlipyReference?
  var mime: String?
  /// Set instead of `media_data` when the media store hands out a URL (R2 presigned GET or CDN).
  var url: URL?
  var expires: Double?
  // Filled by the authenticated transport for active navigation scopes. These
  // are separate from the feed so discovering old posts cannot expand it.
  var tagPages: [SocialTagPage]? = nil
  var libraryPages: [SocialLibraryPage]? = nil
  enum CodingKeys: String, CodingKey {
    case snapshot, token, mime, url, expires
    case resourceID = "resource_id", attachmentID = "attachment_id", mediaData = "media_data", externalMedia = "external_media"
  }
}
struct SocialServiceError: Error, Decodable, LocalizedError {
  var error: String
  var code: String?
  var errorDescription: String? { error }
}

@MainActor struct SocialCredentialStore {
  var read: () -> String?
  var save: (String) throws -> Void
  var deletionPending: () -> Bool
  var markDeletionPending: () throws -> Void
  var clear: () -> Void
  var linkPending: () -> Bool = { false }
  var markLinkPending: () throws -> Void = {}
  var clearLinkPending: () -> Void = {}
  var deletionReceipt: () -> String? = { nil }
  static var keychain: Self {
    Self(read: SocialCredential.read, save: SocialCredential.save,
         deletionPending: SocialCredential.deletionPending,
         markDeletionPending: SocialCredential.markDeletionPending,
         clear: SocialCredential.delete, linkPending: SocialCredential.linkPending,
         markLinkPending: SocialCredential.markLinkPending, clearLinkPending: SocialCredential.clearLinkPending,
         deletionReceipt: SocialCredential.deletionReceipt)
  }
}

/// Shared community transport. Personal email authentication and university verification are separate.
@Observable @MainActor final class SocialService {
  typealias Transport = @MainActor (String, String, [String: Any], String?) async throws -> Data
  private(set) var connected = false
  var feedCommunity: Community = .campus
  private var token: String?
  private let credentials: SocialCredentialStore
  private let transport: Transport?
  let auth: EmailAuthService?
  /// On-device attachment cache; wiped whenever the identity changes.
  let media: MediaStore
  /// GET for store-issued media URLs. Injectable for tests.
  var mediaDownloader: (URL) async throws -> (data: Data, mime: String?) = { try await MediaDownload.fetch($0) }
  private var identityGeneration = 0 { didSet { media.wipe() } }
  var identityRevision: Int { identityGeneration }
  var hasStoredCredential: Bool { token != nil || auth?.signedIn == true }
  var usesEmailSession: Bool { token == nil && auth?.signedIn == true }
  var hasDeviceCredential: Bool { token != nil }
  private var tail: Task<Void, Never>?
  private var deletionTask: Task<Void, Error>?
  private var tagOwners: [UUID: SocialTagQuery] = [:]
  private var libraryOwners: [UUID: SocialLibraryQuery] = [:]
  private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
  }()

  init(credentials: SocialCredentialStore? = nil, auth: EmailAuthService? = nil, transport: Transport? = nil, media: MediaStore? = nil) {
    let credentials = credentials ?? .keychain
    self.credentials = credentials
    self.transport = transport
    // Injected transports (tests) never share the app's on-disk cache.
    self.media = media ?? (transport == nil ? .shared : .temporary())
    self.auth = auth
    token = credentials.read()
  }

  func connect(username: String, adult: Bool = true, allowRegistration: Bool = false) async throws -> SocialResponse {
    try await finishPendingDeletion()
    if credentials.linkPending(), auth?.signedIn == true, token != nil {
      return try await finishEmailLogin(username: username, adult: adult, linkExisting: true)
    }
    if token != nil || auth?.signedIn == true {
      let result = try await perform("snapshot")
      connected = true
      return result
    }
    guard allowRegistration else { throw SocialServiceError(error: "Sign in again to recover your account.", code: "reauthentication_required") }
    let result = try await raw("social", action: "register", payload: ["username": username, "adult": adult], authenticated: false)
    let response = try decoder.decode(SocialResponse.self, from: result)
    guard let credential = response.token else { throw SocialServiceError(error: "The account could not be created. Please try again.", code: "invalid_session") }
    try credentials.save(credential)
    token = credential
    connected = true
    return response
  }
  func refresh() async throws -> SocialResponse {
    try await finishPendingDeletion()
    return try await perform("snapshot")
  }
  func perform(_ action: String, payload: [String: Any] = [:]) async throws -> SocialResponse {
    let previous = tail
    let epoch = identityGeneration
    let task = Task { @MainActor [self] in
      await previous?.value
      guard epoch == identityGeneration else { throw CancellationError() }
      let data = try await raw("social", action: action, payload: payload, authenticated: true)
      guard epoch == identityGeneration else { throw CancellationError() }
      var response = try decoder.decode(SocialResponse.self, from: data)
      // A plain snapshot (launch, polling, pull-to-refresh) never re-fetches the retained
      // tag/library pages: their views load them on demand. A mutation still refreshes
      // them, because a vote, save, block or deletion may change or remove their posts.
      if response.snapshot != nil && action != "snapshot" {
        let queries = Set(tagOwners.values).sorted { ($0.community.rawValue, $0.tag) < ($1.community.rawValue, $1.tag) }
        var pages: [SocialTagPage] = []
        for query in queries {
          guard epoch == identityGeneration else { throw CancellationError() }
          do { pages.append(SocialTagPage(query: query, posts: try await posts(tag: query.tag, community: query.community))) }
          catch {
            if error is CancellationError { throw error }
            // A failed secondary query cannot undo a successful vote/send.
            // Nor may it keep an old result after a block/deletion was applied.
            pages.append(SocialTagPage(query: query, posts: [], error: error.localizedDescription))
          }
        }
        guard epoch == identityGeneration else { throw CancellationError() }
        response.tagPages = pages
        var libraryPages: [SocialLibraryPage] = []
        for query in Set(libraryOwners.values).sorted(by: { ($0.kind.rawValue, $0.offset, $0.postID ?? "") < ($1.kind.rawValue, $1.offset, $1.postID ?? "") }) {
          guard epoch == identityGeneration else { throw CancellationError() }
          do { libraryPages.append(try await library(query)) }
          catch {
            if error is CancellationError { throw error }
            libraryPages.append(SocialLibraryPage(query: query, error: error.localizedDescription))
          }
        }
        guard epoch == identityGeneration else { throw CancellationError() }
        response.libraryPages = libraryPages
      }
      return response
    }
    tail = Task { _ = try? await task.value }
    return try await task.value
  }
  /// Incremental reads share the request queue with mutations, so a page or delta can never
  /// overtake the write that preceded it, and an account switch cancels them the same way.
  private func queued<Value: Decodable>(_ action: String, payload: [String: Any], as type: Value.Type) async throws -> Value {
    let previous = tail
    let epoch = identityGeneration
    let task = Task { @MainActor [self] in
      await previous?.value
      guard epoch == identityGeneration else { throw CancellationError() }
      let data = try await raw("social", action: action, payload: payload, authenticated: true)
      guard epoch == identityGeneration else { throw CancellationError() }
      return try decoder.decode(Value.self, from: data)
    }
    tail = Task { _ = try? await task.value }
    return try await task.value
  }
  /// One keyset page of the selected community, newest first (30 by default, at most 50).
  /// `topic` narrows the page to one topic; it is sent only when set (a server without topics never sees it).
  func feedPage(community: Community, cursor: SocialPageCursor?, limit: Int = 30, topic: String? = nil) async throws -> SocialFeedPage {
    var payload: [String: Any] = ["community": community.rawValue, "limit": min(50, max(1, limit))]
    if let cursor { payload.merge(cursor.payload) { _, new in new } }
    if let topic { payload["topic"] = topic }
    let page = try await queued("feed.page", payload: payload, as: SocialFeedPage.self)
    guard page.posts.count <= 50, topic == nil || page.posts.allSatisfy({ $0.deleted == true || $0.topic == topic }) else { throw URLError(.badServerResponse) }
    return page
  }
  /// Posts changed after `since` (new ones, or ones in `knownIDs`) and known ids that are gone.
  /// With a topic, `removed` also lists known posts whose topic no longer matches.
  func feedDelta(community: Community, since: Double, knownIDs: [String], topic: String? = nil) async throws -> SocialFeedDelta {
    var payload: [String: Any] = ["community": community.rawValue, "since": since, "known_ids": Array(knownIDs.prefix(300))]
    if let topic { payload["topic"] = topic }
    return try await queued("feed.delta", payload: payload, as: SocialFeedDelta.self)
  }
  /// Current copies of held feed posts (at most 50 per call) and the ids that are gone (or, with a
  /// topic, no longer in it).
  func feedPosts(community: Community, ids: [String], topic: String? = nil) async throws -> SocialFeedPosts {
    let requested = Array(ids.prefix(50))
    var payload: [String: Any] = ["community": community.rawValue, "ids": requested]
    if let topic { payload["topic"] = topic }
    let page = try await queued("feed.posts", payload: payload, as: SocialFeedPosts.self)
    guard page.posts.count <= requested.count else { throw URLError(.badServerResponse) }
    return page
  }
  /// `topics.list`: the active topics in catalog order with their 7-day counts in `community`.
  /// A server that predates topics answers with an error ("Unknown social action.").
  func topics(community: Community) async throws -> [Topic] {
    struct Payload: Decodable { var topics: [Topic] }
    let result = try await queued("topics.list", payload: ["community": community.rawValue], as: Payload.self)
    guard result.topics.count <= 64 else { throw URLError(.badServerResponse) }
    return result.topics
  }
  /// Older replies of one post, returned oldest first.
  func commentsPage(postID: String, cursor: SocialPageCursor?, limit: Int = 50) async throws -> SocialCommentsPage {
    var payload: [String: Any] = ["post_id": postID, "limit": min(50, max(1, limit))]
    if let cursor { payload.merge(cursor.payload) { _, new in new } }
    let page = try await queued("comments.page", payload: payload, as: SocialCommentsPage.self)
    guard page.comments.count <= 50 else { throw URLError(.badServerResponse) }
    return page
  }
  /// Messages of one room newer than `afterSequence` or older than `beforeSequence` (oldest
  /// first), or the newest page. With `changedSince` (and `afterSequence`) the answer also lists
  /// held messages that were deleted, edited or reacted to since that server clock.
  func roomMessages(roomID: String, afterSequence: Int? = nil, beforeSequence: Int? = nil, changedSince: Double? = nil, limit: Int = 50) async throws -> SocialRoomMessages {
    var payload: [String: Any] = ["room_id": roomID, "limit": min(50, max(1, limit))]
    if let afterSequence { payload["after_seq"] = afterSequence }
    else if let beforeSequence { payload["before_seq"] = beforeSequence }
    if let changedSince, afterSequence != nil { payload["changed_since"] = changedSince }
    let page = try await queued("room.messages", payload: payload, as: SocialRoomMessages.self)
    guard page.messages.count <= 50, (page.changed?.count ?? 0) <= 50, page.roomID == roomID else { throw URLError(.badServerResponse) }
    return page
  }
  /// A Realtime token for this member's private channels, or `{realtime: false}` (keep polling).
  /// The token is held in memory only and never logged.
  func realtimeGrant() async throws -> RealtimeGrant {
    let grant = try await queued("realtime.token", payload: [:], as: RealtimeGrant.self)
    guard !grant.realtime || (grant.token?.isEmpty == false && grant.member != nil && grant.expiresAt != nil) else { throw URLError(.badServerResponse) }
    return grant
  }
  func credential() async throws -> String {
    guard let token else { throw SocialServiceError(error: "Sign in to continue.", code: "unauthorized") }
    return token
  }
  /// Internal transport shared by authoritative games and Tag; credentials never enter public payloads.
  func authenticatedRequest(endpoint: String, payload: [String: Any]) async throws -> Data {
    var body = payload
    let action = body.removeValue(forKey: "action") as? String ?? "snapshot"
    return try await raw(endpoint, action: action, payload: body, authenticated: true)
  }
  func sendData(endpoint: String, action: String, payload: [String: Any] = [:]) async throws -> Data {
    try await raw(endpoint, action: action, payload: payload, authenticated: true)
  }
  func posts(tag: String, community: Community) async throws -> [Post] {
    let normalized = try PostFeatureRules.normalizeTags([tag])
    guard let tag = normalized.first else { throw SocialServiceError(error: "Choose a tag.", code: "invalid") }
    struct Page: Decodable { let posts: [Post] }
    let data = try await raw("social", action: "posts.tag", payload: ["tag": tag, "community": community.rawValue], authenticated: true)
    try Task.checkCancellation()
    let posts = try decoder.decode(Page.self, from: data).posts
    guard posts.count <= 100 else { throw URLError(.badServerResponse) }
    return posts
  }
  func library(_ query: SocialLibraryQuery) async throws -> SocialLibraryPage {
    struct Payload: Decodable { var posts: [Post]; var comments: [PersonalComment]; var hasMore: Bool }
    let data = try await raw("social", action: "library", payload: query.payload, authenticated: true)
    try Task.checkCancellation()
    let result = try decoder.decode(Payload.self, from: data)
    guard result.posts.count <= 50, result.comments.count <= 50 else { throw URLError(.badServerResponse) }
    return SocialLibraryPage(query: query, posts: result.posts, comments: result.comments, hasMore: result.hasMore)
  }
  func retainLibraryQuery(_ query: SocialLibraryQuery, owner: UUID) { libraryOwners[owner] = query }
  func releaseLibraryQuery(owner: UUID) { libraryOwners.removeValue(forKey: owner) }
  func retainTagQuery(_ query: SocialTagQuery, owner: UUID) { tagOwners[owner] = query }
  func releaseTagQuery(owner: UUID) { tagOwners.removeValue(forKey: owner) }
  func upload(_ media: MediaAttachment, roomID: String? = nil, postID: String? = nil) async throws -> String {
    var payload: [String: Any] = ["data": media.data.base64EncodedString(), "kind": media.kind.rawValue]
    if let roomID { payload["room_id"] = roomID }
    if let postID { payload["post_id"] = postID }
    if let reference = media.klipy {
      payload.removeValue(forKey: "data")
      payload["reference"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(reference))
      payload["nonce"] = media.id
    }
    let result = try await perform(media.klipy == nil ? "attachment.upload" : "attachment.external", payload: payload)
    guard let id = result.attachmentID else { throw URLError(.badServerResponse) }
    return id
  }
  func attachment(_ id: String) async throws -> Data { try await attachmentContent(id).data }
  /// Cache first (memory, then disk); a miss loads once from the network and is stored.
  func attachmentContent(_ id: String) async throws -> (data: Data, isKlipy: Bool, mime: String?) {
    let content = try await media.content(id) { [weak self] id in
      guard let self else { throw CancellationError() }
      return try await self.fetchAttachment(id)
    }
    return (content.data, content.isKlipy, content.mime)
  }
  /// Warms the cache for the next feed rows.
  func prefetchAttachments(_ ids: [String]) {
    media.prefetch(ids: ids) { [weak self] id in
      guard let self else { throw CancellationError() }
      return try await self.fetchAttachment(id)
    }
  }
  /// Media reads do not mutate anything, so they skip the serial mutation queue (a screen of
  /// attachments must not delay a vote); the identity epoch still cancels them on account switch.
  private func fetchAttachment(_ id: String) async throws -> MediaContent {
    let epoch = identityGeneration
    let data = try await raw("social", action: "attachment.read", payload: ["attachment_id": id], authenticated: true)
    // A 5 MB attachment is ~6.7 MB of JSON and base64: parse it off the main actor (prefetch runs this while scrolling).
    let reply = try await Task.detached(priority: Task.currentPriority) { try AttachmentReply.decode(data) }.value
    let content: MediaContent
    switch reply {
    case .external(let reference): content = MediaContent(data: try await KlipyNetwork.media(reference), mime: reference.mime, isKlipy: true)
    case .url(let url, let mime):
      let download = try await mediaDownloader(url)
      content = MediaContent(data: download.data, mime: mime ?? download.mime)
    case .bytes(let bytes, let mime): content = MediaContent(data: bytes, mime: mime)
    }
    guard epoch == identityGeneration else { throw CancellationError() }
    return content
  }
  func clearCredentialAfterDeletion() {
    identityGeneration += 1
    token = nil
    connected = false
    tagOwners = [:]; libraryOwners = [:]
    credentials.clear()
  }
  /// Persist the user's deletion intent before sending. A lost acknowledgement
  /// cannot leave a revoked credential trapping the next launch in a retry loop.
  func deleteAccount() async throws {
    if let deletionTask { try await deletionTask.value; return }
    try credentials.markDeletionPending()
    let previous = tail
    let task = Task { @MainActor [self] in
      await previous?.value
      do {
        if let receipt = credentials.deletionReceipt(), auth != nil {
          let data = try await raw("auth-account", action: "deletion-status", payload: ["receipt": receipt], authenticated: false)
          if (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["deleted"] as? Bool == true {
            try await auth?.signOutLocally(); clearCredentialAfterDeletion(); return
          }
        }
        let payload: [String: Any] = credentials.deletionReceipt().map { ["deletion_receipt": $0] } ?? [:]
        _ = try await raw("social", action: "account.delete", payload: payload, authenticated: true)
      }
      catch {
        // Only a revoked/absent credential completes a previously requested deletion.
        // Suspensions, connection failures and all other errors retain the credential.
        let code = (error as? SocialServiceError)?.code
        guard code == "account_deleted" || (auth == nil && code == "unauthorized") || (token != nil && code == "unauthorized") else { throw error }
      }
      try await auth?.signOutLocally()
      clearCredentialAfterDeletion()
    }
    deletionTask = task
    tail = Task { _ = try? await task.value }
    defer { deletionTask = nil }
    try await task.value
  }
  /// Both credentials are sent only to the linking endpoint. Content keeps its existing member.
  func finishEmailLogin(username: String, adult: Bool, linkExisting: Bool) async throws -> SocialResponse {
    guard auth?.signedIn == true else { throw SocialServiceError(error: "Sign in with your email first.", code: "unauthorized") }
    try await finishPendingDeletion()
    await tail?.value
    let action = linkExisting ? "link" : "register"
    if linkExisting && token == nil { throw SocialServiceError(error: "The existing device credential is missing.", code: "unauthorized") }
    if linkExisting { try credentials.markLinkPending() }
    _ = try await raw("auth-account", action: action, payload: ["username": username, "adult": adult], authenticated: true)
    // The server has bound this exact Auth user and rotated the old device credential.
    identityGeneration += 1; token = nil; credentials.clear(); connected = false
    return try await refresh()
  }
  func signOut() async throws {
    guard token == nil, let auth else { throw SocialServiceError(error: "Email recovery must be linked before signing out of this device account.", code: "not_linked") }
    // Revoke before forgetting a live session. Confirmed expired/revoked sessions
    // can be removed locally; transport failures keep a retryable login.
    if auth.signedIn {
      do { _ = try await raw("auth-account", action: "logout", payload: [:], authenticated: true) }
      catch {
        let code = (error as? SocialServiceError)?.code
        guard !auth.signedIn || code == "unauthorized" || code == "account_deleted" else { throw error }
      }
    }
    identityGeneration += 1; connected = false
    try await auth.signOutLocally()
  }
  private func finishPendingDeletion() async throws {
    guard credentials.deletionPending() else { return }
    try await deleteAccount()
    throw SocialServiceError(error: "Your account was deleted. You can create a new account.", code: "account_deleted")
  }
  private func raw(_ endpoint: String, action: String, payload: [String: Any], authenticated: Bool) async throws -> Data {
    var payload = payload
    if endpoint == "social" { payload["feed_community"] = feedCommunity.rawValue }
    if credentials.deletionPending(), !["account.delete", "deletion-status"].contains(action) {
      throw SocialServiceError(error: "Account deletion is pending. Reconnect to finish deleting it.", code: "account_deletion_pending")
    }
    let epoch = identityGeneration
    let useBearer = authenticated && (token == nil || endpoint == "auth-account") && auth?.signedIn == true
    let bearer = useBearer ? try await auth?.accessToken() : nil
    guard epoch == identityGeneration else { throw CancellationError() }
    let sessionToken = authenticated && !useBearer ? try await credential() : (endpoint == "auth-account" ? token : nil)
    if let transport {
      let data = try await transport(endpoint, action, payload, bearer ?? sessionToken)
      guard epoch == identityGeneration else { throw CancellationError() }
      return data
    }
    guard let configURL = Bundle.main.url(forResource: "Backend", withExtension: "json") else { throw URLError(.badURL) }
    let config = try JSONDecoder().decode(BackendConfig.self, from: Data(contentsOf: configURL))
    var request = URLRequest(url: config.url.appending(path: "functions/v1/\(endpoint)"))
    request.httpMethod = "POST"
    request.timeoutInterval = 25
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
    if let sessionToken { request.setValue(sessionToken, forHTTPHeaderField: "X-Social-Token") }
    if let bearer { request.setValue("Bearer " + bearer, forHTTPHeaderField: "Authorization") }
    var body = payload
    body["action"] = action
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard epoch == identityGeneration else { throw CancellationError() }
    guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
      if let error = try? decoder.decode(SocialServiceError.self, from: data) { throw error }
      throw URLError(.badServerResponse)
    }
    return data
  }
}
private enum SocialCredential {
  private static var query: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "app.maroonsocial.member", kSecAttrAccount as String: "device-account-v1"]
  }
  static func read() -> String? {
    var query = query
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }
  static func save(_ token: String) throws {
    var query = query
    query[kSecValueData as String] = Data(token.utf8)
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemDelete(Self.query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else { throw SocialServiceError(error: "Couldn’t save the secure account credential (\(status)). Please use a signed app build.", code: "secure_storage") }
  }
  private static var deletionQuery: [String: Any] {
    var value = query
    value[kSecAttrAccount as String] = "device-account-deletion-pending-v1"
    return value
  }
  static func deletionPending() -> Bool {
    SecItemCopyMatching(deletionQuery as CFDictionary, nil) == errSecSuccess
  }
  static func markDeletionPending() throws {
    if deletionPending() { return }
    var value = deletionQuery
    var bytes = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw SocialServiceError(error: "Couldn’t secure the deletion request.", code: "secure_storage") }
    value[kSecValueData as String] = Data(bytes.map { String(format: "%02x", $0) }.joined().utf8)
    value[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(value as CFDictionary, nil)
    guard status == errSecSuccess || status == errSecDuplicateItem else {
      throw SocialServiceError(error: "Couldn’t securely save the deletion request (\(status)). Please try again.", code: "secure_storage")
    }
  }
  static func deletionReceipt() -> String? {
    var value = deletionQuery; value[kSecReturnData as String] = true; value[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(value as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
    let receipt = String(data: data, encoding: .utf8)
    return receipt?.count == 64 ? receipt : nil
  }
  private static var linkQuery: [String: Any] { var value = query; value[kSecAttrAccount as String] = "email-link-pending-v1"; return value }
  static func linkPending() -> Bool { SecItemCopyMatching(linkQuery as CFDictionary, nil) == errSecSuccess }
  static func markLinkPending() throws {
    if linkPending() { return }
    var value = linkQuery; value[kSecValueData as String] = Data([1]); value[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(value as CFDictionary, nil)
    guard status == errSecSuccess || status == errSecDuplicateItem else { throw SocialServiceError(error: "Couldn’t securely save the account link.", code: "secure_storage") }
  }
  static func clearLinkPending() { SecItemDelete(linkQuery as CFDictionary) }
  static func delete() {
    SecItemDelete(query as CFDictionary)
    SecItemDelete(deletionQuery as CFDictionary)
    clearLinkPending()
  }
}

/// `attachment.read`'s answer: a KLIPY reference, a store-issued URL, or inline base64 bytes.
/// Decoded with no actor isolation so the JSON and base64 work never runs on the main thread.
enum AttachmentReply: Sendable {
  case external(KlipyReference)
  case url(URL, mime: String?)
  case bytes(Data, mime: String?)
  private struct Body: Decodable {
    var mediaData: String?
    var externalMedia: KlipyReference?
    var mime: String?
    var url: URL?
    enum CodingKeys: String, CodingKey { case mime, url, mediaData = "media_data", externalMedia = "external_media" }
  }
  static func decode(_ data: Data) throws -> AttachmentReply {
    let body = try JSONDecoder().decode(Body.self, from: data)
    if let reference = body.externalMedia { return .external(reference) }
    if let url = body.url { return .url(url, mime: body.mime) }
    guard let value = body.mediaData, let bytes = Data(base64Encoded: value) else { throw URLError(.cannotDecodeRawData) }
    return .bytes(bytes, mime: body.mime)
  }
}
