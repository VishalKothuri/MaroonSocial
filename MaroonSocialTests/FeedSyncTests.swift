import XCTest
import MaroonCore
@testable import MaroonSocial

/// Incremental sync: cursors, merges, eviction caps, old cache files and hash-gated saves.
@MainActor final class FeedSyncTests: XCTestCase {
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
  private func snapshot(_ posts: [Post], next: [String: Any]? = nil, serverNow: Double? = 500, conversations: [[String: Any]] = [],
    community: String? = nil, savedEvents: [String] = []) throws -> Data {
    var value: [String: Any] = ["username": "sync_tester", "nsfwEnabled": false, "posts": try encoded(posts), "courses": [], "activities": [],
      "conversations": conversations, "ownPostIDs": [], "ownCommentIDs": [], "ownMessageIDs": [], "conversationMeta": [],
      "attachments": [], "organizations": [], "savedEvents": savedEvents]
    if let community { value["feedCommunity"] = community }
    if let next { value["feedNext"] = next }
    if let serverNow { value["serverNow"] = serverNow }
    return try JSONSerialization.data(withJSONObject: ["snapshot": value])
  }
  private func file() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    directories.append(directory)
    return directory.appending(path: "social-cache.json")
  }
  private func networkStore(_ transport: @escaping SocialService.Transport) throws -> AppStore {
    let store = AppStore(storageURL: try file(), arguments: [], socialService: SocialService(credentials: credentials(), transport: transport))
    store.state.username = "sync_tester"; store.state.onboarded = true; store.connected = true
    return store
  }
  /// Whole-second dates survive every JSON round trip exactly.
  /// `synced` stands for the server's read time (`syncedAt`), which orders copies of a post.
  private func post(_ number: Int, text: String? = nil, synced: Double? = nil, community: Community = .campus) -> Post {
    var post = Post(id: "p\(number)", author: "Anonymous", community: community, text: text ?? "Post \(number)", created: Date(timeIntervalSince1970: 1_000_000 - Double(number)))
    post.syncedAt = synced.map { Date(timeIntervalSince1970: $0) }
    return post
  }
  private func reply(_ number: Int, parent: Int? = nil) -> Comment {
    var comment = Comment(author: "Aggie", text: "Reply \(number)")
    comment.id = "c\(number)"; comment.created = Date(timeIntervalSince1970: 2_000_000 + Double(number)); comment.parentID = parent.map { "c\($0)" }
    return comment
  }
  private func json(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
  private func message(_ sequence: Int, text: String? = nil) -> [String: Any] {
    ["id": "m\(sequence)", "author": "Them", "text": text ?? "Message \(sequence)", "created": 1_000 + sequence, "sequence": sequence]
  }

  func testCursorBookkeepingAcrossSnapshotPageAndDelta() async throws {
    var requests: [(action: String, payload: [String: Any])] = []
    let first = (0..<30).map { post($0, synced: 100) }
    var edited = post(5, text: "Edited after a vote", synced: 600); edited.score = 3
    let store = try networkStore { [self] _, action, payload, _ in
      requests.append((action, payload))
      switch action {
      case "snapshot":
        let page = requests.filter { $0.action == "snapshot" }.count == 1 ? first : first.filter { $0.id != "p7" }
        return try snapshot(page, next: ["before_created": 999_971, "before_id": "p29"])
      case "feed.page":
        return try JSONSerialization.data(withJSONObject: ["posts": try encoded((30..<40).map { post($0) }), "next": NSNull()])
      case "feed.delta":
        return try JSONSerialization.data(withJSONObject: ["changed": try encoded([edited]), "removed": ["p7"], "now": 510, "truncated": false])
      default: XCTFail("Unexpected \(action)"); return Data("{}".utf8)
      }
    }
    await store.refresh()
    XCTAssertEqual(store.state.feedCursor, SocialPageCursor(beforeCreated: 999_971, beforeID: "p29"))
    XCTAssertEqual(store.state.feedSince, 500)
    XCTAssertEqual(store.feedPostIDs?.count, 30)
    XCTAssertTrue(store.feedHasMore)

    await store.loadMoreFeed()
    let page = try XCTUnwrap(requests.last)
    XCTAssertEqual(page.action, "feed.page")
    XCTAssertEqual(page.payload["before_created"] as? Double, 999_971)
    XCTAssertEqual(page.payload["before_id"] as? String, "p29")
    XCTAssertEqual(page.payload["community"] as? String, Community.campus.rawValue)
    XCTAssertEqual(store.feedPostIDs?.count, 40)
    XCTAssertNil(store.state.feedCursor, "The last page ends the feed")
    XCTAssertFalse(store.feedHasMore)

    await store.syncFeedDelta()
    let delta = try XCTUnwrap(requests.last)
    XCTAssertEqual(delta.action, "feed.delta")
    XCTAssertEqual(delta.payload["since"] as? Double, 500)
    let known = try XCTUnwrap(delta.payload["known_ids"] as? [String])
    XCTAssertEqual(known.count, 40); XCTAssertEqual(known.first, "p0"); XCTAssertEqual(known.last, "p39")
    XCTAssertEqual(store.state.feedSince, 510)
    XCTAssertFalse(store.state.posts.contains { $0.id == "p7" }, "A removed id leaves the cache")
    XCTAssertFalse(store.feedPostIDs?.contains("p7") ?? true)
    XCTAssertEqual(store.state.posts.first { $0.id == "p5" }?.text, "Edited after a vote")

    // Reconciliation keeps older loaded pages and the delta clock.
    await store.refresh()
    XCTAssertEqual(store.feedPostIDs?.count, 39)
    XCTAssertTrue(store.feedPostIDs?.contains("p35") == true)
    XCTAssertEqual(store.state.feedSince, 510, "A snapshot must not jump the delta clock past older pages")
    XCTAssertEqual(store.state.posts.first { $0.id == "p5" }?.text, "Edited after a vote", "An older copy cannot replace a newer change")
  }

  func testSnapshotThatNoLongerOverlapsRebuildsFeedAndOldServerFallsBack() async throws {
    var serverNow: Double? = 500
    var page = (0..<3).map { post($0) }
    let store = try networkStore { [self] _, action, _, _ in
      if action == "feed.delta" { throw SocialServiceError(error: "Unknown social action.", code: "invalid") }
      return try snapshot(page, serverNow: serverNow)
    }
    await store.refresh()
    XCTAssertEqual(store.feedPostIDs, ["p0", "p1", "p2"])
    page = (10..<12).map { post($0) }
    await store.refresh()
    XCTAssertEqual(store.feedPostIDs, ["p10", "p11"], "A page with no overlap starts a fresh feed")
    await store.syncFeedDelta()
    XCTAssertNil(store.state.feedSince, "A server without deltas falls back to snapshots")
    XCTAssertFalse(store.incrementalSync)
    serverNow = nil; page = [post(10)]
    await store.refresh()
    XCTAssertEqual(store.feedPostIDs, ["p10"])
    XCTAssertNil(store.state.feedSince)
  }

  func testMergeKeepsNewestReadAndOlderLoadedReplies() {
    let held = post(1, text: "Newest", synced: 20)
    XCTAssertEqual(AppStore.mergePosts([held], with: [post(1, text: "Stale", synced: 10)]).first?.text, "Newest")
    XCTAssertEqual(AppStore.mergePosts([held], with: [post(1, text: "Changed", synced: 30)]).first?.text, "Changed")
    XCTAssertEqual(AppStore.mergePosts([held], with: [post(2)]).map(\.id), ["p1", "p2"])

    func reply(_ id: String, _ created: Double, _ text: String = "Reply") -> Comment {
      var comment = Comment(author: "Aggie", text: text); comment.id = id; comment.created = Date(timeIntervalSince1970: created); return comment
    }
    var withHistory = post(3, synced: 1)
    withHistory.comments = [reply("c1", 1), reply("c2", 2), reply("c3", 3)]
    var window = post(3, synced: 2)
    window.comments = [reply("c3", 3, "Edited"), reply("c4", 4)]; window.commentCount = 4
    let merged = AppStore.mergePosts([withHistory], with: [window]).first
    XCTAssertEqual(merged?.comments.map(\.id), ["c1", "c2", "c3", "c4"])
    XCTAssertEqual(merged?.comments[2].text, "Edited")
    window.commentCount = 2
    XCTAssertEqual(AppStore.mergePosts([withHistory], with: [window]).first?.comments.map(\.id), ["c3", "c4"], "A complete window is authoritative")
  }

  func testMessageMergeAfterSequenceHasNoDuplicates() {
    func make(_ sequence: Int, _ text: String = "Hi") -> Message {
      var value = Message(author: "Them", text: text); value.id = "m\(sequence)"; value.sequence = sequence; return value
    }
    let merged = AppStore.mergeMessages([make(1), make(2), make(3)], with: [make(3, "Edited"), make(5), make(4)])
    XCTAssertEqual(merged.map(\.sequence), [1, 2, 3, 4, 5])
    XCTAssertEqual(merged[2].text, "Edited")
    XCTAssertEqual(AppStore.mergeMessages(merged, with: merged), merged)
  }

  func testOpenRoomFetchesOnlyNewerMessagesAndUpdatesMetadata() async throws {
    var afterSequences: [Int?] = []
    let conversation: [String: Any] = ["id": "room-1", "title": "Study group", "subtitle": "", "request": false, "anonymous": false,
      "messages": [message(1), message(2), message(3)]]
    let store = try networkStore { [self] _, action, payload, _ in
      if action == "snapshot" { return try snapshot([], conversations: [conversation]) }
      XCTAssertEqual(action, "room.messages")
      afterSequences.append(payload["after_seq"] as? Int)
      let meta: [String: Any] = ["id": "room-1", "kind": "dm", "status": "active", "role": "member", "canSend": true, "unread": 1,
        "lastRead": 3, "pendingOutgoing": false, "typing": ["Them"]]
      return try JSONSerialization.data(withJSONObject: ["room_id": "room-1", "messages": [message(3, text: "Edited"), message(4)], "more": false, "meta": meta])
    }
    await store.refresh()
    XCTAssertEqual(store.state.roomCursors?["room-1"], 3)
    await store.syncRoom("room-1")
    XCTAssertEqual(afterSequences, [3])
    let messages = try XCTUnwrap(store.state.conversations.first?.messages)
    XCTAssertEqual(messages.map(\.sequence), [1, 2, 3, 4])
    XCTAssertEqual(messages[2].text, "Edited")
    XCTAssertEqual(store.state.roomCursors?["room-1"], 4)
    XCTAssertEqual(store.conversationMeta["room-1"]?.typing, ["Them"])
  }

  func testEvictionCapsPostsMessagesAndIdleRooms() {
    var state = LocalState()
    var posts = (0..<150).map { post($0) }
    posts[140].saved = true
    state.posts = posts
    state.feedPostIDs = posts.map(\.id)
    state.feedSince = 500
    func messages(_ count: Int) -> [Message] {
      (1...count).map { sequence in var value = Message(author: "Them", text: "\(sequence)"); value.sequence = sequence; return value }
    }
    let now = Date(timeIntervalSince1970: 10_000_000)
    state.conversations = [Conversation(id: "busy", title: "Busy", messages: messages(80)), Conversation(id: "idle", title: "Idle", messages: messages(5))]
    state.roomOpened = ["busy": now, "idle": now.addingTimeInterval(-31 * 86_400), "gone": now]
    state.roomCursors = ["busy": 80, "idle": 5, "gone": 9]
    let result = AppStore.evicted(state, ownPostIDs: ["p145"], now: now)
    XCTAssertEqual(result.feedPostIDs?.count, AppStore.persistedFeedPosts)
    XCTAssertEqual(Set(result.posts.map(\.id)), Set((0..<100).map { "p\($0)" } + ["p140", "p145"]), "Newest 100 feed posts plus saved and own posts")
    XCTAssertEqual(result.feedCursor?.beforeID, "p99")
    XCTAssertEqual(result.feedCursor?.beforeCreated ?? 0, 1_000_000 - 99 + 0.000_001, accuracy: 0.000_000_5)
    XCTAssertEqual(result.conversations.first { $0.id == "busy" }?.messages.map(\.sequence), Array(31...80))
    XCTAssertEqual(result.conversations.first { $0.id == "idle" }?.messages, [], "A room not opened for 30 days drops its messages")
    XCTAssertEqual(result.conversations.count, 2, "The conversation row stays")
    XCTAssertEqual(result.roomCursors, ["busy": 80])
    XCTAssertNil(result.roomOpened?["gone"])
  }

  func testEvictionAppliesWhenNetworkStoreSaves() async throws {
    let store = try networkStore { [self] _, _, _, _ in try snapshot((0..<120).map { post($0) }) }
    await store.refresh()
    let data = try Data(contentsOf: try XCTUnwrap(directories.last).appending(path: "social-cache.json"))
    let saved = try JSONDecoder().decode(LocalState.self, from: data)
    XCTAssertEqual(saved.posts.count, 100)
    XCTAssertEqual(store.state.posts.count, 120, "Memory keeps everything loaded")
  }

  func testStateFileWithoutIncrementalKeysStillDecodes() throws {
    let old = #"{"username":"returning","onboarded":true,"adult":true,"posts":[],"courses":[],"conversations":[],"activities":[],"hiddenPosts":[],"savedEvents":[],"reports":[]}"#
    let state = try JSONDecoder().decode(LocalState.self, from: Data(old.utf8))
    XCTAssertEqual(state.username, "returning")
    XCTAssertNil(state.feedSince); XCTAssertNil(state.feedCursor); XCTAssertNil(state.roomCursors); XCTAssertNil(state.roomOpened)
    let url = try file()
    try Data(old.utf8).write(to: url)
    let store = AppStore(storageURL: url, arguments: [])
    XCTAssertEqual(store.state.username, "returning")
    XCTAssertNil(store.feedPostIDs)
  }

  func testSaveSkipsUnchangedBytes() throws {
    let url = try file()
    let store = AppStore(storageURL: url, arguments: [])
    store.enter(username: "hash_tester")
    let writes = store.diskWrites
    let modified = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    XCTAssertTrue(store.save()); XCTAssertTrue(store.save())
    XCTAssertEqual(store.diskWrites, writes, "Identical state is not rewritten")
    XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date, modified)
    store.state.reports.append("p1: spam")
    XCTAssertTrue(store.save())
    XCTAssertEqual(store.diskWrites, writes + 1)
  }

  func testFixtureFeedPagesFromState() async {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = AppStore(storageURL: url, arguments: ["--uitesting-feed-pages"])
    XCTAssertEqual(store.feedPostIDs?.count, 30)
    XCTAssertTrue(store.feedHasMore)
    await store.loadMoreFeed()
    XCTAssertEqual(store.feedPostIDs?.count, store.state.posts.filter { $0.community == .campus }.count)
    XCTAssertFalse(store.feedHasMore)
  }

  // MARK: Review regressions

  func testIdenticalSnapshotsDoNotRewriteTheCache() async throws {
    // Sets used to encode in per-instance order and read times change on every snapshot;
    // neither may turn an unchanged snapshot into a disk write.
    var read = 100.0
    let store = try networkStore { [self] _, _, _, _ in
      read += 1
      return try snapshot((0..<5).map { post($0, synced: read) }, savedEvents: ["sports-1", "sports-2", "event-3", "event-4", "event-5"])
    }
    await store.refresh()
    let before = store.diskWrites
    for _ in 0..<20 { await store.refresh() }
    XCTAssertEqual(store.diskWrites, before, "Byte-identical content must not rewrite the cache")
    let saved = try String(contentsOf: try XCTUnwrap(directories.last).appending(path: "social-cache.json"), encoding: .utf8)
    XCTAssertFalse(saved.contains("syncedAt"), "Read times are not persisted")
    XCTAssertTrue(saved.contains(#"["event-3","event-4","event-5","sports-1","sports-2"]"#), "Sets encode sorted")
  }

  func testReplyWindowThatSkippedRepliesDropsDisconnectedHistory() async throws {
    var thread = post(1, synced: 100)
    thread.comments = (11...60).map { reply($0) }; thread.commentCount = 60
    var later = post(1, synced: 200)
    later.comments = (81...130).map { reply($0) }; later.commentCount = 130
    var snapshots = 0
    let all = (1...130).map { reply($0) }
    let store = try networkStore { [self] _, action, payload, _ in
      switch action {
      case "snapshot": snapshots += 1; return try snapshot([snapshots == 1 ? thread : later])
      case "comments.page":
        let before = try XCTUnwrap(payload["before_created"] as? Double)
        let older = all.filter { $0.created.timeIntervalSince1970 < before }
        let page = Array(older.suffix(50))
        let next: Any = older.count > page.count ? ["before_created": page[0].created.timeIntervalSince1970, "before_id": page[0].id] : NSNull()
        return try json(["post_id": "p1", "comments": try encoded(page), "next": next, "commentCount": 130])
      default: XCTFail(action); return Data("{}".utf8)
      }
    }
    await store.refresh()
    await store.refresh()
    XCTAssertEqual(store.state.posts.first?.comments.map(\.id), (81...130).map { "c\($0)" }, "Held replies that do not reach the window are dropped")
    XCTAssertTrue(store.hasEarlierReplies(try XCTUnwrap(store.state.posts.first)))
    await store.loadEarlierComments("p1")
    await store.loadEarlierComments("p1")
    let held = try XCTUnwrap(store.state.posts.first)
    XCTAssertEqual(held.comments.map(\.id), (1...130).map { "c\($0)" }, "Pages back from the window without a gap")
    XCTAssertEqual(held.commentCount, 130, "The server's count is kept")
    XCTAssertFalse(store.hasEarlierReplies(held), "The thread's first reply is held")
  }

  func testOpeningThreadLoadsParentsOlderThanTheWindow() async throws {
    var thread = post(1, synced: 100)
    thread.comments = (51...100).map { reply($0, parent: $0 == 100 ? 3 : nil) }; thread.commentCount = 100
    let all = (1...100).map { reply($0, parent: $0 == 100 ? 3 : nil) }
    var pages = 0
    let store = try networkStore { [self] _, action, payload, _ in
      if action == "snapshot" { return try snapshot([thread]) }
      pages += 1
      let before = try XCTUnwrap(payload["before_created"] as? Double)
      let older = all.filter { $0.created.timeIntervalSince1970 < before }
      let page = Array(older.suffix(25))
      return try json(["post_id": "p1", "comments": try encoded(page), "next": ["before_created": page[0].created.timeIntervalSince1970, "before_id": page[0].id], "commentCount": 100])
    }
    await store.refresh()
    await store.loadMissingParents("p1")
    XCTAssertEqual(pages, 2, "Pages back until the parent of the newest reply is held")
    XCTAssertTrue(store.state.posts.first?.comments.contains { $0.id == "c3" } == true)
  }

  func testCommunitySwitchDuringMutationLoadsTheNewFeed() async throws {
    var requests: [(action: String, payload: [String: Any])] = []
    var release = false, voteEntered = false
    let campus = (0..<3).map { post($0) }
    let store = try networkStore { [self] _, action, payload, _ in
      requests.append((action, payload))
      let community = payload["feed_community"] as? String ?? Community.campus.rawValue
      switch action {
      case "snapshot": return try snapshot(community == Community.campus.rawValue ? campus : [post(50, community: .freshmen)], community: community)
      case "post.vote":
        voteEntered = true
        while !release { try await Task.sleep(for: .milliseconds(5)) }
        return try snapshot(campus, community: community)
      case "feed.delta":
        let requested = payload["community"] as? String
        let known = payload["known_ids"] as? [String] ?? []
        return try json(["changed": [], "removed": known.filter { id in !campus.contains { $0.id == id && $0.community.rawValue == requested } }, "now": 510, "truncated": false])
      default: XCTFail(action); return Data("{}".utf8)
      }
    }
    await store.refresh()
    let vote = Task { await store.mutate("post.vote", ["post_id": "p0", "value": 1]) }
    while !voteEntered { await Task.yield() }
    let select = Task { await store.selectCommunity(.freshmen) }
    try await Task.sleep(for: .milliseconds(400))
    release = true
    _ = await vote.value; await select.value
    XCTAssertFalse(requests.contains { $0.action == "feed.delta" && ($0.payload["community"] as? String) == Community.freshmen.rawValue && !(($0.payload["known_ids"] as? [String]) ?? []).filter { $0.hasPrefix("p") && $0 != "p50" }.isEmpty },
      "No delta asks for Freshmen with the Texas A&M feed's ids")
    XCTAssertEqual(requests.filter { $0.action == "snapshot" && ($0.payload["feed_community"] as? String) == Community.freshmen.rawValue }.count, 1)
    XCTAssertEqual(store.feedPostIDs, ["p50"])
    XCTAssertFalse(store.loadingCommunity)
  }

  func testUpgradedServerStartsAPagedFeed() async throws {
    var upgraded = false
    let store = try networkStore { [self] _, _, _, _ in
      upgraded ? try snapshot((0..<30).map { post($0) }, next: ["before_created": 999_971, "before_id": "p29"], serverNow: 500)
        : try snapshot((0..<150).map { post($0) }, serverNow: nil)
    }
    await store.refresh()
    XCTAssertFalse(store.incrementalSync)
    upgraded = true
    await store.refresh()
    XCTAssertTrue(store.incrementalSync)
    XCTAssertTrue(store.feedHasMore, "The first clock adopts the server's cursor")
    XCTAssertEqual(store.feedPostIDs?.count, 30)
  }

  func testTruncatedDeltaRefetchesHeldPagesInsteadOfCollapsing() async throws {
    var requests: [(action: String, payload: [String: Any])] = []
    let store = try networkStore { [self] _, action, payload, _ in
      requests.append((action, payload))
      switch action {
      case "snapshot": return try snapshot((0..<30).map { post($0, synced: 100) }, next: ["before_created": 999_971, "before_id": "p29"])
      case "feed.page" where payload["before_id"] != nil:
        return try json(["posts": try encoded((30..<60).map { post($0, synced: 110) }), "next": ["before_created": 999_941, "before_id": "p59"]])
      case "feed.page": return try json(["posts": try encoded([post(-1, text: "Brand new", synced: 130)] + (0..<29).map { post($0, synced: 130) }), "next": NSNull()])
      case "feed.delta": return try json(["changed": [], "removed": ["p40"], "now": 520, "truncated": true])
      case "feed.posts":
        let ids = try XCTUnwrap(payload["ids"] as? [String])
        let posts = ids.filter { $0 != "p40" && $0 != "p41" }.compactMap { id in Int(id.dropFirst()).map { post($0, text: "Fresh \($0)", synced: 125) } }
        return try json(["posts": try encoded(posts), "removed": ids.filter { $0 == "p41" }])
      default: XCTFail(action); return Data("{}".utf8)
      }
    }
    await store.refresh()
    await store.loadMoreFeed()
    XCTAssertEqual(store.feedPostIDs?.count, 60)
    await store.syncFeedDelta()
    let refetches = requests.filter { $0.action == "feed.posts" }
    XCTAssertEqual(refetches.map { ($0.payload["ids"] as? [String])?.count }, [50, 9], "Held ids are read again 50 at a time")
    XCTAssertEqual(store.feedPostIDs?.count, 59, "Loaded pages stay; the removed ids leave and the new post joins")
    XCTAssertTrue(store.feedPostIDs?.contains("p-1") == true)
    XCTAssertFalse(store.feedPostIDs?.contains("p40") == true || store.feedPostIDs?.contains("p41") == true)
    XCTAssertEqual(store.state.posts.first { $0.id == "p55" }?.text, "Fresh 55")
    XCTAssertEqual(store.state.feedSince, 520)
    XCTAssertNotNil(store.state.feedCursor, "The older cursor is kept")
  }

  func testResyncRefetchesHeldPostsAndKeepsTheClockOnFailure() async throws {
    var failRefetch = true
    var requests: [String] = []
    let store = try networkStore { [self] _, action, payload, _ in
      requests.append(action)
      switch action {
      case "snapshot": return try snapshot((0..<3).map { post($0, synced: 100) })
      case "feed.delta": return try json(["changed": try encoded([post(9, text: "New", synced: 140)]), "removed": [], "now": 530, "truncated": false, "resync": true])
      case "feed.posts":
        if failRefetch { throw URLError(.timedOut) }
        let ids = try XCTUnwrap(payload["ids"] as? [String])
        return try json(["posts": try encoded([post(0, text: "Replies hidden for me", synced: 150)]), "removed": ids.filter { $0 == "p2" }])
      default: XCTFail(action); return Data("{}".utf8)
      }
    }
    await store.refresh()
    await store.syncFeedDelta()
    XCTAssertEqual(store.state.feedSince, 500, "A failed refetch keeps the clock so the next delta asks again")
    XCTAssertTrue(store.feedPostIDs?.contains("p9") == true, "The delta's own changes still apply")
    failRefetch = false
    await store.syncFeedDelta()
    XCTAssertEqual(store.state.feedSince, 530)
    XCTAssertEqual(store.state.posts.first { $0.id == "p0" }?.text, "Replies hidden for me")
    XCTAssertFalse(store.feedPostIDs?.contains("p2") == true)
    XCTAssertFalse(requests.contains("feed.page"), "A resync without truncation needs no first page")
  }

  func testHotFillsItsWindowAndStops() async throws {
    var pages = 0
    let store = try networkStore { [self] _, action, payload, _ in
      if action == "snapshot" { return try snapshot((0..<30).map { post($0) }, next: ["before_created": 999_971, "before_id": "p29"]) }
      pages += 1
      let start = 30 * pages
      return try json(["posts": try encoded((start..<start + 30).map { post($0) }), "next": ["before_created": 1_000_000 - Double(start + 29), "before_id": "p\(start + 29)"]])
    }
    await store.refresh()
    await store.fillFeedForHot()
    XCTAssertEqual(store.feedPostIDs?.count, AppStore.hotWindow)
    XCTAssertEqual(pages, 4)
    XCTAssertTrue(store.feedHasMore, "New can still page past the Hot window")
  }

  func testOpenRoomMergesChangesAndKeepsHistoryAcrossSnapshots() async throws {
    var calls: [[String: Any]] = []
    let window = (31...80).map { message($0) }
    let store = try networkStore { [self] _, action, payload, _ in
      switch action {
      case "snapshot":
        let conversation: [String: Any] = ["id": "room-1", "title": "Study group", "subtitle": "", "request": false, "anonymous": false, "messages": window]
        return try snapshot([], conversations: [conversation])
      case "room.messages":
        calls.append(payload)
        if let before = payload["before_seq"] as? Int {
          return try json(["room_id": "room-1", "messages": (max(1, before - 50)..<before).map { message($0) }, "more": before - 50 > 1])
        }
        var deleted = message(40, text: "[Message deleted]"); deleted["deleted"] = true
        return try json(["room_id": "room-1", "messages": [message(81)], "more": false, "now": 540,
          "changed": [deleted, message(5, text: "Not held, so not merged")]])
      default: XCTFail(action); return Data("{}".utf8)
      }
    }
    await store.refresh()
    let follow = Task { await store.followRoom("room-1") }
    while !calls.contains(where: { $0["after_seq"] != nil }) { try await Task.sleep(for: .milliseconds(5)) }
    XCTAssertEqual(calls.last?["after_seq"] as? Int, 80)
    XCTAssertEqual(calls.last?["changed_since"] as? Double, 500, "Change polling starts at the snapshot clock")
    var messages = try XCTUnwrap(store.state.conversations.first?.messages)
    XCTAssertEqual(messages.first { $0.sequence == 40 }?.text, "[Message deleted]", "A deletion reaches the open chat without a snapshot")
    XCTAssertNil(messages.first { $0.sequence == 5 }, "Changes only refresh held messages")
    XCTAssertEqual(messages.last?.sequence, 81)

    XCTAssertTrue(store.hasEarlierMessages("room-1"))
    await store.loadEarlierMessages("room-1")
    XCTAssertEqual(calls.last?["before_seq"] as? Int, 31)
    XCTAssertEqual(store.state.conversations.first?.messages.first?.sequence, 1)
    XCTAssertFalse(store.hasEarlierMessages("room-1"), "A short older page ends the history")

    await store.refresh()
    messages = try XCTUnwrap(store.state.conversations.first?.messages)
    XCTAssertEqual(messages.first?.sequence, 1, "A snapshot keeps the history an open chat paged in")
    XCTAssertEqual(messages.last?.sequence, 80, "Inside its window the snapshot is authoritative")
    follow.cancel(); await follow.value

    await store.refresh()
    XCTAssertEqual(store.state.conversations.first?.messages.first?.sequence, 31, "A closed room takes the newest window again")
  }

  func testSourcePostTagCanOpenPostsOlderThanTheFeed() async throws {
    // The tag opens LibraryPostDestination, which reads the post by id when it is not held.
    var reads: [String] = []
    let store = try networkStore { [self] _, action, payload, _ in
      reads.append(action)
      if action == "snapshot" { return try snapshot([post(0)]) }
      return try json(["posts": try encoded([post(77, text: "Older source post")]), "comments": [], "hasMore": false])
    }
    await store.refresh()
    let lease = store.openLibraryScope(SocialLibraryQuery(kind: .post, postID: "p77"))
    await store.loadLibraryPage(SocialLibraryQuery(kind: .post, postID: "p77"))
    XCTAssertEqual(store.state.posts.first { $0.id == "p77" }?.text, "Older source post")
    _ = lease
  }
}
