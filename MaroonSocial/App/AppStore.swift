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
  var hiddenPosts: Set<String> = []
  var savedEvents: Set<String> = []
  var reports: [String] = []
}

@Observable @MainActor final class AppStore {
  var state = LocalState()
  var notice: String?
  var tab = 0
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
  private(set) var feedCommunity = Community.campus
  private(set) var loadingCommunity = false
  private(set) var tagPages: [SocialTagQuery: SocialTagPage] = [:]
  private var tagOwners: [UUID: SocialTagQuery] = [:]
  private var libraryOwners: [UUID: SocialLibraryQuery] = [:]
  private(set) var libraryPages: [SocialLibraryQuery: SocialLibraryPage] = [:]
  private(set) var fixtureMode: Bool
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
  init(storageURL: URL? = nil, arguments: [String] = ProcessInfo.processInfo.arguments, courseTermService: CourseTermsService? = nil, socialService: SocialService? = nil) {
    let usesFixtures = storageURL != nil || arguments.contains("--uitesting") || arguments.contains("--uitesting-preserve")
    let auth = usesFixtures ? EmailAuthService.unavailableForFixtures() : EmailAuthService()
    self.auth = auth
    self.social = socialService ?? SocialService(credentials: usesFixtures ? SocialCredentialStore(read: { nil }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {}) : nil, auth: usesFixtures ? nil : auth)
    self.tag = TagService(social: social)
    self.courseTerms = courseTermService ?? CourseTermsService(social: social, fixtureMode: usesFixtures)
    fixtureMode = usesFixtures && socialService == nil
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
    if fixtureMode, state.posts.isEmpty && !state.onboarded { seed() }
    if fixtureMode { organizations = [OrganizationAccessFixture.managedOrganization, OrganizationAccessFixture.invitingOrganization] }
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
  @discardableResult
  func save() -> Bool {
    do {
      var persisted = state
      if !fixtureMode, let feedPostIDs { persisted.posts.removeAll { !feedPostIDs.contains($0.id) } }
      try JSONEncoder().encode(persisted).write(
        to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
      return true
    } catch {
      notice = "Your changes could not be saved on this device. Please try again."
      return false
    }
  }
  func seed() {
    state.posts = [
      Post(
        author: "demo-ag", text: "The walk to class is somehow uphill in both directions.",
        score: 124,
        comments: [Comment(author: "demo-rev", text: "Especially when you're already late.")]),
      Post(
        author: "demo-espresso", anonymous: false,
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
        request: true, anonymous: true)
    ]
  }
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
    guard let post = state.posts.first(where: { $0.id == id }), !owns(post), post.deleted != true else { return }
    if !fixtureMode { Task { _ = await mutate("post.vote", ["post_id": id, "value": state.posts.first { $0.id == id }?.vote == value ? 0 : value]) }; return }
    guard let i = state.posts.firstIndex(where: { $0.id == id }) else { return }
    let previous = state.posts[i]
    state.posts[i].setVote(value)
    if !save() { state.posts[i] = previous }
  }
  func toggleSave(_ id: String) {
    if !fixtureMode { Task { _ = await mutate("post.save", ["post_id": id, "saved": !(state.posts.first { $0.id == id }?.saved ?? false)]) }; return }
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
    // Wait for any old feed request, then fetch after the selection changed.
    await refreshAfterMutation()
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
      await tag.restoreSession()
      await PushService.shared.configure(social: social)
    }
    await courseTerms.refresh()
    var calendarRefresh = Date.now
    while !Task.isCancelled {
      do { try await Task.sleep(for: .seconds(3)) } catch { break }
      await refresh()
      if connected && connectionError == nil { await flushOutbox() }
      courseTerms.advanceClock()
      if Date.now.timeIntervalSince(calendarRefresh) >= 300 { await courseTerms.refresh(); calendarRefresh = .now }
    }
  }
  func apply(_ response: SocialResponse) {
    guard let snapshot = response.snapshot else { return }
    state.username = snapshot.username
    let currentFeed = snapshot.feedCommunity == nil || snapshot.feedCommunity == feedCommunity
    if currentFeed { feedPostIDs = Set(snapshot.posts.map(\.id)) }
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
    if currentFeed { state.posts = mergeActivePostSources(feed: snapshot.posts) }
    state.courses = snapshot.courses
    state.activities = snapshot.activities
    state.conversations = snapshot.conversations
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
        if let index = result.firstIndex(where: { $0.id == post.id }) { result[index] = post }
        else { result.append(post) }
      }
    }
    return result
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
  func loadLibraryPage(_ query: SocialLibraryQuery) async {
    guard !fixtureMode else { return }
    let owner = compositions.owner
    if await perform("snapshot") == nil, compositions.owner == owner, libraryOwners.values.contains(query) {
      libraryPages[query] = SocialLibraryPage(query: query, error: notice ?? "Your collection could not load. Please retry.")
    }
  }
  func libraryPosts(_ queries: [SocialLibraryQuery]) -> [Post] {
    let ids = Set(queries.flatMap { libraryPages[$0]?.posts.map(\.id) ?? [] })
    return state.posts.filter { ids.contains($0.id) && $0.deleted != true && !state.hiddenPosts.contains($0.id) }
      .sorted { $0.created > $1.created }
  }
  func loadTagPage(_ query: SocialTagQuery) async {
    guard !fixtureMode else { return }
    let owner = compositions.owner
    if await perform("snapshot") == nil, compositions.owner == owner, tagOwners.values.contains(query) {
      tagPages[query] = SocialTagPage(query: query, posts: [], error: notice ?? "Posts could not load. Please retry.")
    }
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
        if let index = result.firstIndex(where: { $0.id == post.id }) { result[index] = post }
        else { result.append(post) }
      }
    }
    return result
  }
  @discardableResult func perform(_ action: String, _ payload: [String: Any] = [:]) async -> SocialResponse? {
    guard !fixtureMode else { return nil }
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
    await perform(action, payload) != nil
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
    busy = false; syncing = false; creatingPost = false; drainingOutbox = false; sendingQueuedID = nil
    connected = false; connectionError = nil; nsfwEnabled = false; karma = 0; tab = 0
    ownPostIDs = []; ownCommentIDs = []; ownMessageIDs = []
    conversationMeta = [:]; attachments = []; organizations = []
    for owner in tagOwners.keys { social.releaseTagQuery(owner: owner) }
    tagOwners = [:]; tagPages = [:]; libraryOwners = [:]; libraryPages = [:]; feedPostIDs = nil
    feedCommunity = .campus; social.feedCommunity = .campus; loadingCommunity = false
    pendingPost = nil; pendingComments = [:]; pendingUploads = [:]
    save()
  }
  func owns(_ post: Post) -> Bool { fixtureMode ? post.author == state.username : ownPostIDs.contains(post.id) }
  func isMine(_ message: Message) -> Bool { fixtureMode ? message.author == state.username : ownMessageIDs.contains(message.id) }
  func createPost(text: String, anonymous: Bool, community: Community, acceptsDM: Bool, media: MediaAttachment? = nil, poll: PostPollDraft? = nil, linkURL: String? = nil, tags: [String] = []) async -> Bool {
    guard !creatingPost else { return false }
    let features: ValidatedPostFeatures
    do { features = try PostFeatureRules.validate(text: text, poll: poll, linkURL: linkURL, tags: tags) }
    catch { notice = error.localizedDescription; return false }
    let owner = compositions.owner
    creatingPost = true
    defer { if compositions.owner == owner { creatingPost = false } }
    if fixtureMode {
      var post = Post(author: state.username, anonymous: anonymous, community: community, text: features.text, acceptsDM: acceptsDM)
      post.media = media; post.linkURL = features.linkURL; post.tags = features.tags.isEmpty ? nil : features.tags
      if let draft = features.poll {
        post.poll = PostPoll(question: draft.question, options: draft.options.map { PostPollOption(text: $0) }, endsAt: .now.addingTimeInterval(Double(draft.durationHours) * 3600))
      }
      state.posts.insert(post, at: 0)
      if save() { return true }; state.posts.removeAll { $0.id == post.id }; return false
    }
    let mediaKey = media.map { $0.klipy?.url ?? SHA256.hash(data: $0.data).map { String(format: "%02x", $0) }.joined() } ?? ""
    var payload: [String: Any] = ["text": features.text, "anonymous": anonymous, "community": community.rawValue, "acceptsDM": acceptsDM, "tags": features.tags]
    if let link = features.linkURL { payload["link_url"] = link }
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
      let comment = Comment(author: state.username, text: body, anonymous: anonymous || state.posts[index].anonymous, parentID: parentID)
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
    guard comment.deleted != true, !owns(comment), (-1...1).contains(value) else { return }
    if !fixtureMode {
      Task { _ = await mutate("comment.vote", ["comment_id": id, "value": comment.vote == value ? 0 : value]) }
      return
    }
    state.posts[postIndex].comments[commentIndex].setVote(value)
    if !save() { state.posts[postIndex].comments[commentIndex] = comment }
  }
  func owns(_ comment: Comment) -> Bool { fixtureMode ? comment.author == state.username : ownCommentIDs.contains(comment.id) }
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
