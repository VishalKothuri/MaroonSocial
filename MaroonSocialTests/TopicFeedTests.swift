import XCTest
import MaroonCore
@testable import MaroonSocial

/// Topic feeds: availability (and the old-server fallback), the keyed feed, topic deltas,
/// catalog drift and the topic a new post carries.
@MainActor final class TopicFeedTests: XCTestCase {
  private var directories: [URL] = []
  override func tearDown() {
    directories.forEach { try? FileManager.default.removeItem(at: $0) }
    directories = []
    super.tearDown()
  }
  private func credentials() -> SocialCredentialStore {
    SocialCredentialStore(read: { String(repeating: "a", count: 64) }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {})
  }
  private func encoded<Value: Encodable>(_ value: Value) throws -> Any {
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
    return try JSONSerialization.jsonObject(with: encoder.encode(value))
  }
  private func snapshot(_ posts: [Post], next: [String: Any]? = nil, serverNow: Double? = 500, resourceID: String? = nil) throws -> Data {
    var value: [String: Any] = ["username": "topic_tester", "nsfwEnabled": false, "posts": try encoded(posts), "courses": [], "activities": [],
      "conversations": [], "ownPostIDs": [], "ownCommentIDs": [], "ownMessageIDs": [], "conversationMeta": [],
      "attachments": [], "organizations": [], "savedEvents": []]
    if let next { value["feedNext"] = next }
    if let serverNow { value["serverNow"] = serverNow }
    var body: [String: Any] = ["snapshot": value]
    if let resourceID { body["resource_id"] = resourceID }
    return try JSONSerialization.data(withJSONObject: body)
  }
  private func file() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    directories.append(directory)
    return directory.appending(path: "social-cache.json")
  }
  private func networkStore(file: URL? = nil, _ transport: @escaping SocialService.Transport) throws -> AppStore {
    let store = AppStore(storageURL: try file ?? self.file(), arguments: [], socialService: SocialService(credentials: credentials(), transport: transport))
    store.state.username = "topic_tester"; store.state.onboarded = true; store.connected = true
    return store
  }
  private func post(_ number: Int, topic: String? = nil, synced: Double? = nil, community: Community = .campus) -> Post {
    var post = Post(id: "p\(number)", author: "Anonymous", community: community, text: "Post \(number)", created: Date(timeIntervalSince1970: 1_000_000 - Double(number)))
    post.topic = topic
    post.syncedAt = synced.map { Date(timeIntervalSince1970: $0) }
    return post
  }
  private func json(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
  private func topicRows(_ slugs: [String] = ["academics", "aggie_life", "questions", "housing", "sports", "relationships", "confessions", "memes"], count: Int = 7) -> [[String: Any]] {
    TopicCatalog.fallback.filter { slugs.contains($0.slug) }.map {
      ["slug": $0.slug, "title": $0.title, "emoji": $0.emoji, "text_hex": $0.textHex, "fill_hex": $0.fillHex, "sort_order": $0.order, "recent_count": count]
    }
  }
  private static let unknownAction = SocialServiceError(error: "Unknown social action.", code: "invalid")

  // MARK: Old server (no topics.list)

  /// Today's live server: `topics.list` is an unknown action. Topics stay off, every feed request
  /// and new post goes out without `topic`, and the store state is exactly the pre-topic feed.
  func testServerWithoutTopicsListKeepsTodaysFeedComposerAndCards() async throws {
    var requests: [(action: String, payload: [String: Any])] = []
    let first = (0..<30).map { post($0, synced: 100) }
    let store = try networkStore { [self] _, action, payload, _ in
      requests.append((action, payload))
      switch action {
      case "snapshot": return try snapshot(first, next: ["before_created": 999_971, "before_id": "p29"])
      case "topics.list": throw Self.unknownAction
      case "feed.page": return try json(["posts": try encoded((30..<35).map { post($0) }), "next": NSNull()])
      case "feed.delta": return try json(["changed": [], "removed": [], "now": 510])
      case "feed.posts": return try json(["posts": [], "removed": []])
      case "post.create": return try snapshot(first, next: ["before_created": 999_971, "before_id": "p29"], resourceID: "new-post")
      default: XCTFail("Unexpected \(action)"); return Data("{}".utf8)
      }
    }
    XCTAssertFalse(store.topicsAvailable, "Nothing is available before topics.list succeeds")
    await store.refresh()
    await store.refreshTopics()
    XCTAssertFalse(store.topicsAvailable); XCTAssertFalse(store.topicsLoaded)
    XCTAssertEqual(store.topics, []); XCTAssertNil(store.state.topicCatalog)
    // The strip, pill and topic row are all gated on topicsAvailable; selecting a topic is refused.
    XCTAssertNil(store.selectTopic("sports")); XCTAssertNil(store.feedTopic)
    XCTAssertEqual(store.currentFeedKey, FeedKey(community: .campus, topic: nil)); XCTAssertNil(store.topicFeedKey)
    XCTAssertEqual(store.feedIDs(for: store.currentFeedKey), store.feedPostIDs, "The feed shows the All ids, as before")
    XCTAssertEqual(store.feedPostIDs?.count, 30); XCTAssertTrue(store.feedHasMore)
    XCTAssertEqual(store.currentFeedCursor, store.state.feedCursor); XCTAssertFalse(store.currentFeedLoadFailed)
    XCTAssertTrue(TopicCatalog.canPublish(topic: nil, topicsAvailable: store.topicsAvailable, catalog: store.topics), "No topic is required")
    XCTAssertFalse(PostReportReason.options(topicsAvailable: store.topicsAvailable, postHasTopic: true).contains(PostReportReason.wrongTopic))
    await store.loadMoreFeed()
    await store.syncFeedDelta()
    let posted = await store.createPost(text: "Hello", anonymous: true, community: .campus, acceptsDM: true, topic: "sports")
    XCTAssertTrue(posted)
    XCTAssertEqual(store.feedPostIDs?.count, 35)
    XCTAssertTrue(store.topicFeeds.isEmpty)
    let actions = requests.map(\.action)
    XCTAssertEqual(actions.filter { $0 == "topics.list" }.count, 1)
    for action in ["feed.page", "feed.delta", "post.create"] { XCTAssertTrue(actions.contains(action), action) }
    for request in requests where request.action != "topics.list" {
      XCTAssertNil(request.payload["topic"], "\(request.action) must not carry a topic to a server without topics")
    }
    // The cache written for this server carries no catalog or topic keys.
    let data = try Data(contentsOf: try XCTUnwrap(directories.first).appending(path: "social-cache.json"))
    let text = String(decoding: data, as: UTF8.self)
    XCTAssertFalse(text.contains("\"topic\"") || text.contains("topicCatalog"))
  }

  /// A catalog cached from an earlier success keeps topics on while it refreshes; a network failure
  /// keeps it, and an answer that the action is unknown (the server was rolled back) turns topics off.
  func testCachedCatalogSurvivesNetworkFailureButNotAServerWithoutTopics() async throws {
    let cache = try file()
    var fail: Error = URLError(.notConnectedToInternet)
    let seeded = try networkStore(file: cache) { [self] _, action, _, _ in
      if action == "topics.list" { return try json(["topics": topicRows()]) }
      return try snapshot([])
    }
    await seeded.refreshTopics()
    XCTAssertTrue(seeded.topicsAvailable); XCTAssertEqual(seeded.state.topicCatalog?.count, 8)
    let relaunched = try networkStore(file: cache) { _, action, _, _ in
      if action == "topics.list" { throw fail }
      return Data("{}".utf8)
    }
    XCTAssertTrue(relaunched.topicsAvailable, "The cached catalog is used while it refreshes")
    await relaunched.refreshTopics()
    XCTAssertTrue(relaunched.topicsAvailable, "A network failure keeps the cached catalog")
    _ = relaunched.selectTopic("sports"); XCTAssertEqual(relaunched.feedTopic, "sports")
    fail = Self.unknownAction
    await relaunched.refreshTopics()
    XCTAssertFalse(relaunched.topicsAvailable); XCTAssertNil(relaunched.feedTopic); XCTAssertNil(relaunched.state.topicCatalog)
    XCTAssertTrue(relaunched.topicFeeds.isEmpty)
  }

  // MARK: Keyed feed

  func testSelectingATopicLoadsItsOwnKeyAndLeavesTheAllFeedAlone() async throws {
    var requests: [(action: String, payload: [String: Any])] = []
    let all = (0..<30).map { post($0, topic: $0.isMultiple(of: 3) ? "sports" : nil, synced: 100) }
    let sportsPage = (100..<130).map { post($0, topic: "sports", synced: 200) }
    let sportsOlder = (130..<140).map { post($0, topic: "sports", synced: 200) } + [post(100, topic: "sports", synced: 200)]
    let store = try networkStore { [self] _, action, payload, _ in
      requests.append((action, payload))
      switch action {
      case "snapshot": return try snapshot(all, next: ["before_created": 999_971, "before_id": "p29"])
      case "topics.list": return try json(["topics": topicRows()])
      case "feed.page":
        if payload["before_id"] == nil { return try json(["posts": try encoded(sportsPage), "next": ["before_created": 999_871, "before_id": "p129"]]) }
        return try json(["posts": try encoded(sportsOlder), "next": NSNull()])
      default: XCTFail("Unexpected \(action)"); return Data("{}".utf8)
      }
    }
    await store.refresh()
    await store.refreshTopics()
    XCTAssertTrue(store.topicsAvailable)
    let allIDs = store.feedPostIDs
    let key = FeedKey(community: .campus, topic: "sports")
    let task = store.selectTopic("sports")
    XCTAssertEqual(store.feedTopic, "sports"); XCTAssertEqual(store.currentFeedKey, key)
    // Before the first page arrives the key is not loaded: the feed shows its loading state, not the empty state.
    XCTAssertFalse(store.feedState(for: key).loaded)
    await task?.value
    let entry = store.feedState(for: key)
    XCTAssertTrue(entry.loaded); XCTAssertFalse(entry.loading); XCTAssertNil(entry.error)
    XCTAssertEqual(entry.ids.count, 30); XCTAssertEqual(entry.cursor, SocialPageCursor(beforeCreated: 999_871, beforeID: "p129"))
    XCTAssertEqual(entry.since, 500, "Deltas start from the clock read before the page")
    XCTAssertEqual(store.feedPostIDs, allIDs, "The All key is untouched")
    XCTAssertEqual(store.state.feedCursor, SocialPageCursor(beforeCreated: 999_971, beforeID: "p29"))
    XCTAssertTrue(store.feedHasMore); XCTAssertEqual(store.currentFeedCursor, entry.cursor)
    await store.loadMoreFeed()
    XCTAssertEqual(store.feedState(for: key).ids.count, 40, "The older page appends without duplicates")
    XCTAssertFalse(store.feedHasMore)
    let pages = requests.filter { $0.action == "feed.page" }
    XCTAssertEqual(pages.count, 2); XCTAssertTrue(pages.allSatisfy { $0.payload["topic"] as? String == "sports" })
    XCTAssertEqual(pages.last?.payload["before_id"] as? String, "p129")
    // Topic posts stay in the canonical list across a snapshot rebuild (they are not on All's page).
    await store.refresh()
    XCTAssertTrue(store.state.posts.contains { $0.id == "p135" })
    // Only the All key is persisted.
    let persisted = try JSONDecoder().decode(LocalState.self, from: Data(contentsOf: try XCTUnwrap(directories.first).appending(path: "social-cache.json")))
    XCTAssertEqual(persisted.feedPostIDs.map(Set.init), allIDs)
    XCTAssertFalse(persisted.posts.contains { $0.id == "p135" })
    // A selection is never remembered between launches.
    XCTAssertNil(AppStore(storageURL: try XCTUnwrap(directories.first).appending(path: "social-cache.json"), arguments: [], socialService: SocialService(credentials: credentials(), transport: { _, _, _, _ in Data() })).feedTopic)
  }

  func testTopicDeltaSendsTheTopicAndRemovesRetaggedPostsOnlyFromThatTopic() async throws {
    var requests: [(action: String, payload: [String: Any])] = []
    let all = (0..<5).map { post($0, topic: "sports", synced: 100) }
    var moved = post(1, topic: "academics", synced: 600)
    moved.text = "Retagged"
    let fresh = post(50, topic: "sports", synced: 600)
    let store = try networkStore { [self] _, action, payload, _ in
      requests.append((action, payload))
      switch action {
      case "snapshot": return try snapshot(all)
      case "topics.list": return try json(["topics": topicRows()])
      case "feed.page": return try json(["posts": try encoded(all), "next": NSNull()])
      case "feed.delta":
        guard payload["topic"] as? String == "sports" else { return try json(["changed": [], "removed": [], "now": 525]) }
        return try json(["changed": try encoded([fresh, moved]), "removed": ["p2"], "now": 520])
      default: XCTFail("Unexpected \(action)"); return Data("{}".utf8)
      }
    }
    await store.refresh(); await store.refreshTopics()
    let key = FeedKey(community: .campus, topic: "sports")
    await store.selectTopic("sports")?.value
    await store.syncFeedDelta()
    let entry = store.feedState(for: key)
    XCTAssertEqual(entry.ids, ["p0", "p3", "p4", "p50"], "p1 changed topic and p2 left; the new sports post joins")
    XCTAssertEqual(entry.since, 520)
    XCTAssertEqual(store.feedPostIDs, Set(all.map(\.id)), "A topic delta never removes posts from All")
    XCTAssertEqual(store.state.posts.first { $0.id == "p1" }?.topic, "academics", "The canonical copy carries the new topic")
    XCTAssertEqual(requests.filter { $0.action == "feed.delta" }.first?.payload["known_ids"] as? [String], ["p0", "p1", "p2", "p3", "p4"])
    // Returning to All asks All for its own delta, without a topic.
    await store.selectTopic(nil)?.value
    XCTAssertNil(requests.last?.payload["topic"]); XCTAssertEqual(requests.last?.action, "feed.delta")
  }

  func testAllDeltaRemovalsLeaveTopicFeedsToo() async throws {
    let all = (0..<4).map { post($0, topic: "sports", synced: 100) }
    let store = try networkStore { [self] _, action, payload, _ in
      switch action {
      case "snapshot": return try snapshot(all)
      case "topics.list": return try json(["topics": topicRows()])
      case "feed.page": return try json(["posts": try encoded(all), "next": NSNull()])
      case "feed.delta": XCTAssertNil(payload["topic"]); return try json(["changed": [], "removed": ["p3"], "now": 530])
      default: return Data("{}".utf8)
      }
    }
    await store.refresh(); await store.refreshTopics()
    let key = FeedKey(community: .campus, topic: "sports")
    await store.loadTopicFeed(key)
    await store.syncFeedDelta()
    XCTAssertEqual(store.feedState(for: key).ids, ["p0", "p1", "p2"], "A post gone from the community is gone from its topic")
  }

  func testCatalogDriftResetsTheSelectionToAllAndDropsThatTopicsCache() async throws {
    var slugs = ["academics", "sports", "memes"]
    let all = (0..<3).map { post($0, topic: "sports", synced: 100) }
    let store = try networkStore { [self] _, action, _, _ in
      switch action {
      case "snapshot": return try snapshot(all)
      case "topics.list": return try json(["topics": topicRows(slugs)])
      case "feed.page": return try json(["posts": try encoded(all), "next": NSNull()])
      default: return Data("{}".utf8)
      }
    }
    await store.refresh(); await store.refreshTopics()
    XCTAssertEqual(store.topics.map(\.slug), ["academics", "sports", "memes"])
    await store.selectTopic("sports")?.value
    await store.loadTopicFeed(FeedKey(community: .campus, topic: "memes"))
    XCTAssertNotNil(store.topicFeeds[FeedKey(community: .campus, topic: "sports")])
    slugs = ["academics", "memes"]
    await store.refreshTopics()
    XCTAssertNil(store.feedTopic, "A selected topic the catalog no longer lists resets to All")
    XCTAssertNil(store.topicFeeds[FeedKey(community: .campus, topic: "sports")], "Its cached feed is dropped")
    XCTAssertNotNil(store.topicFeeds[FeedKey(community: .campus, topic: "memes")])
    XCTAssertNil(store.selectTopic("sports"), "Inactive topics cannot be selected")
    // Every topic switched off: nothing to pick, so topics turn off and no topic is required.
    slugs = []
    await store.refreshTopics()
    XCTAssertFalse(store.topicsAvailable); XCTAssertTrue(store.topicFeeds.isEmpty); XCTAssertNil(store.state.topicCatalog)
    XCTAssertTrue(TopicCatalog.canPublish(topic: nil, topicsAvailable: store.topicsAvailable, catalog: store.topics))
  }

  func testAnInvalidTopicAnswerRefreshesTheCatalog() async throws {
    var slugs = ["academics", "sports"]
    var listed = 0
    let store = try networkStore { [self] _, action, _, _ in
      switch action {
      case "snapshot": return try snapshot([])
      case "topics.list": listed += 1; return try json(["topics": topicRows(slugs)])
      case "feed.page": throw SocialServiceError(error: "Choose an available topic.", code: "invalid")
      default: return Data("{}".utf8)
      }
    }
    await store.refresh(); await store.refreshTopics()
    slugs = ["academics"]
    await store.selectTopic("sports")?.value
    XCTAssertEqual(listed, 2); XCTAssertNil(store.feedTopic)
  }

  func testNewPostSendsItsTopicAndJoinsThatTopicFeed() async throws {
    var created: [String: Any]?
    var page = [post(0, topic: "sports", synced: 100)]
    let store = try networkStore { [self] _, action, payload, _ in
      switch action {
      case "snapshot": return try snapshot(page)
      case "topics.list": return try json(["topics": topicRows()])
      case "feed.page": return try json(["posts": try encoded([post(0, topic: "sports")]), "next": NSNull()])
      case "post.create":
        created = payload
        var mine = post(-5, topic: "sports", synced: 700); mine.id = "mine"
        page.insert(mine, at: 0)
        return try snapshot(page, resourceID: "mine")
      default: return Data("{}".utf8)
      }
    }
    await store.refresh(); await store.refreshTopics()
    await store.selectTopic("sports")?.value
    let posted = await store.createPost(text: "Game day", anonymous: true, community: .campus, acceptsDM: true, topic: "sports")
    XCTAssertTrue(posted)
    XCTAssertEqual(created?["topic"] as? String, "sports")
    XCTAssertTrue(store.feedState(for: FeedKey(community: .campus, topic: "sports")).ids.contains("mine"))
  }

  func testSwitchingCommunityKeepsTheTopicAndLoadsTheNewKey() async throws {
    var pages: [[String: Any]] = []
    let store = try networkStore { [self] _, action, payload, _ in
      switch action {
      case "snapshot": return try snapshot([])
      case "topics.list": return try json(["topics": topicRows()])
      case "feed.page":
        pages.append(payload)
        let community = Community(rawValue: payload["community"] as? String ?? "") ?? .campus
        return try json(["posts": try encoded([post(pages.count, topic: "sports", community: community)]), "next": NSNull()])
      default: return Data("{}".utf8)
      }
    }
    await store.refresh(); await store.refreshTopics()
    await store.selectTopic("sports")?.value
    await store.selectCommunity(.freshmen)
    for _ in 0..<50 where store.feedState(for: FeedKey(community: .freshmen, topic: "sports")).loaded == false { try await Task.sleep(for: .milliseconds(20)) }
    XCTAssertEqual(store.feedTopic, "sports")
    XCTAssertTrue(store.feedState(for: FeedKey(community: .freshmen, topic: "sports")).loaded)
    XCTAssertEqual(pages.last?["community"] as? String, "Freshmen"); XCTAssertEqual(pages.last?["topic"] as? String, "sports")
  }

  /// A first topic page that fails ends the loading state with an error (the feed then shows its
  /// Retry card instead of an endless loading wordmark), and Retry loads it.
  func testAFailedFirstTopicPageShowsItsErrorInsteadOfLoading() async throws {
    var fail = true
    let store = try networkStore { [self] _, action, _, _ in
      switch action {
      case "snapshot": return try snapshot([])
      case "topics.list": return try json(["topics": topicRows()])
      case "feed.page":
        if fail { throw URLError(.notConnectedToInternet) }
        return try json(["posts": try encoded([post(1, topic: "sports")]), "next": NSNull()])
      default: return Data("{}".utf8)
      }
    }
    await store.refresh(); await store.refreshTopics()
    let key = FeedKey(community: .campus, topic: "sports")
    XCTAssertTrue(store.feedState(for: key).showsLoading, "Not asked yet: loading")
    await store.selectTopic("sports")?.value
    var entry = store.feedState(for: key)
    XCTAssertFalse(entry.loaded); XCTAssertFalse(entry.loading); XCTAssertNotNil(entry.error)
    XCTAssertFalse(entry.showsLoading, "A failed first page shows its error, not the loading state")
    fail = false
    let loaded = await store.loadTopicFeed(key, reset: true)
    entry = store.feedState(for: key)
    XCTAssertTrue(loaded); XCTAssertTrue(entry.loaded); XCTAssertNil(entry.error); XCTAssertFalse(entry.showsLoading)
  }

  /// A truncated topic delta keeps the key's clock until the first page has been read again, so a
  /// failed reload loses nothing: the next delta asks from the same point.
  func testATruncatedTopicDeltaKeepsItsClockUntilTheReloadSucceeds() async throws {
    var failPage = false
    var deltaSince: [Double] = []
    let store = try networkStore { [self] _, action, payload, _ in
      switch action {
      case "snapshot": return try snapshot([])
      case "topics.list": return try json(["topics": topicRows()])
      case "feed.page":
        if failPage { throw URLError(.timedOut) }
        return try json(["posts": try encoded([post(1, topic: "sports", synced: 100)]), "next": NSNull()])
      case "feed.delta":
        deltaSince.append(payload["since"] as? Double ?? -1)
        return try json(["changed": [], "removed": [], "now": 900, "truncated": true])
      default: return Data("{}".utf8)
      }
    }
    await store.refresh(); await store.refreshTopics()
    let key = FeedKey(community: .campus, topic: "sports")
    await store.selectTopic("sports")?.value
    XCTAssertEqual(store.feedState(for: key).since, 500)
    failPage = true
    await store.syncFeedDelta()
    XCTAssertEqual(store.feedState(for: key).since, 500, "A failed reload keeps the clock")
    XCTAssertNotNil(store.feedState(for: key).error)
    failPage = false
    await store.syncFeedDelta()
    XCTAssertEqual(deltaSince, [500, 500], "The next delta asks from the same point")
    XCTAssertEqual(store.feedState(for: key).since, 900, "The clock moves once the first page was read again")
    XCTAssertNil(store.feedState(for: key).error)
  }

  /// Topic deltas carry only held or newer posts, so an older post retagged into a topic reaches
  /// that loaded tab through All's delta; it leaves the community's other topic tabs.
  func testAnOlderPostRetaggedIntoATopicJoinsItsLoadedTabFromAllDeltas() async throws {
    let all = [post(1, topic: "housing", synced: 100), post(2, topic: "sports", synced: 100), post(3, synced: 100)]
    var retagged = post(1, topic: "sports", synced: 600)
    retagged.text = "Retagged"
    var deleted = post(2, topic: nil, synced: 600)
    deleted.deleted = true
    let store = try networkStore { [self] _, action, payload, _ in
      switch action {
      case "snapshot": return try snapshot(all)
      case "topics.list": return try json(["topics": topicRows()])
      case "feed.page":
        let topic = payload["topic"] as? String
        return try json(["posts": try encoded(all.filter { $0.topic == topic }), "next": NSNull()])
      case "feed.delta":
        XCTAssertNil(payload["topic"])
        return try json(["changed": try encoded([retagged, deleted]), "removed": [], "now": 610])
      default: return Data("{}".utf8)
      }
    }
    await store.refresh(); await store.refreshTopics()
    let sports = FeedKey(community: .campus, topic: "sports"), housing = FeedKey(community: .campus, topic: "housing")
    await store.loadTopicFeed(sports); await store.loadTopicFeed(housing)
    XCTAssertEqual(store.feedState(for: sports).ids, ["p2"]); XCTAssertEqual(store.feedState(for: housing).ids, ["p1"])
    await store.syncFeedDelta()
    XCTAssertEqual(store.feedState(for: sports).ids, ["p1"], "The retagged post joins Sports; the deleted one leaves it")
    XCTAssertEqual(store.feedState(for: housing).ids, [], "It leaves its old topic")
    XCTAssertNil(store.topicFeeds[FeedKey(community: .campus, topic: "memes")], "A tab that never loaded is not created")
  }

  /// "Choose an available topic." on post.create (the topic was disabled after the catalog was read)
  /// refreshes the catalog, so the composer's chip goes away and a new pick is required.
  func testARefusedTopicOnANewPostRefreshesTheCatalog() async throws {
    var slugs = ["academics", "sports"]
    var listed = 0
    let store = try networkStore { [self] _, action, _, _ in
      switch action {
      case "snapshot": return try snapshot([])
      case "topics.list": listed += 1; return try json(["topics": topicRows(slugs)])
      case "post.create": throw SocialServiceError(error: "Choose an available topic.", code: "invalid")
      default: return Data("{}".utf8)
      }
    }
    await store.refresh(); await store.refreshTopics()
    XCTAssertEqual(listed, 1)
    slugs = ["academics"]
    let posted = await store.createPost(text: "Game day", anonymous: true, community: .campus, acceptsDM: true, topic: "sports")
    XCTAssertFalse(posted)
    XCTAssertEqual(store.notice, "Choose an available topic.")
    XCTAssertEqual(listed, 2, "The refusal refreshed the catalog")
    XCTAssertEqual(store.topics.map(\.slug), ["academics"])
    XCTAssertFalse(TopicCatalog.canPublish(topic: nil, topicsAvailable: store.topicsAvailable, catalog: store.topics))
  }

  /// A community switch while the first topics.list is in flight drops that answer (its counts are
  /// for the old community) but asks again soon instead of waiting out the refresh interval.
  func testSwitchingCommunityDuringTheFirstCatalogReadRetriesSoon() async throws {
    var store: AppStore!
    var listed = 0
    store = try networkStore { [self] _, action, _, _ in
      switch action {
      case "snapshot": return try snapshot([])
      case "topics.list":
        listed += 1
        if listed == 1 {
          // The member switches community while this read is in flight (selectCommunity sets the
          // selection before its first suspension point).
          Task { await store.selectCommunity(.freshmen) }
          for _ in 0..<100 where store.feedCommunity != .freshmen { await Task.yield() }
        }
        return try json(["topics": topicRows()])
      default: return Data("{}".utf8)
      }
    }
    await store.refresh()
    await store.refreshTopics()
    XCTAssertFalse(store.topicsAvailable, "The old community's answer is not applied")
    XCTAssertLessThanOrEqual(store.topicsRetryAt, .now, "The catalog is asked for again on the next pass")
    await store.refreshTopics()
    XCTAssertTrue(store.topicsAvailable)
  }

  // MARK: Fixture mode

  func testFixtureModeHasTopicsAndSeedsPostsAcrossThem() throws {
    XCTAssertTrue(FeatureAvailability.topicsEnabled, "Topic feeds ship switched on; the server decides at run time")
    let store = AppStore(storageURL: try file(), arguments: [])
    XCTAssertTrue(store.topicsAvailable)
    XCTAssertEqual(store.topics.count, 8)
    let folded = TopicCatalog.fold(store.topics, selected: nil)
    XCTAssertEqual(folded.more.map(\.slug), ["confessions", "memes"], "Fixture counts fold two quiet topics into More")
    let seeded = Set(store.state.posts.compactMap(\.topic))
    XCTAssertTrue(seeded.isSuperset(of: ["academics", "aggie_life", "sports", "questions", "memes", "confessions", "housing"]))
    XCTAssertTrue(store.state.posts.contains { $0.topic == nil }, "Posts without a topic still show under All")
    XCTAssertNil(store.feedIDs(for: FeedKey(community: .campus, topic: "sports")), "Fixture topic feeds filter the held posts")
    XCTAssertTrue(store.feedState(for: FeedKey(community: .campus, topic: "sports")).loaded)
    let withoutTopics = AppStore(storageURL: try file(), arguments: [AppStore.noTopicsArgument])
    XCTAssertFalse(withoutTopics.topicsAvailable)
  }
}
