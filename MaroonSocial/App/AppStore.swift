import CryptoKit
import ImageIO
import MaroonCore
import SwiftUI

struct LocalState: Codable {
  var username = ""
  var draftOwner: String? = nil
  var onboarded = false
  var adult = false
  var posts: [Post] = []
  var courses: [Course] = []
  var conversations: [Conversation] = []
  var activities: [Activity] = []
  @SortedSetCoding var hiddenPosts: Set<String> = []
  @SortedSetCoding var savedEvents: Set<String> = []
  var reports: [String] = []
  /// Set once the member has confirmed the username that named posts and replies carry.
  var publicNameConfirmed: Bool? = nil
  // Incremental sync bookkeeping. Every key is optional so cache files written before
  // incremental sync still decode (synthesized decoding treats a missing optional as nil).
  /// Server time (already overlapped) from which `feed.delta` asks for changes.
  var feedSince: Double? = nil
  /// Keyset position of the next older feed page; nil once the end of the feed is loaded.
  var feedCursor: SocialPageCursor? = nil
  /// The posts that belong to the feed (newest first) and the community they were loaded for.
  var feedPostIDs: [String]? = nil
  var feedCommunity: String? = nil
  /// Highest message sequence held per room (`room.messages after_seq`).
  var roomCursors: [String: Int]? = nil
  /// When each room was last opened (or first seen); drives message eviction.
  var roomOpened: [String: Date]? = nil
}

/// Encodes a set as a sorted array (the same JSON as before). Swift may iterate two equal sets in
/// different orders, and the hash-gated `save()` needs equal state to encode to identical bytes.
@propertyWrapper struct SortedSetCoding: Codable, Equatable {
  var wrappedValue: Set<String>
  init(wrappedValue: Set<String>) { self.wrappedValue = wrappedValue }
  init(from decoder: Decoder) throws { wrappedValue = Set(try decoder.singleValueContainer().decode([String].self)) }
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(wrappedValue.sorted())
  }
}

@Observable @MainActor final class AppStore {
  var state = LocalState()
  var notice: String?
  var tab = 0
  /// A post the member chose to repost; the feed's inline composer consumes it.
  var quoteRequest: String?
  let campus = CampusService()
  let compositions = DurableCompositions()
  private(set) var sendingQueuedID: String?
  private var drainingOutbox = false
  let auth: EmailAuthService
  let social: SocialService
  let tag: TagService
  let courseTerms: CourseTermsService
  var connected = false
  var syncing = false
  var busy = false
  var connectionError: String?
  var nsfwEnabled = false
  var karma = 0
  var ownPostIDs: Set<String> = []
  var ownCommentIDs: Set<String> = []
  var ownMessageIDs: Set<String> = []
  var conversationMeta: [String: SocialConversationMeta] = [:]
  var attachments: [SocialAttachmentReference] = []
  var organizations: [SocialOrganization] = []
  var feedPostIDs: Set<String>?
  private var feedIDsCommunity: Community?
  /// Set when a delta could not describe every change; the next snapshot rebuilds the feed.
  private var feedNeedsReset = false
  private(set) var loadingMoreFeed = false
  private(set) var feedLoadFailed = false
  private(set) var loadingComments: Set<String> = []
  /// Posts whose held replies reach the thread's first reply (the oldest held id when
  /// "Load earlier replies" found no older page). A merge that drops held replies invalidates it.
  private(set) var firstReplyIDs: [String: String] = [:]
  private var feedDeltaRunning = false
  /// Bumped whenever the feed is rebuilt from a first page; Hot refills its window after it.
  private(set) var feedGeneration = 0
  private(set) var fillingFeed = false
  private var roomSyncUnsupported = false
  private var lastSnapshot = Date.distantPast
  /// The last snapshot's server clock (with overlap): where an open room's change polling starts.
  private var snapshotClock: Double?
  /// Rooms an open ChatView follows (a count, since the same room can be pushed twice).
  private var openRooms: [String: Int] = [:]
  /// Per open room, the server clock from which `room.messages` reports changed held messages.
  private var roomChangeClocks: [String: Double] = [:]
  private(set) var loadingEarlierMessages: Set<String> = []
  /// Rooms whose held messages start at the conversation's first message.
  private var roomHistoryComplete: Set<String> = []
  private var lastSavedDigest: SHA256.Digest?
  /// Number of times the cache file was actually written (saves skip identical bytes).
  private(set) var diskWrites = 0
  private(set) var feedCommunity = Community.campus
  private(set) var loadingCommunity = false
  private(set) var tagPages: [SocialTagQuery: SocialTagPage] = [:]
  private var tagOwners: [UUID: SocialTagQuery] = [:]
  private var libraryOwners: [UUID: SocialLibraryQuery] = [:]
  private(set) var libraryPages: [SocialLibraryQuery: SocialLibraryPage] = [:]
  private(set) var fixtureMode: Bool
  /// Supabase Realtime pokes (inert in fixture mode). While `realtime.connected`, open rooms stop polling.
  let realtime: RealtimeService
  private var pokeQueue: [RealtimePoke] = []
  private var pokeDrain: Task<Void, Never>?
  /// A poke asked for a snapshot that has not started yet (see `requestSnapshot`).
  private(set) var snapshotRequested = false
  /// When this device last sent `room.typing`, per room: the server echoes it back as a poke.
  private var typingSent: [String: Date] = [:]
  /// When the server last showed a room's typing indicator (realtime mode expires it locally).
  private var typingSeen: [String: Date] = [:]
  private var polling = false
  private let refreshWork = RefreshWork()
  private var pendingPost: (key: String, nonce: String, id: String?, attachmentID: String?)?
  private var creatingPost = false
  private var pendingComments: [String: String] = [:]
  private var pendingUploads: [String: String] = [:]
  private let file: URL
  static func storageFileURL(arguments: [String], directory: URL = .documentsDirectory) -> URL {
    let testing = arguments.contains("--uitesting") || arguments.contains("--uitesting-preserve")
    return directory.appending(path: testing ? "preview-state-ui-tests.json" : "preview-state.json")
  }
  init(storageURL: URL? = nil, arguments: [String] = ProcessInfo.processInfo.arguments, courseTermService: CourseTermsService? = nil, socialService: SocialService? = nil, realtime: RealtimeService? = nil) {
    let usesFixtures = storageURL != nil || arguments.contains("--uitesting") || arguments.contains("--uitesting-preserve")
    let auth = usesFixtures ? EmailAuthService.unavailableForFixtures() : EmailAuthService()
    self.auth = auth
    self.social = socialService ?? SocialService(credentials: usesFixtures ? SocialCredentialStore(read: { nil }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {}) : nil, auth: usesFixtures ? nil : auth)
    self.tag = TagService(social: social)
    self.courseTerms = courseTermService ?? CourseTermsService(social: social, fixtureMode: usesFixtures)
    fixtureMode = usesFixtures && socialService == nil
    // UI tests and fixture journeys have no realtime: the service stays inert.
    self.realtime = realtime ?? (usesFixtures ? .inert() : .live(social: social))
    file = storageURL ?? (usesFixtures ? Self.storageFileURL(arguments: arguments) : URL.documentsDirectory.appending(path: "social-cache.json"))
    if arguments.contains("--uitesting") && !arguments.contains("--uitesting-preserve") {
      try? FileManager.default.removeItem(at: file)
    }
    if let data = try? Data(contentsOf: file),
      let saved = try? JSONDecoder().decode(LocalState.self, from: data)
    {
      state = saved
    }
    if !usesFixtures, state.onboarded, !social.hasStoredCredential { state = LocalState() }
    if fixtureMode, state.posts.isEmpty && !state.onboarded {
      seed()
      if arguments.contains("--uitesting-feed-pages") { seedFeedPages() }
    }
    if let ids = state.feedPostIDs, state.feedCommunity == feedCommunity.rawValue {
      feedPostIDs = Set(ids); feedIDsCommunity = feedCommunity
    } else {
      state.feedPostIDs = nil; state.feedCommunity = nil; state.feedCursor = nil; state.feedSince = nil
    }
    if fixtureMode {
      organizations = [OrganizationAccessFixture.managedOrganization, OrganizationAccessFixture.invitingOrganization]
      conversationMeta = Self.fixtureConversationMeta.filter { id, _ in state.conversations.contains { $0.id == id } }
    }
    if !usesFixtures, !state.onboarded, social.hasStoredCredential,
      let data = try? Data(contentsOf: Self.storageFileURL(arguments: [])),
      let previous = try? JSONDecoder().decode(LocalState.self, from: data), previous.onboarded {
      // Keep the previous local-only file intact. Only account preferences migrate.
      state.username = previous.username
      state.adult = previous.adult
      state.onboarded = previous.onboarded
    }
    if state.draftOwner == nil { state.draftOwner = UUID().uuidString }
    compositions.configure(file: file.deletingPathExtension().appendingPathExtension("compositions.json"), owner: state.draftOwner!, reset: arguments.contains("--uitesting") && !arguments.contains("--uitesting-preserve"))
    save()
    courseTerms.onChange = { [weak self] in self?.removeExpiredCourseContent() }
    removeExpiredCourseContent()
    self.realtime.onPoke = { [weak self] poke in self?.enqueue(poke) }
  }
  func canAccessConversation(_ id: String) -> Bool {
    if let course = state.courses.first(where: { $0.id == id }) { return courseTerms.canAccess(term: course.term) }
    return conversationMeta[id]?.kind != "course"
  }
  private func removeExpiredCourseContent() {
    let expired = Set(state.courses.filter { !courseTerms.canAccess(term: $0.term) }.map(\.id))
    guard !expired.isEmpty else { return }
    state.courses.removeAll { expired.contains($0.id) }
    state.conversations.removeAll { expired.contains($0.id) }
    for id in expired { conversationMeta.removeValue(forKey: id) }
    attachments.removeAll { $0.roomID.map(expired.contains) == true }
    save()
  }
  /// Writes the cache only when its bytes changed (SHA-256 of the encoded state), so a
  /// poll that brought nothing new costs no disk write.
  @discardableResult
  func save() -> Bool {
    do {
      var persisted = state
      // Read times only order copies within one run; anything fetched after a launch is newer
      // than the cache, and leaving them out keeps an unchanged snapshot from rewriting the file.
      for index in persisted.posts.indices { persisted.posts[index].syncedAt = nil }
      persisted.feedPostIDs = feedPostIDs.map { ids in
        state.posts.filter { ids.contains($0.id) }.sorted { $0.created > $1.created }.map(\.id)
      }
      persisted.feedCommunity = feedPostIDs == nil ? nil : feedCommunity.rawValue
      // Game-day chat lives in memory only (its last 50 messages); the snapshot refills it.
      for index in persisted.conversations.indices where isGameRoom(persisted.conversations[index].id) {
        persisted.conversations[index].messages = []
        persisted.roomCursors?.removeValue(forKey: persisted.conversations[index].id)
      }
      if persisted.roomCursors?.isEmpty == true { persisted.roomCursors = nil }
      if !fixtureMode { persisted = Self.evicted(persisted, ownPostIDs: ownPostIDs, now: .now) }
      let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
      let data = try encoder.encode(persisted)
      let digest = SHA256.hash(data: data)
      if digest == lastSavedDigest { return true }
      try data.write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
      lastSavedDigest = digest; diskWrites += 1
      return true
    } catch {
      notice = "Your changes could not be saved on this device. Please try again."
      return false
    }
  }
  /// Persisted cache caps (eviction). Memory may hold more while the app runs:
  /// - posts: the 100 newest feed posts, plus saved and own posts the store still holds
  ///   (tag and library pages are not persisted otherwise);
  /// - messages: the 50 newest per room;
  /// - rooms not opened for 30 days keep their conversation row but drop their messages.
  /// The next snapshot (launch, foreground) refills the newest page of everything.
  static let persistedFeedPosts = 100
  static let persistedMessagesPerRoom = 50
  static let roomMessageRetention: TimeInterval = 30 * 86_400
  static func evicted(_ state: LocalState, ownPostIDs: Set<String>, now: Date) -> LocalState {
    var result = state
    let feedIDs = state.feedPostIDs.map(Set.init)
    let feed = state.posts.filter { feedIDs?.contains($0.id) ?? true }.sorted { $0.created > $1.created }
    let keptFeed = Array(feed.prefix(persistedFeedPosts))
    let keep = Set(keptFeed.map(\.id)).union(state.posts.filter { $0.saved || ownPostIDs.contains($0.id) }.map(\.id))
    result.posts = state.posts.filter { keep.contains($0.id) }
    if feedIDs != nil {
      result.feedPostIDs = keptFeed.map(\.id)
      // Dropped older pages are fetched again from just above the oldest kept post; the
      // microsecond margin turns any rounding into a harmless duplicate instead of a gap.
      if feed.count > keptFeed.count, state.feedSince != nil, let oldest = keptFeed.last {
        result.feedCursor = SocialPageCursor(beforeCreated: oldest.created.timeIntervalSince1970 + 0.000_001, beforeID: oldest.id)
      }
    }
    var cursors = state.roomCursors ?? [:]
    let opened = (state.roomOpened ?? [:]).filter { id, _ in state.conversations.contains { $0.id == id } }
    for index in result.conversations.indices {
      let id = result.conversations[index].id
      if let seen = opened[id], now.timeIntervalSince(seen) > roomMessageRetention {
        result.conversations[index].messages = []
      } else if result.conversations[index].messages.count > persistedMessagesPerRoom {
        result.conversations[index].messages = Array(result.conversations[index].messages.suffix(persistedMessagesPerRoom))
      }
      if result.conversations[index].messages.isEmpty { cursors.removeValue(forKey: id) }
    }
    cursors = cursors.filter { id, _ in result.conversations.contains { $0.id == id } }
    result.roomCursors = cursors.isEmpty ? nil : cursors
    result.roomOpened = opened.isEmpty ? nil : opened
    return result
  }
  func seed() {
    state.posts = [
      Post(
        author: "demo-ag", text: "The walk to class is somehow uphill in both directions.",
        score: 124,
        comments: [Comment(author: "demo-rev", text: "Especially when you're already late.")]),
      Post(
        id: "demo-coffee-post", author: "demo-espresso", anonymous: false,
        text: "Unofficial campus rule: getting coffee counts as being productive.", score: 86,
        acceptsDM: true),
      Post(
        author: "demo-chem",
        text: "CHEM 107 people: study room, whiteboard, and a very unreasonable amount of snacks?",
        score: 42, acceptsDM: true),
      Post(
        author: "demo-night", community: .nsfw,
        text: "How do you set boundaries with a roommate without making it weird?", score: 18),
    ]
    state.posts[1].repostCount = 1
    var quoted = Post(author: "demo-lab", anonymous: false, text: "Confirmed: this is how I passed CHEM", score: 12, created: .now.addingTimeInterval(1))
    quoted.quote = PostQuote(quoting: state.posts[1])
    var orphan = Post(id: "demo-missing-quote-post", author: "demo-quiet", text: "Someone said it better than I could.", score: 3, created: .now.addingTimeInterval(2))
    orphan.quote = PostQuote(id: "demo-deleted-post", unavailable: true)
    // Appended so tests that read the first seeded post and its reply keep their fixture; the feed sorts by date.
    state.posts.append(contentsOf: [quoted, orphan])
    state.activities = [
      Activity(
        title: "Coffee, then absolutely no plans", kind: .hangout, host: "demo-espresso",
        place: "Memorial Student Center", starts: .now.addingTimeInterval(7200), capacity: 6,
        details:
          "A sample hangout. Pick a public spot, bring a friend, and stay as long as you like."),
      Activity(
        title: "One more pickup game", kind: .recreation, host: "demo-hoops",
        place: "Student Rec Center", starts: .now.addingTimeInterval(10800), capacity: 10,
        details: "Sample basketball plan. All skill levels welcome."),
      Activity(
        title: "CHEM 107 • whiteboard session", kind: .study, host: "demo-chem",
        place: "Evans Library", starts: .now.addingTimeInterval(86400), capacity: 5,
        details: "Practice problems and comparing notes.", course: "CHEM 107"),
      Activity(
        title: "Mario Kart & questionable driving", kind: .gaming, host: "demo-player",
        place: "MSC game area", starts: .now.addingTimeInterval(90000), capacity: 8,
        details: "Sample gaming hangout. Bring your own controller."),
    ]
    state.conversations = [
      Conversation(
        id: "demo-request", title: "Anonymous • coffee post", subtitle: "Message request · sample",
        messages: [Message(author: "Post author", text: "Any good coffee spots near campus?")],
        request: true, anonymous: true),
      Conversation(
        id: "demo-deleted-post-chat", title: "Anonymous conversation", subtitle: "Shared dm conversation",
        messages: [Self.fixtureHiddenGameInvitation, Self.fixtureHiddenGameInvitationReply, Message(author: "Them", text: "Thanks for the study room tip!")], anonymous: true),
    ]
  }
  /// An older 8 Ball invitation, as the server writes it. 8 Ball is hidden, so the chat
  /// shows a non-tappable "isn’t available" row for it (HiddenFeaturesUITests).
  static var fixtureHiddenGameInvitation: Message {
    var message = Message(author: "Them", text: "Pool invitation. Accept to start.", game: "8 Ball")
    message.id = "demo-hidden-game-invitation"
    message.gameSessionID = "6f1c2a5e-7b0d-4f8e-9a1b-3c4d5e6f7a8b"
    message.created = .now.addingTimeInterval(-900)
    return message
  }
  /// A reply that quotes the hidden invitation: the quote shows the unavailable copy, never the server body.
  static var fixtureHiddenGameInvitationReply: Message {
    var message = Message(author: "Them", text: "Are you free after class?")
    message.id = "demo-hidden-game-invitation-reply"
    message.replyTo = fixtureHiddenGameInvitation.id
    message.created = .now.addingTimeInterval(-600)
    return message
  }
  /// `--uitesting-feed-pages`: 40 older fixture posts so the feed has more than one page.
  /// Only the newest 30 posts start in the feed; `loadMoreFeed` pages the rest from `state`.
  func seedFeedPages() {
    let base = Date.now.addingTimeInterval(-3_600)
    for number in 1...40 {
      state.posts.append(Post(id: "fixture-page-post-\(number)", author: "demo-archive", text: "Archived campus thread \(number)",
        score: 40 - number, created: base.addingTimeInterval(Double(-number) * 600)))
    }
    let feed = state.posts.filter { $0.community == feedCommunity }.sorted { $0.created > $1.created }
    let first = feed.prefix(30)
    state.feedPostIDs = first.map(\.id); state.feedCommunity = feedCommunity.rawValue
    state.feedCursor = first.last.map { SocialPageCursor(beforeCreated: $0.created.timeIntervalSince1970, beforeID: $0.id) }
  }
  /// Preview rooms carry the metadata the server sends, so the inbox row, request panel
  /// and chat render their "From this post" tags without a backend: one live origin that
  /// opens a seeded post, one whose post is gone.
  static let fixtureConversationMeta: [String: SocialConversationMeta] = [
    "demo-request": SocialConversationMeta(id: "demo-request", kind: "dm", status: "pending", role: "member", canSend: false, unread: 0, lastRead: 0, pendingOutgoing: false,
      sourcePost: SourcePostContext(postID: "demo-coffee-post", excerpt: "Unofficial campus rule: getting coffee counts as being productive.")),
    "demo-deleted-post-chat": SocialConversationMeta(id: "demo-deleted-post-chat", kind: "dm", status: "active", role: "member", canSend: true, unread: 0, lastRead: 0, pendingOutgoing: false,
      sourcePost: SourcePostContext(postID: "demo-deleted-post", deleted: true, fromReply: true)),
  ]
  func enter(username: String) {
    if !fixtureMode { Task { await connect(username: username) }; return }
    let username = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard username.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil else {
      notice = "Use 3–20 letters, numbers or underscores for your username."
      return
    }
    let previous = state
    state.username = username
    state.onboarded = true
    state.adult = true
    if !save() { state = previous }
  }
  func vote(_ id: String, _ value: Int) {
    guard let post = state.posts.first(where: { $0.id == id }), post.deleted != true else { return }
    if !fixtureMode { Task { _ = await mutate("post.vote", ["post_id": id, "value": state.posts.first { $0.id == id }?.vote == value ? 0 : value]) }; return }
    guard let i = state.posts.firstIndex(where: { $0.id == id }) else { return }
    let previous = state.posts[i]
    state.posts[i].setVote(value)
    if !save() { state.posts[i] = previous }
  }
  func toggleSave(_ id: String) {
    if !fixtureMode {
      let saved = !(state.posts.first { $0.id == id }?.saved ?? false)
      Task {
        // Saved is projected for the saver alone, so no delta reports it: a post older than the
        // snapshot's first page takes the confirmed value here.
        guard await mutate("post.save", ["post_id": id, "saved": saved]),
          let index = state.posts.firstIndex(where: { $0.id == id }), state.posts[index].saved != saved else { return }
        state.posts[index].saved = saved
        save()
      }
      return
    }
    guard let i = state.posts.firstIndex(where: { $0.id == id }) else { return }
    state.posts[i].saved.toggle()
    if !save() { state.posts[i].saved.toggle() }
  }
  func joinCourse(_ course: Course) {
    guard courseTerms.canAccess(term: course.term) else { notice = "This semester’s class chats are closed."; return }
    if !fixtureMode { Task { _ = await mutate("course.join", ["code": course.code, "title": course.title, "term": course.term, "icon": course.icon]) }; return }
    let previous = state
    if !state.courses.contains(where: { $0.id == course.id }) { state.courses.append(course) }
    if !state.conversations.contains(where: { $0.id == course.id }) {
      state.conversations.append(
        Conversation(id: course.id, title: course.code,
                     subtitle: "\(course.term) · local course conversation"))
    }
    if !save() { state = previous }
  }
  func ensureActivityConversation(_ activity: Activity) {
    if !fixtureMode { Task { await refresh() }; return }
    guard let activity = state.activities.first(where: { $0.id == activity.id }),
      activity.participants.contains(state.username), !activity.cancelled,
      !state.conversations.contains(where: { $0.id == activity.id }) else { return }
    let previous = state
    state.conversations.append(
      Conversation(id: activity.id, title: activity.title, subtitle: "Local \(activity.kind.rawValue.lowercased()) conversation"))
    if !save() { state = previous }
  }
  func leaveConversation(_ id: String) {
    if !fixtureMode { Task { _ = await mutate("room.leave", ["room_id": id]) }; return }
    let previous = state
    let username = state.username
    state.conversations.removeAll { $0.id == id }
    state.courses.removeAll { $0.id == id }
    if let index = state.activities.firstIndex(where: { $0.id == id }) {
      if state.activities[index].host == username {
        state.activities[index].cancelled = true
      } else {
        state.activities[index].participants.removeAll { $0 == username }
      }
    }
    if !save() { state = previous }
  }
  func joinActivity(_ id: String) {
    if !fixtureMode { Task { _ = await mutate("activity.join", ["activity_id": id]) }; return }
    guard let i = state.activities.firstIndex(where: { $0.id == id }) else { return }
    let previous = state
    let username = state.username
    do {
      try state.activities[i].join(username)
      let a = state.activities[i]
      if !state.conversations.contains(where: { $0.id == id }) {
        state.conversations.append(Conversation(id: id, title: a.title, subtitle: a.kind.rawValue))
      }
      if !save() { state = previous }
    } catch { notice = error.localizedDescription }
  }
  @discardableResult
  func send(_ id: String, text: String, media: MediaAttachment? = nil, game: String? = nil) -> Bool {
    guard fixtureMode else { return false }
    do {
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      try MessageValidation.validate(text: trimmed, media: media.map { [$0] } ?? [])
      if let media, media.klipy == nil {
        guard let source = CGImageSourceCreateWithData(media.data as CFData, nil),
          CGImageSourceGetCount(source) > 0 else {
          notice = "That attachment is not a supported photo or GIF."
          return false
        }
      }
      guard trimmed.count <= 4000 else {
        notice = "Keep messages under 4,000 characters."
        return false
      }
      guard let i = state.conversations.firstIndex(where: { $0.id == id }) else {
        notice = "This conversation is no longer available."
        return false
      }
      guard !state.conversations[i].request else {
        notice = "Accept the message request before replying."
        return false
      }
      let message = Message(author: state.username, text: trimmed, media: media, game: game)
      state.conversations[i].messages.append(message)
      if isGameRoom(id) { state.conversations[i].messages = Self.trimmedGameRoom(state.conversations[i].messages) }
      guard save() else {
        state.conversations[i].messages.removeAll { $0.id == message.id }
        return false
      }
      return true
    } catch {
      notice = error.localizedDescription
      return false
    }
  }
  func report(_ id: String, reason: String) {
    if !fixtureMode { Task { _ = await mutate("report", ["target_type": "post", "target_id": id, "reason": reason]) }; return }
    let previous = state
    state.reports.append("\(id): \(reason)")
    state.hiddenPosts.insert(id)
    if save() {
      notice = "Hidden on this device. This preview does not send reports to moderators."
    } else { state = previous }
  }
}

extension AppStore {
  func selectCommunity(_ community: Community) async {
    guard community != feedCommunity else { return }
    feedCommunity = community; social.feedCommunity = community
    guard !fixtureMode else { return }
    loadingCommunity = true
    defer { if feedCommunity == community { loadingCommunity = false } }
    // Wait for any old feed request, then fetch after the selection changed. A mutation in
    // flight makes that fetch skip (busy), so wait for it and fetch again. A fetch that failed
    // is retried by the update loop, which snapshots until the feed matches the selection.
    for _ in 0..<60 {
      await refreshAfterMutation()
      guard feedCommunity == community, feedIDsCommunity != community, busy || syncing, !Task.isCancelled else { return }
      try? await Task.sleep(for: .milliseconds(250))
    }
  }
  func connect(username: String? = nil) async {
    guard !busy else { return }
    if fixtureMode { connected = true; return }
    let owner = compositions.owner
    busy = true
    defer { if compositions.owner == owner { busy = false } }
    do {
      let response = try await social.connect(username: (username ?? state.username).lowercased(), allowRegistration: username != nil)
      guard compositions.owner == owner else { return }
      apply(response)
      state.onboarded = true
      state.adult = true
      connected = true
      connectionError = nil
      save()
    } catch {
      guard compositions.owner == owner else { return }
      if (error as? SocialServiceError)?.code == "account_deleted" { resetDeletedAccount(); return }
      connected = false
      connectionError = error.localizedDescription
      if username != nil { notice = error.localizedDescription }
    }
  }
  func refresh() async {
    await refreshWork.run(joinExisting: false) { await self.fetchRefresh() }
  }
  /// Manual pulls await any existing background refresh instead of ending early.
  func refreshAndWait() async {
    await refreshWork.run(joinExisting: true) { await self.fetchRefresh() }
  }
  /// Communities have their own endpoint, so their successful mutations need
  /// a fresh social snapshot before presenting the resulting conversation.
  func refreshAfterMutation() async {
    await refreshWork.runAfterCurrent { await self.fetchRefresh() }
  }
  private func fetchRefresh() async {
    guard !fixtureMode, state.onboarded, !syncing, !busy else { return }
    let owner = compositions.owner
    // This snapshot starts after every poke that asked for one so far.
    snapshotRequested = false
    syncing = true
    defer { if compositions.owner == owner { syncing = false } }
    do {
      let result = connected ? try await social.refresh() : try await social.connect(username: state.username)
      guard compositions.owner == owner else { return }
      apply(result)
      connected = true
      connectionError = nil
    } catch {
      guard compositions.owner == owner else { return }
      if (error as? SocialServiceError)?.code == "account_deleted" { resetDeletedAccount(); return }
      connectionError = error.localizedDescription
    }
  }
  func runUpdates() async {
    guard !polling else { return }
    polling = true
    defer { polling = false }
    await connect()
    if connected && !fixtureMode {
      // Campus Tag is hidden: no session restore, so no Tag polling or location request.
      if FeatureAvailability.isCampusTagAvailable() { await tag.restoreSession() }
      await PushService.shared.configure(social: social)
    }
    await courseTerms.refresh()
    // Pokes for the inbox and open rooms while the app is active; inert in fixture mode. Until the
    // member channel joins (or after 10 s without a socket) open rooms keep their 3 s polling.
    let pokes = Task { await realtime.run() }
    defer { pokes.cancel() }
    var calendarRefresh = Date.now
    while !Task.isCancelled {
      do { try await Task.sleep(for: .seconds(3)) } catch { break }
      // Incremental servers: the feed asks for its delta every 3 s while the Community tab is
      // visible (an open ChatView polls its own room unless Realtime pokes it), and a slim snapshot reconciles the
      // rest every 60 s and after mutations. A server without deltas keeps the 3 s snapshot.
      // A feed that does not match the selected community (a switch whose snapshot was skipped
      // or failed) takes a snapshot instead of a delta.
      // A snapshot a poke asked for, which a mutation or another refresh held up, runs now.
      if snapshotRequested || !incrementalSync || feedIDsCommunity != feedCommunity || Date.now.timeIntervalSince(lastSnapshot) >= Self.reconciliationInterval { await refresh() }
      else if tab == 0 { await syncFeedDelta() }
      if connected && connectionError == nil { await flushOutbox() }
      courseTerms.advanceClock()
      if Date.now.timeIntervalSince(calendarRefresh) >= 300 { await courseTerms.refresh(); calendarRefresh = .now }
    }
  }
  static let reconciliationInterval: TimeInterval = 60
  /// The server answered the last snapshot with a delta clock, so deltas and pages exist.
  var incrementalSync: Bool { state.feedSince != nil }
  var feedHasMore: Bool { feedPostIDs != nil && state.feedCursor != nil }
  func apply(_ response: SocialResponse) {
    guard let snapshot = response.snapshot else { return }
    state.username = snapshot.username
    let currentFeed = snapshot.feedCommunity == nil || snapshot.feedCommunity == feedCommunity
    // Only a snapshot of the selected feed is a reconciliation: a mutation answered for the
    // previous community leaves the new one waiting for (and the loop asking for) its own.
    if currentFeed { lastSnapshot = .now }
    snapshotClock = snapshot.serverNow
    var feed = state.posts.filter { feedPostIDs?.contains($0.id) == true }
    if currentFeed {
      // The snapshot's posts are the first page. Cached older pages stay unless the page no
      // longer overlaps them (another community, a gap, or a requested rebuild).
      let page = snapshot.posts, pageIDs = Set(page.map(\.id))
      // The first clock from a server that just gained pages also starts over: the held feed
      // came without a cursor, so it could never page past what the old server sent.
      let upgraded = state.feedSince == nil && state.feedCursor == nil && snapshot.serverNow != nil && snapshot.feedNext != nil
      let reset = upgraded || feedNeedsReset || feedPostIDs == nil || feedIDsCommunity != feedCommunity || feedPostIDs?.isDisjoint(with: pageIDs) != false
      if reset {
        feed = page; state.feedCursor = snapshot.feedNext; state.feedSince = snapshot.serverNow; feedGeneration += 1
      } else {
        // The page is authoritative inside its window: a cached post there that it no
        // longer carries was deleted, hidden or blocked.
        if snapshot.feedNext != nil, let oldest = page.map(\.created).min() {
          feed.removeAll { $0.created >= oldest && !pageIDs.contains($0.id) }
        } else { feed.removeAll { !pageIDs.contains($0.id) }; state.feedCursor = nil }
        feed = Self.mergePosts(feed, with: page)
        // Keep the delta clock: jumping it forward would skip changes to older pages.
        if state.feedSince == nil { state.feedSince = snapshot.serverNow }
      }
      // A server without incremental reads sends no clock: no deltas and no paging.
      if snapshot.serverNow == nil { state.feedSince = nil; state.feedCursor = nil }
      feedPostIDs = Set(feed.map(\.id)); feedIDsCommunity = feedCommunity; feedNeedsReset = false
    }
    let activeQueries = Set(tagOwners.values)
    tagPages = tagPages.filter { activeQueries.contains($0.key) }
    for page in response.tagPages ?? [] where activeQueries.contains(page.query) { tagPages[page.query] = page }
    if !snapshot.nsfwEnabled { tagPages = tagPages.filter { $0.key.community != .nsfw } }
    let activeLibraryQueries = Set(libraryOwners.values)
    libraryPages = libraryPages.filter { activeLibraryQueries.contains($0.key) }
    for page in response.libraryPages ?? [] where activeLibraryQueries.contains(page.query) { libraryPages[page.query] = page }
    if !snapshot.nsfwEnabled {
      for key in libraryPages.keys {
        libraryPages[key]?.posts.removeAll { $0.community == .nsfw }
        let visible = Set(libraryPages[key]?.posts.map(\.id) ?? [])
        libraryPages[key]?.comments.removeAll { !visible.contains($0.postID) }
      }
    }
    if currentFeed { state.posts = mergeActivePostSources(feed: feed) }
    state.courses = snapshot.courses
    state.activities = snapshot.activities
    let held = Dictionary(state.conversations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    state.conversations = snapshot.conversations.map { incoming in
      // An open chat keeps the history it paged in or followed; other rooms take the newest window.
      guard openRooms[incoming.id] != nil, let current = held[incoming.id] else { roomHistoryComplete.remove(incoming.id); return incoming }
      var merged = incoming
      merged.messages = Self.mergedRoomMessages(held: current.messages, window: incoming.messages)
      return merged
    }
    // A window shorter than the snapshot's is the whole conversation.
    for conversation in snapshot.conversations where conversation.messages.count < Self.roomMessageWindow { roomHistoryComplete.insert(conversation.id) }
    let gameRooms = Set(snapshot.conversationMeta.filter { $0.kind == "sports" }.map(\.id))
    for index in state.conversations.indices where Self.isGameRoom(state.conversations[index].id) || gameRooms.contains(state.conversations[index].id) {
      state.conversations[index].messages = Self.trimmedGameRoom(state.conversations[index].messages)
    }
    var opened = state.roomOpened ?? [:], cursors = state.roomCursors ?? [:]
    for conversation in state.conversations {
      if opened[conversation.id] == nil { opened[conversation.id] = .now }
      if let last = conversation.messages.compactMap(\.sequence).max() { cursors[conversation.id] = last }
    }
    state.roomOpened = opened; state.roomCursors = cursors
    state.savedEvents = Set(snapshot.savedEvents)
    nsfwEnabled = snapshot.nsfwEnabled
    karma = snapshot.karma ?? 0
    ownPostIDs = Set(snapshot.ownPostIDs)
    ownCommentIDs = Set(snapshot.ownCommentIDs)
    ownMessageIDs = Set(snapshot.ownMessageIDs)
    conversationMeta = Dictionary(uniqueKeysWithValues: snapshot.conversationMeta.map { ($0.id, $0) })
    GroupPhotoCache.shared.synchronize(owner:compositions.owner,conversations:state.conversations,metadata:conversationMeta)
    attachments = snapshot.attachments
    organizations = snapshot.organizations
    removeExpiredCourseContent()
    save()
  }
  /// Active navigation leases survive a push to PostDetail and nested tag pages.
  /// Releasing the last owner removes that page's extra posts from the cache.
  func openTagScope(_ query: SocialTagQuery) -> TaggedPostLease {
    let owner = UUID(); tagOwners[owner] = query
    if !fixtureMode { social.retainTagQuery(query, owner: owner) }
    return TaggedPostLease(id: owner, query: query) { [weak self] owner in self?.closeTagScope(owner) }
  }
  private func closeTagScope(_ owner: UUID) {
    guard let query = tagOwners.removeValue(forKey: owner) else { return }
    social.releaseTagQuery(owner: owner)
    guard !tagOwners.values.contains(query) else { return }
    tagPages.removeValue(forKey: query)
    if !fixtureMode, let feedPostIDs {
      state.posts = mergeActivePostSources(feed: state.posts.filter { feedPostIDs.contains($0.id) })
    }
  }
  private func mergeActivePostSources(feed: [Post]) -> [Post] {
    var result = Self.mergePostSources(feed: feed, pages: Array(tagPages.values))
    for page in libraryPages.values.sorted(by: { $0.loadedAt < $1.loadedAt }) where page.error == nil {
      for post in page.posts {
        if let index = result.firstIndex(where: { $0.id == post.id }) { if !Self.isOlder(post, than: result[index]) { result[index] = post } }
        else { result.append(post) }
      }
    }
    return result
  }
  /// A copy the server read earlier than the one held loses a merge (`syncedAt`, the read time,
  /// orders copies without exposing when a post last changed). Copies without one always win.
  static func isOlder(_ post: Post, than held: Post) -> Bool {
    guard let incoming = post.syncedAt, let current = held.syncedAt else { return false }
    return incoming < current
  }
  /// Merges posts by id, keeping the most recently read copy. Replies older than the newest
  /// window the server sent (loaded with "Load earlier replies") are kept while they connect.
  static func mergePosts(_ existing: [Post], with incoming: [Post]) -> [Post] {
    var result = existing
    var index = Dictionary(result.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
    for var post in incoming {
      if let position = index[post.id] {
        let held = result[position]
        if isOlder(post, than: held) { continue }
        post.comments = mergedComments(held: held, incoming: post)
        result[position] = post
      } else { index[post.id] = result.count; result.append(post) }
    }
    return result
  }
  /// Older held replies stay only while they connect to the incoming window (the window
  /// overlaps them). Otherwise replies in between would be silently missing, so the thread
  /// keeps just the window and "Load earlier replies" pages back from it without a gap.
  static func mergedComments(held: Post, incoming: Post) -> [Comment] {
    guard let total = incoming.commentCount, total > incoming.comments.count,
      let oldest = incoming.comments.map(\.created).min() else { return incoming.comments }
    let sent = Set(incoming.comments.map(\.id))
    guard held.comments.contains(where: { sent.contains($0.id) }) else { return incoming.comments }
    return held.comments.filter { $0.created <= oldest && !sent.contains($0.id) } + incoming.comments
  }
  /// Merges messages by id/sequence; incoming copies replace held ones (edits, deletions, reactions).
  /// Sequenced messages sort by sequence; local messages without one (still sending) stay last.
  static func mergeMessages(_ existing: [Message], with incoming: [Message]) -> [Message] {
    var result = existing
    for message in incoming {
      if let position = result.firstIndex(where: { $0.id == message.id || ($0.sequence != nil && $0.sequence == message.sequence) }) {
        result[position] = message
      } else { result.append(message) }
    }
    let sequenced = result.filter { $0.sequence != nil }.sorted { $0.sequence! < $1.sequence! }
    return sequenced + result.filter { $0.sequence == nil }
  }
  /// The snapshot's newest window is authoritative inside its range (a held message missing
  /// from it was removed or blocked); held messages older than the window stay.
  static func mergedRoomMessages(held: [Message], window: [Message]) -> [Message] {
    guard let oldest = window.compactMap(\.sequence).min() else { return window }
    return mergeMessages(held.filter { ($0.sequence ?? .max) < oldest }, with: window)
  }
  func openLibraryScope(_ query: SocialLibraryQuery) -> LibraryPostLease {
    let owner = UUID(); libraryOwners[owner] = query
    if !fixtureMode { social.retainLibraryQuery(query, owner: owner) }
    return LibraryPostLease(id: owner, query: query) { [weak self] owner in self?.closeLibraryScope(owner) }
  }
  private func closeLibraryScope(_ owner: UUID) {
    guard let query = libraryOwners.removeValue(forKey: owner) else { return }
    social.releaseLibraryQuery(owner: owner)
    guard !libraryOwners.values.contains(query) else { return }
    libraryPages.removeValue(forKey: query)
    if !fixtureMode, let feedPostIDs { state.posts = mergeActivePostSources(feed: state.posts.filter { feedPostIDs.contains($0.id) }) }
  }
  /// The owning view asks for its page; snapshots no longer re-fetch retained pages.
  func loadLibraryPage(_ query: SocialLibraryQuery) async {
    guard !fixtureMode else { return }
    let owner = compositions.owner
    do {
      var page = try await social.library(query)
      guard compositions.owner == owner, libraryOwners.values.contains(query) else { return }
      if !nsfwEnabled {
        page.posts.removeAll { $0.community == .nsfw }
        let visible = Set(page.posts.map(\.id)); page.comments.removeAll { !visible.contains($0.postID) }
      }
      libraryPages[query] = page
    } catch {
      guard compositions.owner == owner, libraryOwners.values.contains(query), !(error is CancellationError) else { return }
      libraryPages[query] = SocialLibraryPage(query: query, error: error.localizedDescription)
    }
    refreshActivePosts()
  }
  private func refreshActivePosts() {
    guard let feedPostIDs else { state.posts = mergeActivePostSources(feed: state.posts); return }
    state.posts = mergeActivePostSources(feed: state.posts.filter { feedPostIDs.contains($0.id) })
  }
  func libraryPosts(_ queries: [SocialLibraryQuery]) -> [Post] {
    let ids = Set(queries.flatMap { libraryPages[$0]?.posts.map(\.id) ?? [] })
    return state.posts.filter { ids.contains($0.id) && $0.deleted != true && !state.hiddenPosts.contains($0.id) }
      .sorted { $0.created > $1.created }
  }
  func loadTagPage(_ query: SocialTagQuery) async {
    guard !fixtureMode else { return }
    let owner = compositions.owner
    do {
      let posts = try await social.posts(tag: query.tag, community: query.community)
      guard compositions.owner == owner, tagOwners.values.contains(query) else { return }
      tagPages[query] = SocialTagPage(query: query, posts: posts)
    } catch {
      guard compositions.owner == owner, tagOwners.values.contains(query), !(error is CancellationError) else { return }
      tagPages[query] = SocialTagPage(query: query, posts: [], error: error.localizedDescription)
    }
    refreshActivePosts()
  }
  func posts(for query: SocialTagQuery) -> [Post] {
    guard query.community != .nsfw || nsfwEnabled else { return [] }
    // A query owns membership/order, while the merged store owns current card
    // values. Overlapping pages may have arrived at different server instants.
    let membership = tagPages[query]?.posts ?? (fixtureMode ? state.posts.sorted { $0.created > $1.created } : [])
    let canonical = Dictionary(state.posts.map { ($0.id, $0) }, uniquingKeysWith: { _, newest in newest })
    let source = membership.compactMap { canonical[$0.id] }
    return source.filter { $0.community == query.community && $0.deleted != true && !state.hiddenPosts.contains($0.id) && ($0.tags ?? []).contains(query.tag) }
  }
  static func mergePostSources(feed: [Post], pages: [SocialTagPage]) -> [Post] {
    var result = feed
    for page in pages.sorted(by: { $0.loadedAt < $1.loadedAt }) where page.error == nil {
      for post in page.posts {
        if let index = result.firstIndex(where: { $0.id == post.id }) { if !isOlder(post, than: result[index]) { result[index] = post } }
        else { result.append(post) }
      }
    }
    return result
  }
  @discardableResult func perform(_ action: String, _ payload: [String: Any] = [:]) async -> SocialResponse? {
    guard !fixtureMode else { return fixturePerform(action, payload) }
    let owner = compositions.owner
    busy = true
    defer { if compositions.owner == owner { busy = false } }
    do {
      let response = try await social.perform(action, payload: payload)
      guard compositions.owner == owner else { return nil }
      apply(response)
      connectionError = nil
      connected = true
      return response
    } catch { if compositions.owner == owner { notice = error.localizedDescription }; return nil }
  }
  @discardableResult func mutate(_ action: String, _ payload: [String: Any] = [:]) async -> Bool {
    guard await perform(action, payload) != nil else { return false }
    // The snapshot only carries the first page; a delta brings the changed older post too.
    if Self.postMutations.contains(action) { await syncFeedDelta() }
    return true
  }
  static let postMutations: Set<String> = ["post.vote", "post.save", "post.delete", "post.attach", "poll.vote", "comment.create", "comment.delete", "comment.vote", "report", "block"]

  // MARK: Incremental feed, replies and rooms
  /// Applies `feed.delta`: changed posts replace held copies (the most recently read copy wins)
  /// and join the feed; removed ids leave every cache. A truncated delta, or one asking this
  /// member to resync, refetches the held pages instead of collapsing the feed.
  func syncFeedDelta() async {
    guard !fixtureMode, connected, state.onboarded, !feedDeltaRunning, let since = state.feedSince, feedPostIDs != nil else { return }
    // A feed still showing another community waits for that community's snapshot: a delta would
    // ask for the new community with the old feed's ids and report every one of them removed.
    guard feedIDsCommunity == feedCommunity else { lastSnapshot = .distantPast; return }
    let owner = compositions.owner, community = feedCommunity
    feedDeltaRunning = true
    defer { if compositions.owner == owner { feedDeltaRunning = false } }
    do {
      let delta = try await social.feedDelta(community: community, since: since, knownIDs: heldFeedIDs())
      guard compositions.owner == owner, feedCommunity == community, feedIDsCommunity == community, state.feedSince == since else { return }
      guard delta.truncated == true || delta.resync == true else { applyFeedDelta(delta); return }
      // `removed` is complete either way; a truncated `changed` is not, so the held posts (and,
      // for posts created meanwhile, the first page) are read again before the clock moves.
      var complete = delta
      if delta.truncated == true { complete.changed = [] }
      applyFeedDelta(complete, advanceClock: false)
      guard await refetchHeldFeed(owner: owner, community: community, includeFirstPage: delta.truncated == true),
        state.feedSince == since else { return }
      state.feedSince = delta.now
      save()
    } catch {
      guard compositions.owner == owner else { return }
      // A server without incremental reads answers "invalid": fall back to snapshots.
      if (error as? SocialServiceError)?.code == "invalid" { state.feedSince = nil }
    }
  }
  /// The held feed posts deltas cover: the 300 newest.
  private func heldFeedIDs() -> [String] {
    guard let ids = feedPostIDs else { return [] }
    return state.posts.filter { ids.contains($0.id) }.sorted { $0.created > $1.created }.prefix(300).map(\.id)
  }
  /// Reads the held feed posts again with `feed.posts` (50 per call), plus the first page after a
  /// truncated delta. A first page that no longer overlaps the feed (more new posts than a page)
  /// starts the feed over from it. Returns false when a read failed or the feed changed meanwhile;
  /// the delta clock then stays, so the next delta asks again.
  private func refetchHeldFeed(owner: String, community: Community, includeFirstPage: Bool) async -> Bool {
    let ids = heldFeedIDs()
    for start in stride(from: 0, to: ids.count, by: 50) {
      do {
        let page = try await social.feedPosts(community: community, ids: Array(ids[start..<min(ids.count, start + 50)]))
        guard compositions.owner == owner, feedCommunity == community, feedIDsCommunity == community else { return false }
        applyFeedDelta(SocialFeedDelta(changed: page.posts, removed: page.removed, now: 0), advanceClock: false)
      } catch { return false }
    }
    guard includeFirstPage else { return true }
    do {
      let page = try await social.feedPage(community: community, cursor: nil)
      guard compositions.owner == owner, feedCommunity == community, feedIDsCommunity == community, let held = feedPostIDs else { return false }
      if !page.posts.isEmpty && held.isDisjoint(with: page.posts.map(\.id)) {
        let feed = page.posts
        feedPostIDs = Set(feed.map(\.id)); state.feedCursor = page.next; feedGeneration += 1
        state.posts = mergeActivePostSources(feed: Self.mergePosts(state.posts.filter { feedPostIDs?.contains($0.id) == true }, with: feed))
        save()
      } else {
        applyFeedDelta(SocialFeedDelta(changed: page.posts, removed: [], now: 0), advanceClock: false)
      }
      return true
    } catch { return false }
  }
  func applyFeedDelta(_ delta: SocialFeedDelta, advanceClock: Bool = true) {
    guard let ids = feedPostIDs else { return }
    let removed = Set(delta.removed)
    var feed = state.posts.filter { ids.contains($0.id) && !removed.contains($0.id) }
    feed = Self.mergePosts(feed, with: delta.changed.filter { !removed.contains($0.id) })
    feedPostIDs = Set(feed.map(\.id))
    if !removed.isEmpty {
      for key in tagPages.keys { tagPages[key]?.posts.removeAll { removed.contains($0.id) } }
      for key in libraryPages.keys { libraryPages[key]?.posts.removeAll { removed.contains($0.id) } }
    }
    state.posts = mergeActivePostSources(feed: feed)
    if advanceClock { state.feedSince = delta.now }
    save()
  }
  /// Scroll end: the next keyset page of the selected community.
  func loadMoreFeed() async {
    guard !loadingMoreFeed, let cursor = state.feedCursor, let ids = feedPostIDs else { return }
    let owner = compositions.owner, community = feedCommunity
    loadingMoreFeed = true; feedLoadFailed = false
    defer { if compositions.owner == owner { loadingMoreFeed = false } }
    let page: SocialFeedPage
    if fixtureMode {
      // Stand in for network latency so the loading row is observable in UI journeys.
      try? await Task.sleep(for: .seconds(2))
      page = fixtureFeedPage(after: cursor, excluding: ids)
    }
    else {
      do { page = try await social.feedPage(community: community, cursor: cursor) }
      catch {
        guard compositions.owner == owner, feedCommunity == community else { return }
        // A view that went away cancels its page; that is not a failure to show.
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
        // "invalid" means the server has no pages; stop offering more instead of failing.
        if (error as? SocialServiceError)?.code == "invalid" { state.feedCursor = nil } else { feedLoadFailed = true }
        return
      }
    }
    guard compositions.owner == owner, feedCommunity == community, state.feedCursor == cursor, let current = feedPostIDs else { return }
    let feed = Self.mergePosts(state.posts.filter { current.contains($0.id) }, with: page.posts)
    feedPostIDs = Set(feed.map(\.id)); state.feedCursor = page.next
    state.posts = fixtureMode ? Self.mergePosts(state.posts, with: page.posts) : mergeActivePostSources(feed: feed)
    save()
  }
  /// Hot ranks a fixed window of the newest posts (the window the feed ranked before it paged),
  /// so pages loaded while reading never re-rank older posts above the member's position.
  static let hotWindow = 150
  /// Loads pages until the Hot window is full or the feed ends.
  func fillFeedForHot() async {
    guard !fillingFeed else { return }
    fillingFeed = true
    defer { fillingFeed = false }
    for _ in 0..<10 {
      let before = feedPostIDs?.count ?? 0
      guard feedHasMore, before < Self.hotWindow, !Task.isCancelled else { return }
      await loadMoreFeed()
      guard !feedLoadFailed, (feedPostIDs?.count ?? 0) > before else { return }
    }
  }
  /// Fixture pages come from `state`: posts of the feed's community older than the cursor.
  private func fixtureFeedPage(after cursor: SocialPageCursor, excluding ids: Set<String>) -> SocialFeedPage {
    let older = state.posts.filter { post in
      let created = post.created.timeIntervalSince1970
      return !ids.contains(post.id) && post.community == feedCommunity
        && (created < cursor.beforeCreated || (created == cursor.beforeCreated && post.id < cursor.beforeID))
    }.sorted { $0.created > $1.created }
    let page = Array(older.prefix(30))
    let next = older.count > page.count ? page.last.map { SocialPageCursor(beforeCreated: $0.created.timeIntervalSince1970, beforeID: $0.id) } : nil
    return SocialFeedPage(posts: page, next: next)
  }
  /// More replies exist than are held, and the held ones do not reach the thread's first reply.
  func hasEarlierReplies(_ post: Post) -> Bool {
    guard let total = post.commentCount, total > post.comments.count else { return false }
    guard let first = firstReplyIDs[post.id] else { return true }
    return post.comments.min(by: { ($0.created, $0.id) < ($1.created, $1.id) })?.id != first
  }
  /// "Load earlier replies": the page before the oldest reply held for this post.
  func loadEarlierComments(_ postID: String) async {
    guard !fixtureMode, !loadingComments.contains(postID), let post = state.posts.first(where: { $0.id == postID }),
      let oldest = post.comments.min(by: { ($0.created, $0.id) < ($1.created, $1.id) }) else { return }
    let owner = compositions.owner
    loadingComments.insert(postID)
    defer { if compositions.owner == owner { loadingComments.remove(postID) } }
    // A microsecond margin above the oldest reply makes Date rounding a duplicate, never a gap.
    let cursor = SocialPageCursor(beforeCreated: oldest.created.timeIntervalSince1970 + 0.000_001, beforeID: oldest.id)
    do {
      let page = try await social.commentsPage(postID: postID, cursor: cursor)
      guard compositions.owner == owner, let index = state.posts.firstIndex(where: { $0.id == postID }) else { return }
      let held = Set(state.posts[index].comments.map(\.id))
      state.posts[index].comments = page.comments.filter { !held.contains($0.id) } + state.posts[index].comments
      if let total = page.commentCount { state.posts[index].commentCount = total }
      // No older page: the held replies now start at the first reply. The server's count stays,
      // so a mismatch never hides the button while replies are still missing.
      if page.next == nil, let first = state.posts[index].comments.min(by: { ($0.created, $0.id) < ($1.created, $1.id) }) {
        firstReplyIDs[postID] = first.id
      }
      save()
    } catch { if compositions.owner == owner { notice = error.localizedDescription } }
  }
  /// A thread whose newest replies answer replies that are not loaded yet pages back (at most
  /// three pages; a post accepts 200 replies) until those parents are present.
  func loadMissingParents(_ postID: String) async {
    for _ in 0..<3 {
      guard let post = state.posts.first(where: { $0.id == postID }), hasEarlierReplies(post) else { return }
      let held = Set(post.comments.map(\.id))
      guard post.comments.contains(where: { $0.parentID.map { !held.contains($0) } ?? false }) else { return }
      await loadEarlierComments(postID)
      guard let after = state.posts.first(where: { $0.id == postID })?.comments.count, after > post.comments.count else { return }
    }
  }
  /// An open ChatView follows its room: `room.messages after_seq` with the changes to held
  /// messages. While Realtime pokes the room (its channel is subscribed) new messages, edits,
  /// reactions, typing and room changes arrive as pokes and the view does not poll: a shown typing
  /// indicator clears locally once the server's 8 s window passes without a new typing poke.
  /// Otherwise it polls every 3 s. While it is open, snapshots merge into the room instead of
  /// replacing it.
  func followRoom(_ id: String) async {
    markRoomOpened(id)
    openRooms[id, default: 0] += 1
    defer {
      if let count = openRooms[id], count > 1 { openRooms[id] = count - 1 }
      else { openRooms.removeValue(forKey: id); roomChangeClocks.removeValue(forKey: id) }
    }
    guard !fixtureMode else { return }
    await syncRoom(id)
    guard !Task.isCancelled else { return }
    // Joining the room's channel catches it up once more (`.resync`), after this first read.
    realtime.follow(id)
    defer { realtime.unfollow(id) }
    while !Task.isCancelled {
      do { try await Task.sleep(for: .seconds(3)) } catch { break }
      if realtime.receives(room: id) { expireTyping(id) } else { await syncRoom(id) }
    }
  }
  /// Realtime mode: a shown typing indicator clears once the server's window has passed without
  /// the room confirming it again (each typing poke re-reads the room).
  func expireTyping(_ id: String, now: Date = .now) {
    guard conversationMeta[id]?.typing?.isEmpty == false else { typingSeen.removeValue(forKey: id); return }
    guard let seen = typingSeen[id] else { typingSeen[id] = now; return }
    guard now.timeIntervalSince(seen) >= Self.typingWindow else { return }
    conversationMeta[id]?.typing = nil
    typingSeen.removeValue(forKey: id)
  }
  /// `room.typing` shows the indicator for 8 s on the server.
  static let typingWindow: TimeInterval = 8
  /// The composer's typing ping (at most every 4 s). Its own poke comes back within this window
  /// and is ignored.
  func sendTyping(_ room: String) async {
    guard !fixtureMode else { return }
    typingSent[room] = .now
    _ = try? await social.perform("room.typing", payload: ["room_id": room])
  }
  static let ownTypingEcho: TimeInterval = 2
  /// Rooms an open ChatView follows.
  func isRoomOpen(_ id: String) -> Bool { openRooms[id] != nil }
  func markRoomOpened(_ id: String) {
    var opened = state.roomOpened ?? [:]; opened[id] = .now; state.roomOpened = opened
  }
  func syncRoom(_ id: String) async {
    guard !fixtureMode, connected, state.onboarded, !roomSyncUnsupported, incrementalSync, canAccessConversation(id),
      let conversation = state.conversations.first(where: { $0.id == id }),
      !(conversation.request && conversationMeta[id]?.kind != "dm") else { return }
    let owner = compositions.owner
    var after = conversation.messages.compactMap(\.sequence).max() ?? state.roomCursors?[id]
    var changedSince = roomChangeClocks[id] ?? snapshotClock
    for _ in 0..<5 {
      do {
        let page = try await social.roomMessages(roomID: id, afterSequence: after, changedSince: changedSince)
        guard compositions.owner == owner, let index = state.conversations.firstIndex(where: { $0.id == id }) else { return }
        // Changes only refresh messages already held; older history stays unloaded.
        let held = Set(state.conversations[index].messages.map(\.id))
        let updates = (page.changed ?? []).filter { held.contains($0.id) } + page.messages
        if let meta = page.meta {
          conversationMeta[id] = meta
          if meta.typing?.isEmpty == false { typingSeen[id] = .now } else { typingSeen.removeValue(forKey: id) }
        }
        if !updates.isEmpty {
          var merged = Self.mergeMessages(state.conversations[index].messages, with: updates)
          if isGameRoom(id) { merged = Self.trimmedGameRoom(merged) }
          if merged != state.conversations[index].messages { state.conversations[index].messages = merged }
        }
        if let now = page.now {
          changedSince = now
          if openRooms[id] != nil { roomChangeClocks[id] = now }
        }
        let last = state.conversations[index].messages.compactMap(\.sequence).max()
        if let last { var cursors = state.roomCursors ?? [:]; cursors[id] = last; state.roomCursors = cursors }
        save()
        guard page.more == true, let last, last != after else { return }
        after = last
      } catch {
        guard compositions.owner == owner else { return }
        if (error as? SocialServiceError)?.code == "invalid" { roomSyncUnsupported = true }
        return
      }
    }
  }
  /// The snapshot embeds each room's newest 50 messages.
  static let roomMessageWindow = 50
  /// A room may hold older messages than its window: "Earlier messages" pages them in.
  func hasEarlierMessages(_ id: String) -> Bool {
    guard !fixtureMode, !roomSyncUnsupported, incrementalSync, !roomHistoryComplete.contains(id), !isGameRoom(id),
      let conversation = state.conversations.first(where: { $0.id == id }) else { return false }
    return conversation.messages.count >= Self.roomMessageWindow
  }
  /// "Earlier messages": the page before the oldest message held in the room (`before_seq`).
  func loadEarlierMessages(_ id: String) async {
    guard !fixtureMode, !loadingEarlierMessages.contains(id), canAccessConversation(id), !isGameRoom(id),
      let oldest = state.conversations.first(where: { $0.id == id })?.messages.compactMap(\.sequence).min() else { return }
    let owner = compositions.owner
    loadingEarlierMessages.insert(id)
    defer { if compositions.owner == owner { loadingEarlierMessages.remove(id) } }
    do {
      let page = try await social.roomMessages(roomID: id, beforeSequence: oldest)
      guard compositions.owner == owner, let index = state.conversations.firstIndex(where: { $0.id == id }) else { return }
      if !page.messages.isEmpty { state.conversations[index].messages = Self.mergeMessages(state.conversations[index].messages, with: page.messages) }
      if page.more != true { roomHistoryComplete.insert(id) }
      save()
    } catch { if compositions.owner == owner { notice = error.localizedDescription } }
  }
  /// Fixture journeys exercise the navigation that follows a server answer
  /// without a network: a post-originated request and a game-day room are
  /// created locally with the same identifiers and metadata the gateway returns.
  private func fixturePerform(_ action: String, _ payload: [String: Any]) -> SocialResponse? {
    switch action {
    case "dm.request":
      guard let text = payload["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
      let id = "fixture-request-" + UUID().uuidString
      var message = Message(author: state.username, text: text); message.sequence = 1
      state.conversations.insert(Conversation(id: id, title: "Anonymous conversation", subtitle: "Request sent", messages: [message], request: false, anonymous: true), at: 0)
      var meta = SocialConversationMeta(id: id, kind: "dm", status: "pending", role: "member", canSend: false, unread: 0, lastRead: 1, pendingOutgoing: true)
      if let postID = payload["post_id"] as? String, let origin = state.posts.first(where: { $0.id == postID }) {
        meta.sourcePost = SourcePostContext(postID: postID, excerpt: String(origin.text.prefix(140)))
      }
      conversationMeta[id] = meta; _ = save()
      var response = SocialResponse(); response.resourceID = id; return response
    case "join_sports":
      guard let eventID = payload["event_id"] as? String, let event = campus.events.first(where: { $0.id == eventID }) else { return nil }
      let id = "sports:" + eventID
      if !state.conversations.contains(where: { $0.id == id }) {
        state.conversations.insert(Conversation(id: id, title: event.title, subtitle: "Shared sports conversation", messages: [], request: false, anonymous: false), at: 0)
      }
      conversationMeta[id] = SocialConversationMeta(id: id, kind: "sports", status: "active", role: "member", canSend: true, unread: 0, lastRead: 0, pendingOutgoing: false)
      _ = save()
      var response = SocialResponse(); response.resourceID = id; return response
    default: return nil
    }
  }
  @discardableResult func finishEmailLogin(username: String, adult: Bool, linkExisting: Bool) async -> Bool {
    guard !busy else { return false }
    busy = true
    defer { busy = false }
    do {
      let result = try await social.finishEmailLogin(username: username.lowercased(), adult: adult, linkExisting: linkExisting)
      if !linkExisting { resetDeletedAccount() }
      apply(result); state.onboarded = true; state.adult = true
      connected = true; connectionError = nil; save()
      return true
    } catch {
      if (error as? SocialServiceError)?.code == "account_deleted" { resetDeletedAccount(); return true }
      auth.error = error.localizedDescription; return false
    }
  }
  func signOut() async {
    guard !busy else { return }
    busy = true
    defer { busy = false }
    if !fixtureMode, !(await PushService.shared.unregister()) {
      notice = PushService.shared.error
      return
    }
    do { try await social.signOut(); resetDeletedAccount() }
    catch {
      notice = error.localizedDescription
      if !fixtureMode { await PushService.shared.configure(social: social) }
    }
  }
  @discardableResult func deleteAccount() async -> Bool {
    guard !busy else { return false }
    busy = true
    defer { busy = false }
    do {
      if !fixtureMode {
        // Server deletion also cascades push registrations; it must remain
        // available even if this device cannot unregister independently.
        try await social.deleteAccount()
        _ = await PushService.shared.unregister()
      }
      resetDeletedAccount()
      return true
    } catch { notice = error.localizedDescription; return false }
  }
  private func resetDeletedAccount() {
    tag.deactivate()
    state = LocalState()
    state.draftOwner = UUID().uuidString
    compositions.reset(owner: state.draftOwner!)
    GroupPhotoCache.shared.clear()
    // Identity changes already wipe it; fixture deletions and sign-outs must not leave media behind either.
    social.media.wipe()
    busy = false; syncing = false; creatingPost = false; drainingOutbox = false; sendingQueuedID = nil
    connected = false; connectionError = nil; nsfwEnabled = false; karma = 0; tab = 0
    ownPostIDs = []; ownCommentIDs = []; ownMessageIDs = []
    conversationMeta = [:]; attachments = []; organizations = []
    for owner in tagOwners.keys { social.releaseTagQuery(owner: owner) }
    tagOwners = [:]; tagPages = [:]; libraryOwners = [:]; libraryPages = [:]; feedPostIDs = nil
    feedIDsCommunity = nil; feedNeedsReset = false; feedLoadFailed = false; loadingMoreFeed = false; loadingComments = []
    feedDeltaRunning = false; roomSyncUnsupported = false; lastSnapshot = .distantPast
    firstReplyIDs = [:]; fillingFeed = false; snapshotClock = nil; openRooms = [:]; roomChangeClocks = [:]
    pokeQueue = []; snapshotRequested = false; typingSent = [:]; typingSeen = [:]; realtime.restart()
    loadingEarlierMessages = []; roomHistoryComplete = []; feedGeneration += 1
    feedCommunity = .campus; social.feedCommunity = .campus; loadingCommunity = false
    pendingPost = nil; pendingComments = [:]; pendingUploads = [:]
    save()
  }
  func owns(_ post: Post) -> Bool { fixtureMode ? post.author == state.username : ownPostIDs.contains(post.id) }
  func isMine(_ message: Message) -> Bool { fixtureMode ? message.author == state.username : ownMessageIDs.contains(message.id) }
  func createPost(text: String, anonymous: Bool, community: Community, acceptsDM: Bool, media: MediaAttachment? = nil, poll: PostPollDraft? = nil, linkURL: String? = nil, tags: [String] = [], quoting: String? = nil) async -> Bool {
    guard !creatingPost else { return false }
    let features: ValidatedPostFeatures
    do { features = try PostFeatureRules.validate(text: text, poll: poll, linkURL: linkURL, tags: tags, hasQuote: quoting != nil) }
    catch { notice = error.localizedDescription; return false }
    let owner = compositions.owner
    creatingPost = true
    defer { if compositions.owner == owner { creatingPost = false } }
    if fixtureMode {
      var post = Post(author: state.username, anonymous: anonymous, community: community, text: features.text, acceptsDM: acceptsDM)
      post.setVote(1)  // Your own post starts with your upvote, like the server's.
      post.media = media; post.linkURL = features.linkURL; post.tags = features.tags.isEmpty ? nil : features.tags
      if let draft = features.poll {
        post.poll = PostPoll(question: draft.question, options: draft.options.map { PostPollOption(text: $0) }, endsAt: .now.addingTimeInterval(Double(draft.durationHours) * 3600))
      }
      let previous = state.posts
      if let quoting {
        if let source = state.posts.firstIndex(where: { $0.id == quoting }), state.posts[source].deleted != true {
          post.quote = PostQuote(quoting: state.posts[source]); state.posts[source].repostCount += 1
        } else { post.quote = PostQuote(id: quoting, unavailable: true) }
      }
      state.posts.insert(post, at: 0)
      feedPostIDs?.insert(post.id)
      if save() { return true }; state.posts = previous; feedPostIDs?.remove(post.id); return false
    }
    let mediaKey = media.map { $0.klipy?.url ?? SHA256.hash(data: $0.data).map { String(format: "%02x", $0) }.joined() } ?? ""
    var payload: [String: Any] = ["text": features.text, "anonymous": anonymous, "community": community.rawValue, "acceptsDM": acceptsDM, "tags": features.tags]
    if let link = features.linkURL { payload["link_url"] = link }
    if let quoting { payload["quoted_post_id"] = quoting }
    if let draft = features.poll { payload["poll"] = ["question": draft.question, "options": draft.options, "duration_hours": draft.durationHours] }
    // Stable structured encoding prevents a changed poll/link/tag draft from reusing
    // the previous post's idempotency nonce, including after an upload retry.
    var identity = payload; identity["media"] = mediaKey
    guard let encoded = try? JSONSerialization.data(withJSONObject: identity, options: [.sortedKeys]) else { return false }
    let key = SHA256.hash(data: encoded).map { String(format: "%02x", $0) }.joined()
    if pendingPost == nil, let saved = compositions.draft("pending-post"), saved.fields["key"] == key {
      pendingPost = (key, saved.nonce, saved.fields["id"], saved.fields["attachmentID"])
    }
    if pendingPost?.key != key { pendingPost = (key, UUID().uuidString, nil, nil) }
    guard await persistPendingPost(owner: owner) else { notice = compositions.error; return false }
    payload["nonce"] = pendingPost!.nonce
    if pendingPost?.id == nil {
      guard let result = await perform("post.create", payload), let id = result.resourceID else { return false }
      guard compositions.owner == owner else { return false }
      pendingPost?.id = id
      guard await persistPendingPost(owner: owner) else { notice = compositions.error; return false }
    }
    if let media, let postID = pendingPost?.id {
      do {
        if pendingPost?.attachmentID == nil {
          // An upload may have committed even if its acknowledgement was lost.
          await refresh()
          guard compositions.owner == owner else { return false }
          if let existing = state.posts.first(where: { $0.id == postID })?.attachmentID { pendingPost?.attachmentID = existing }
          else {
            let attachmentID = try await social.upload(media, postID: postID)
            guard compositions.owner == owner else { return false }
            pendingPost?.attachmentID = attachmentID
          }
        }
        guard await persistPendingPost(owner: owner) else { notice = compositions.error; return false }
        guard let attachmentID = pendingPost?.attachmentID else { return false }
        guard await mutate("post.attach", ["post_id": postID, "attachment_id": attachmentID]) else { return false }
      } catch { guard compositions.owner == owner else { return false }; notice = "Your post was saved, but its attachment failed. Retry to finish attaching it. " + error.localizedDescription; return false }
    }
    guard compositions.owner == owner else { return false }
    if let reference = media?.klipy { Task { await KlipyService().share(reference) } }
    pendingPost = nil
    await compositions.removeDraft("pending-post", owner: owner)
    return true
  }

  func discardPendingPostDraft(owner expectedOwner: String? = nil) async {
    guard expectedOwner == nil || compositions.owner == expectedOwner else { return }
    let owner = compositions.owner
    pendingPost = nil
    await compositions.removeDraft("pending-post", owner: owner)
  }
  private func persistPendingPost(owner: String) async -> Bool {
    guard compositions.owner == owner else { return false }
    guard let pendingPost else { return true }
    var fields = ["key": pendingPost.key]
    if let id = pendingPost.id { fields["id"] = id }
    if let id = pendingPost.attachmentID { fields["attachmentID"] = id }
    return await compositions.saveDraft(CompositionDraft(fields: fields, nonce: pendingPost.nonce, hasContent: true), key: "pending-post", owner: owner)
  }

  @discardableResult func votePoll(postID: String, optionID: String) async -> Bool {
    guard let index = state.posts.firstIndex(where: { $0.id == postID }), state.posts[index].deleted != true,
          var poll = state.posts[index].poll, poll.endsAt > .now,
          poll.options.contains(where: { $0.id == optionID }) else { return false }
    if fixtureMode {
      let previous = poll
      guard poll.select(optionID) else { return false }
      state.posts[index].poll = poll
      if save() { return true }
      state.posts[index].poll = previous
      return false
    }
    return await mutate("poll.vote", ["post_id": postID, "option_id": optionID])
  }

  func createComment(postID: String, text: String, anonymous: Bool, parentID: String? = nil, nonce requestedNonce: String? = nil) async -> Bool {
    if fixtureMode {
      let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard let index = state.posts.firstIndex(where: { $0.id == postID }), state.posts[index].deleted != true,
            (1...2000).contains(body.count) else { return false }
      if let parentID {
        guard let parent = state.posts[index].comments.first(where: { $0.id == parentID }), parent.deleted != true else { return false }
      }
      // Only the author of an anonymous post is held anonymous in its thread.
      let post = state.posts[index]
      var comment = Comment(author: state.username, text: body, anonymous: anonymous || (post.anonymous && owns(post)), parentID: parentID)
      comment.setVote(1)
      state.posts[index].comments.append(comment)
      if save() { return true }; state.posts[index].comments.removeAll { $0.id == comment.id }; return false
    }
    let key = "\(postID)|\(parentID ?? "root")|\(anonymous)|\(text)"
    let nonce = requestedNonce ?? pendingComments[key] ?? UUID().uuidString
    pendingComments[key] = nonce
    var payload: [String: Any] = ["post_id": postID, "text": text, "anonymous": anonymous, "nonce": nonce]
    if let parentID { payload["parent_id"] = parentID }
    let success = await mutate("comment.create", payload)
    if success { pendingComments.removeValue(forKey: key) }
    return success
  }
  func voteComment(_ id: String, _ value: Int) {
    guard let postIndex = state.posts.firstIndex(where: { $0.comments.contains(where: { $0.id == id }) }),
          let commentIndex = state.posts[postIndex].comments.firstIndex(where: { $0.id == id }),
          state.posts[postIndex].deleted != true else { return }
    let comment = state.posts[postIndex].comments[commentIndex]
    guard comment.deleted != true, (-1...1).contains(value) else { return }
    if !fixtureMode {
      Task { _ = await mutate("comment.vote", ["comment_id": id, "value": comment.vote == value ? 0 : value]) }
      return
    }
    state.posts[postIndex].comments[commentIndex].setVote(value)
    if !save() { state.posts[postIndex].comments[commentIndex] = comment }
  }
  func owns(_ comment: Comment) -> Bool { fixtureMode ? comment.author == state.username : ownCommentIDs.contains(comment.id) }
  /// Changes the account username (already normalized and valid). Preview state renames
  /// its name-keyed ownership markers; the server keeps anonymous posts anonymous.
  func updateUsername(_ normalized: String) async -> Bool {
    guard AccountUsernameRules.valid(normalized) else { return false }
    guard normalized != state.username else { return true }
    if fixtureMode {
      let previous = state.username
      state.username = normalized
      for index in state.posts.indices {
        if state.posts[index].author == previous { state.posts[index].author = normalized }
        for reply in state.posts[index].comments.indices where state.posts[index].comments[reply].author == previous {
          state.posts[index].comments[reply].author = normalized
        }
      }
      if save() { return true }
      state.username = previous; return false
    }
    return await mutate("profile.update", ["username": normalized])
  }
  /// Named posting is allowed once the member has confirmed the username it will carry.
  var publicNameConfirmed: Bool { state.publicNameConfirmed == true }
  func confirmPublicName() { state.publicNameConfirmed = true; save() }
  func sendMessage(roomID: String, text: String, media: MediaAttachment?, replyTo: String? = nil, nonce: String) async -> Bool {
    guard canAccessConversation(roomID), state.conversations.contains(where: { $0.id == roomID && !$0.request }), conversationMeta[roomID]?.canSend != false else { notice = "This conversation is closed."; return false }
    if fixtureMode { return send(roomID, text: text, media: media) }
    let owner = compositions.owner
    do {
      guard text.count <= 4000 else { throw SocialServiceError(error: "Messages can be up to 4,000 characters.", code: "invalid") }
      try MessageValidation.validate(text: text, media: media.map { [$0] } ?? [])
      try await compositions.enqueue(QueuedMessage(nonce: nonce, roomID: roomID, text: text, media: media, replyID: replyTo))
      guard compositions.owner == owner else { return false }
      await flushOutbox()
      guard compositions.owner == owner else { return false }
      if let queued = compositions.queue.first(where: { $0.id == nonce }), queued.requiresRetry { notice = queued.failure; return false }
      return true
    } catch { if compositions.owner == owner { notice = error.localizedDescription }; return false }
  }
  func flushOutbox() async {
    guard !fixtureMode, state.onboarded, connected, connectionError == nil, !drainingOutbox else { return }
    let owner = compositions.owner
    drainingOutbox = true
    defer { if compositions.owner == owner { drainingOutbox = false; sendingQueuedID = nil } }
    for original in compositions.queue where !original.requiresRetry && original.nextAttempt <= .now {
      guard !Task.isCancelled, compositions.owner == owner, state.onboarded else { return }
      var message = original
      sendingQueuedID = message.id
      do {
        guard canAccessConversation(message.roomID), conversationMeta[message.roomID]?.canSend == true else { throw SocialServiceError(error: "This conversation is no longer available for sending. Your message remains here until you remove it.", code: "forbidden") }
        if let media = message.media, message.attachmentID == nil {
          message.attachmentID = try await social.upload(media, roomID: message.roomID)
          guard compositions.owner == owner else { return }
          try await compositions.update(message)
        }
        var payload: [String: Any] = ["room_id":message.roomID,"text":message.text,"nonce":message.nonce]
        if let reply = message.replyID { payload["reply_to"] = reply }
        if let attachment = message.attachmentID { payload["attachment_id"] = attachment }
        let response = try await social.perform("room.send", payload: payload)
        guard compositions.owner == owner else { return }
        apply(response)
        try await compositions.remove(message.id)
        if let reference = message.media?.klipy { Task { await KlipyService().share(reference) } }
      } catch {
        guard compositions.owner == owner else { return }
        message.attempts += 1; message.failure = error.localizedDescription
        let code = (error as? SocialServiceError)?.code
        let retryable = error is URLError || ["unavailable","upload_failed","rate_limit"].contains(code ?? "")
        message.requiresRetry = !retryable
        message.nextAttempt = .now.addingTimeInterval(min(300, pow(2, Double(min(message.attempts, 7))) * 3))
        try? await compositions.update(message)
        if retryable { break }
      }
    }
  }
  func retryQueuedMessage(_ id: String) async {
    guard sendingQueuedID != id else { return }
    do { try await compositions.retry(id); await flushOutbox() } catch { notice = error.localizedDescription }
  }
  func cancelQueuedMessage(_ id: String) async {
    guard sendingQueuedID != id else { return }
    do { try await compositions.remove(id) } catch { notice = error.localizedDescription }
  }
  func createActivity(_ activity: Activity, extra: [String: Any] = [:]) async -> Bool {
    if fixtureMode {
      state.activities.insert(activity, at: 0)
      state.conversations.append(Conversation(id: activity.id, title: activity.title, subtitle: activity.kind.rawValue))
      return save()
    }
    var payload: [String: Any] = ["title": activity.title, "kind": activity.kind.rawValue,
      "place": activity.place, "starts": activity.starts.timeIntervalSince1970,
      "capacity": activity.capacity, "details": activity.details, "nonce": UUID().uuidString]
    if let course = activity.course { payload["course"] = course }
    payload.merge(extra) { _, new in new }
    return await mutate("activity.create", payload)
  }
  func markRead(_ roomID: String) async {
    guard !fixtureMode, let meta = conversationMeta[roomID], meta.unread > 0 else { return }
    let owner = compositions.owner
    if let response = try? await social.perform("room.read", payload: ["room_id": roomID]), compositions.owner == owner { apply(response) }
  }
}

// MARK: - Realtime pokes and game-day chat (caching phase 3)
extension AppStore {
  /// Game-day chat keeps only its newest messages in memory and is never written to the cache.
  static let gameRoomMessageLimit = 50
  /// Game-day rooms are created by `join_sports` as `sports:<event>` with room kind "sports".
  static func isGameRoom(_ id: String) -> Bool { id.hasPrefix("sports:") }
  func isGameRoom(_ id: String) -> Bool { Self.isGameRoom(id) || conversationMeta[id]?.kind == "sports" }
  /// The newest `gameRoomMessageLimit` messages (sequenced ones; unsent local copies stay).
  static func trimmedGameRoom(_ messages: [Message]) -> [Message] {
    let sequenced = messages.filter { $0.sequence != nil }
    guard sequenced.count > gameRoomMessageLimit else { return messages }
    let floor = sequenced.compactMap(\.sequence).sorted().suffix(gameRoomMessageLimit).first ?? 0
    return messages.filter { ($0.sequence ?? .max) >= floor }
  }
  /// Pokes are handled one at a time in arrival order, so a room poke and the matching inbox poke
  /// for the same message cost one `room.messages` request.
  func enqueue(_ poke: RealtimePoke) {
    pokeQueue.append(poke)
    guard pokeDrain == nil else { return }
    pokeDrain = Task { [weak self] in
      while let self, !self.pokeQueue.isEmpty {
        let next = self.pokeQueue.removeFirst()
        await self.handle(next)
      }
      self?.pokeDrain = nil
    }
  }
  /// Enqueues a poke and waits until the queue is drained (tests).
  func receive(_ poke: RealtimePoke) async {
    enqueue(poke)
    await pokeDrain?.value
  }
  /// One poke, one read: `room.messages after_seq` for a held room the poke is ahead of, a snapshot
  /// for a room this device does not hold yet. Nothing is fetched for a sequence already held, and
  /// a read answers the pokes still queued behind it that it covers (it starts after they arrived).
  func handle(_ poke: RealtimePoke) async {
    guard !fixtureMode, connected, state.onboarded else { return }
    switch poke.kind {
    case .resync:
      if let room = poke.room {
        guard openRooms[room] != nil else { return }
        dropQueuedRoomPokes(room)
        await syncRoom(room)
        return
      }
      for id in openRooms.keys.sorted() { dropQueuedRoomPokes(id); await syncRoom(id) }
      // Inbox pokes sent while the member channel was away are gone too: one snapshot, unless one
      // just ran (the first join right after the app became active).
      if Date.now.timeIntervalSince(lastSnapshot) > Self.resyncSnapshotAge { await requestSnapshot() }
    case .message, .inbox:
      // Invitations, request answers and calls change the room row itself: the snapshot carries it.
      guard let room = poke.room, let seq = poke.seq, let conversation = state.conversations.first(where: { $0.id == room }) else {
        await requestSnapshot(); return
      }
      // Game-day chat is live only while it is open.
      if isGameRoom(room) && openRooms[room] == nil { return }
      if let held = conversation.messages.compactMap(\.sequence).max() ?? state.roomCursors?[room], seq <= held { return }
      await syncRoom(room)
    case .change, .typing:
      guard let room = poke.room, openRooms[room] != nil else { return }
      // This device's own typing comes back as a poke; it changes nothing here.
      if poke.kind == .typing, let sent = typingSent[room], Date.now.timeIntervalSince(sent) < Self.ownTypingEcho { return }
      dropQueuedRoomPokes(room)
      await syncRoom(room)
    }
  }
  /// A snapshot within this long before a member-channel catch-up already covers the inbox.
  static let resyncSnapshotAge: TimeInterval = 10
  /// A poke that needs the room list asks for a snapshot that starts after it arrived. A refresh
  /// already running may have read before the change, and a mutation in flight blocks refreshes,
  /// so the request stays pending (the update loop retries it every 3 s) until one starts.
  func requestSnapshot() async {
    pokeQueue.removeAll { poke in
      guard poke.kind == .inbox || poke.kind == .message else { return false }
      guard let room = poke.room, poke.seq != nil else { return true }
      return !state.conversations.contains { $0.id == room }
    }
    snapshotRequested = true
    await refreshAfterMutation()
  }
  /// Queued pokes for `room` that only ask for a read of it; a read starting now answers them.
  private func dropQueuedRoomPokes(_ room: String) {
    pokeQueue.removeAll { $0.room == room && ($0.kind == .change || $0.kind == .typing || $0.kind == .resync) }
  }
}
