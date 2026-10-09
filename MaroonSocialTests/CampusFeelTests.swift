import XCTest
import MaroonCore
@testable import MaroonSocial

/// Campus feel: reply aliases, "+N" on New, notification grouping, the game-day window, organization
/// bylines and profile tiles.
@MainActor final class CampusFeelTests: XCTestCase {
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
  private func snapshot(_ posts: [Post], own: [String] = [], serverNow: Double? = 500, postCount: Int? = nil) throws -> Data {
    var value: [String: Any] = ["username": "feel_tester", "nsfwEnabled": false, "posts": try encoded(posts), "courses": [], "activities": [],
      "conversations": [], "ownPostIDs": own, "ownCommentIDs": [], "ownMessageIDs": [], "conversationMeta": [],
      "attachments": [], "organizations": [], "savedEvents": []]
    if let serverNow { value["serverNow"] = serverNow }
    if let postCount { value["postCount"] = postCount }
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
    store.state.username = "feel_tester"; store.state.onboarded = true; store.connected = true
    return store
  }
  /// Higher numbers are newer here (the opposite of the sync tests), so a delta's new post is "p9".
  private func post(_ number: Int, topic: String? = nil, synced: Double? = 100) -> Post {
    var post = Post(id: "p\(number)", author: "Anonymous", text: "Post \(number)", created: Date(timeIntervalSince1970: 1_000_000 + Double(number)))
    post.topic = topic; post.syncedAt = synced.map { Date(timeIntervalSince1970: $0) }
    return post
  }
  private func json(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
  private func topicRows() -> [[String: Any]] {
    TopicCatalog.active(TopicCatalog.fallback).map {
      ["slug": $0.slug, "title": $0.title, "emoji": $0.emoji, "text_hex": $0.textHex, "fill_hex": $0.fillHex, "sort_order": $0.order, "recent_count": 7]
    }
  }

  // MARK: Reply aliases

  func testAliasColourIsStableAndSpreadOverTheEightHues() {
    XCTAssertEqual(ReplyAlias.palette.count, 8)
    // FNV-1a, not Swift's per-launch Hasher: these values are the same on every device and launch.
    XCTAssertEqual(ReplyAlias.colorIndex("Aggie 1a2b"), ReplyAlias.colorIndex("Aggie 1a2b"))
    let pinned = ["Aggie 0000", "Aggie 1a2b", "Aggie ffff", "Aggie 9c3e"].map(ReplyAlias.colorIndex)
    XCTAssertEqual(pinned, [Self.fnvIndex("Aggie 0000"), Self.fnvIndex("Aggie 1a2b"), Self.fnvIndex("Aggie ffff"), Self.fnvIndex("Aggie 9c3e")])
    var used = Set<Int>()
    for value in 0..<256 { let index = ReplyAlias.colorIndex("Aggie " + String(format: "%04x", value * 251)); XCTAssertTrue((0..<8).contains(index)); used.insert(index) }
    XCTAssertEqual(used.count, 8, "Aliases spread over every hue")
  }
  /// An independent reference: FNV-1a 64 with the MurmurHash3 fmix64 finish.
  private static func fnvIndex(_ text: String) -> Int {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in Array(text.utf8) { hash ^= UInt64(byte); hash = hash &* 1_099_511_628_211 }
    hash ^= hash >> 33; hash = hash &* 18_397_679_294_719_823_053; hash ^= hash >> 33
    return Int(hash % 8)
  }

  func testAliasesAreStableWithinAPostAndDifferBetweenPosts() {
    // The server's alias is kept as is.
    XCTAssertEqual(ReplyAlias.alias(author: "Aggie 1a2b", postID: "any"), "Aggie 1a2b")
    // A copy that still names its author never shows the name: the same person gets the same alias in
    // one post and (almost always) a different one in another, like the server's md5(post || author).
    let first = ReplyAlias.alias(author: "demo-owl", postID: "demo-question-post")
    XCTAssertTrue(ReplyAlias.isAlias(first))
    XCTAssertEqual(first, ReplyAlias.alias(author: "demo-owl", postID: "demo-question-post"))
    XCTAssertNotEqual(first, ReplyAlias.alias(author: "demo-owl", postID: "demo-meme-post"))
    XCTAssertNotEqual(first, ReplyAlias.alias(author: "demo-quiet", postID: "demo-question-post"))
    XCTAssertFalse(ReplyAlias.isAlias("Anonymous")); XCTAssertFalse(ReplyAlias.isAlias("Aggie zzzz"))
  }

  func testReplyRowAndReplyTargetNamesFollowTheSameRules() {
    var other = Comment(author: "Aggie 1a2b", text: "Hi"); other.isOP = false
    var op = Comment(author: "OP", text: "Thanks"); op.isOP = true
    let named = Comment(author: "howdy", text: "Named", anonymous: false)
    var gone = Comment(author: "[deleted]", text: "[Reply deleted]"); gone.deleted = true
    let mine = Comment(author: "feel_tester", text: "Mine")
    XCTAssertEqual(ReplyAlias.display(other, postID: "p", mine: false), .alias("Aggie 1a2b"))
    XCTAssertEqual(ReplyAlias.display(op, postID: "p", mine: false), .op)
    XCTAssertEqual(ReplyAlias.display(named, postID: "p", mine: false), .named("@howdy"))
    XCTAssertEqual(ReplyAlias.display(gone, postID: "p", mine: false), .deleted)
    XCTAssertEqual(ReplyAlias.display(mine, postID: "p", mine: true), .mine("Anonymous"))
    XCTAssertEqual(ReplyAlias.target(other, postID: "p", mine: false), "Aggie 1a2b")
    XCTAssertEqual(ReplyAlias.target(op, postID: "p", mine: false), "OP")
    XCTAssertEqual(ReplyAlias.target(mine, postID: "p", mine: true), "your reply")
    XCTAssertEqual(ReplyAlias.target(named, postID: "p", mine: false), "@howdy")
    XCTAssertEqual(ReplyAlias.target(nil, postID: "p", mine: false), "a reply")
  }

  func testFixtureThreadHasStableAliasesAndAnOPReply() throws {
    let store = AppStore(storageURL: try file(), arguments: [])
    let thread = try XCTUnwrap(store.state.posts.first { $0.id == "demo-question-post" })
    let names = thread.comments.map { ReplyAlias.display($0, postID: thread.id, mine: store.owns($0)) }
    XCTAssertEqual(names[1], .op)
    XCTAssertEqual(names[0], names[2], "The same replier keeps one alias in a post")
    XCTAssertNotEqual(names[0], names[3])
    let meme = try XCTUnwrap(store.state.posts.first { $0.id == "demo-meme-post" })
    XCTAssertNotEqual(ReplyAlias.display(meme.comments[0], postID: meme.id, mine: false), names[0], "Another post gives the same replier another alias")
  }

  // MARK: "+N" on New

  func testDeltaPostsAboveTheListWaitBehindTheBadgeUntilTheTop() async throws {
    var changed: [Post] = []
    var removed: [String] = []
    let store = try networkStore { [self] _, action, _, _ in
      switch action {
      case "snapshot": return try snapshot((0..<5).map { post($0) }, own: ["p8"])
      case "feed.delta": return try json(["changed": try encoded(changed), "removed": removed, "now": 600])
      case "feed.posts": return try json(["posts": [], "removed": []])
      default: return Data("{}".utf8)
      }
    }
    await store.refresh()
    let key = store.currentFeedKey
    XCTAssertTrue(store.feedAtTop)
    // At the top, new posts join the list at once.
    changed = [post(6, synced: 600)]
    await store.syncFeedDelta()
    XCTAssertEqual(store.newPostCount(for: key), 0); XCTAssertTrue(store.feedPostIDs?.contains("p6") == true)
    // Reading further down: newer posts wait; an older one (backfill), an edit and your own post do not count.
    store.setFeedAtTop(false)
    var edited = post(2, synced: 610); edited.text = "Edited"
    changed = [post(9, synced: 610), post(10, synced: 610), post(-3, synced: 610), edited, post(8, synced: 610)]
    await store.syncFeedDelta()
    XCTAssertEqual(store.newPosts(for: key), ["p9", "p10"])
    XCTAssertEqual(store.newPostCount(for: key), 2, "The badge matches the new posts the delta returned")
    XCTAssertTrue(store.feedPostIDs?.isSuperset(of: ["p9", "p10", "p-3", "p8"]) == true, "They are in the feed, held back only from the list")
    // A later delta adds to the count; a removed post leaves it.
    changed = [post(11, synced: 620)]; removed = ["p9"]
    await store.syncFeedDelta()
    XCTAssertEqual(store.newPosts(for: key), ["p10", "p11"])
    // Back at the top (or New tapped) they join the list.
    changed = []; removed = []
    store.setFeedAtTop(true)
    XCTAssertEqual(store.newPostCount(for: key), 0)
    store.setFeedAtTop(false)
    changed = [post(12, synced: 630)]
    await store.syncFeedDelta()
    XCTAssertEqual(store.newPostCount(for: key), 1)
    store.showNewPosts(for: key)
    XCTAssertEqual(store.newPostCount(for: key), 0)
  }

  func testTopicDeltasCountForTheirOwnKey() async throws {
    var changed: [Post] = []
    let store = try networkStore { [self] _, action, payload, _ in
      switch action {
      case "snapshot": return try snapshot([post(1, topic: "sports")])
      case "topics.list": return try json(["topics": topicRows()])
      case "feed.page": return try json(["posts": try encoded([post(1, topic: "sports")]), "next": NSNull()])
      case "feed.delta":
        XCTAssertEqual(payload["topic"] as? String, "sports")
        return try json(["changed": try encoded(changed), "removed": [], "now": 700])
      default: return Data("{}".utf8)
      }
    }
    await store.refresh(); await store.refreshTopics()
    await store.selectTopic("sports")?.value
    store.setFeedAtTop(false)
    changed = [post(5, topic: "sports", synced: 700)]
    await store.syncFeedDelta()
    let sports = FeedKey(community: .campus, topic: "sports")
    XCTAssertEqual(store.newPostCount(for: sports), 1)
    XCTAssertEqual(store.newPostCount(for: FeedKey(community: .campus, topic: nil)), 0, "All has its own count")
  }

  /// A server without incremental reads sends no clock: no deltas run, so no badge.
  func testNoBadgeWithoutDeltas() async throws {
    var deltas = 0
    let store = try networkStore { [self] _, action, _, _ in
      if action == "feed.delta" { deltas += 1 }
      return try snapshot((0..<3).map { post($0) }, serverNow: nil)
    }
    await store.refresh()
    store.setFeedAtTop(false)
    await store.syncFeedDelta()
    await store.refresh()
    XCTAssertEqual(deltas, 0); XCTAssertEqual(store.newPostCount(for: store.currentFeedKey), 0)
  }

  func testFixtureSimulatesADeltaOnceTheFeedLeavesItsTop() throws {
    let store = AppStore(storageURL: try file(), arguments: [AppStore.feedDeltaArgument])
    store.deliverFixtureDeltaIfDue()
    XCTAssertEqual(store.newPostCount(for: store.currentFeedKey), 0, "Nothing arrives while the feed is at its top")
    store.setFeedAtTop(false)
    store.deliverFixtureDeltaIfDue()
    XCTAssertEqual(store.newPostCount(for: store.currentFeedKey), 2)
    store.deliverFixtureDeltaIfDue()
    XCTAssertEqual(store.state.posts.filter { $0.id.hasPrefix("fixture-delta-post") }.count, 2, "Delivered once")
    store.setFeedAtTop(true)
    XCTAssertEqual(store.newPostCount(for: store.currentFeedKey), 0)
    let plain = AppStore(storageURL: try file(), arguments: [])
    plain.setFeedAtTop(false); plain.deliverFixtureDeltaIfDue()
    XCTAssertFalse(plain.state.posts.contains { $0.id.hasPrefix("fixture-delta-post") })
  }

  /// Posts held behind "+N" for one list show when that list is shown at its top again: a topic or
  /// community switch opens a new page at the top, and pull to refresh happens there.
  func testHeldPostsShowWhenTheirListReturnsAtItsTop() async throws {
    let store = AppStore(storageURL: try file(), arguments: [AppStore.feedDeltaArgument])
    let all = store.currentFeedKey
    store.setFeedAtTop(false)
    store.deliverFixtureDeltaIfDue()
    XCTAssertEqual(store.newPostCount(for: all), 2)
    // Another topic opens at its top; a report from the page fading out (All, still scrolled) is ignored.
    await store.selectTopic("academics")?.value
    XCTAssertTrue(store.feedAtTop)
    store.setFeedAtTop(false, key: all)
    XCTAssertTrue(store.feedAtTop, "A page that is no longer shown does not move the flag")
    // Back on All: its page opens at the top with the held posts in it.
    await store.selectTopic(nil)?.value
    XCTAssertEqual(store.newPostCount(for: all), 0); XCTAssertTrue(store.feedAtTop)
    // Showing another key's list leaves this one's held posts; this page reaching its top shows them.
    let other = AppStore(storageURL: try file(), arguments: [AppStore.feedDeltaArgument])
    other.setFeedAtTop(false); other.deliverFixtureDeltaIfDue()
    let key = other.currentFeedKey
    other.listShownAtTop(FeedKey(community: .campus, topic: "academics"))
    XCTAssertEqual(other.newPostCount(for: key), 2, "Another key's list does not release this one")
    other.setFeedAtTop(true, key: key)
    XCTAssertEqual(other.newPostCount(for: key), 0)
    // Pull to refresh at the top releases them too.
    let pulled = AppStore(storageURL: try file(), arguments: [AppStore.feedDeltaArgument])
    pulled.setFeedAtTop(false); pulled.deliverFixtureDeltaIfDue()
    XCTAssertEqual(pulled.newPostCount(for: pulled.currentFeedKey), 2)
    await pulled.refreshFeed()
    XCTAssertEqual(pulled.newPostCount(for: pulled.currentFeedKey), 0)
  }

  // MARK: Notifications

  private func note(_ id: String, _ kind: SocialNotification.Kind, post: String?, minutes: Double, read: Bool = false) -> SocialNotification {
    SocialNotification(id: id, kind: kind, title: kind == .comment ? "New comment on your post" : kind == .reply ? "New reply to your comment" : "Title \(id)",
      body: "Body \(id)", postID: post, created: Date(timeIntervalSince1970: 10_000 + minutes * 60), read: read)
  }
  func testNotificationsGroupBySameKindAndPost() {
    let items = [
      note("c1", .comment, post: "a", minutes: 1, read: true), note("c2", .comment, post: "a", minutes: 5), note("c3", .comment, post: "a", minutes: 3),
      note("r1", .reply, post: "a", minutes: 4), note("c4", .comment, post: "b", minutes: 2),
      note("u1", .upvotes, post: "a", minutes: 6, read: true), note("x1", .announcement, post: nil, minutes: 7), note("x2", .announcement, post: nil, minutes: 0),
    ]
    let groups = NotificationGrouping.group(items)
    XCTAssertEqual(groups.map(\.id), ["x1", "u1", "c2", "r1", "c4", "x2"], "Ordered by each group's newest item")
    let comments = groups[2]
    XCTAssertEqual(comments.items.map(\.id), ["c2", "c3", "c1"])
    XCTAssertEqual(comments.title, "3 new comments on your post", "Counts replies; the payload cannot tell people apart")
    XCTAssertEqual(comments.body, "Body c2"); XCTAssertFalse(comments.read); XCTAssertEqual(comments.unreadIDs, ["c2", "c3"])
    XCTAssertEqual(groups[3].title, "New reply to your comment", "A single notification keeps its own title")
    XCTAssertTrue(groups[1].read)
    let pair = NotificationGrouping.group([note("r1", .reply, post: "a", minutes: 1), note("r2", .reply, post: "a", minutes: 2)])
    XCTAssertEqual(pair.first?.title, "2 new replies to you on this post")
    XCTAssertEqual(NotificationGrouping.group([]).count, 0)
  }

  // MARK: Game-day chat link

  func testGameDayWindowMatchesTheCampusCard() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func event(_ id: String, starts: TimeInterval, category: String = "Sports", allDay: Bool = false, cancelled: Bool = false, ends: TimeInterval? = nil) -> CampusEvent {
      CampusEvent(id: id, title: id, category: category, starts: now.addingTimeInterval(starts), ends: ends.map { now.addingTimeInterval($0) }, allDay: allDay, url: "https://example.edu", source: "test", cancelled: cancelled)
    }
    XCTAssertEqual(CampusService.gameDay(in: [event("live", starts: -600)], now: now)?.id, "live")
    // The chat opens 30 minutes before the start; the link shows from three hours before that.
    XCTAssertEqual(CampusService.gameDay(in: [event("soon", starts: 3 * 3600 + 1800)], now: now)?.id, "soon")
    XCTAssertNil(CampusService.gameDay(in: [event("later", starts: 3 * 3600 + 1801)], now: now))
    XCTAssertNil(CampusService.gameDay(in: [event("over", starts: -7 * 3600)], now: now), "Six hours after the start without an end")
    XCTAssertNil(CampusService.gameDay(in: [event("ended", starts: -3600, ends: -60)], now: now))
    XCTAssertNil(CampusService.gameDay(in: [event("talk", starts: -600, category: "Lectures")], now: now))
    XCTAssertNil(CampusService.gameDay(in: [event("allday", starts: -600, allDay: true), event("off", starts: -600, cancelled: true)], now: now))
    XCTAssertEqual(CampusService.gameDay(in: [event("second", starts: 1800), event("first", starts: -600)], now: now)?.id, "first")
    XCTAssertTrue(event("live", starts: -600).canOpenSportsChat(at: now)); XCTAssertFalse(event("soon", starts: 3 * 3600).canOpenSportsChat(at: now))
  }

  func testFixtureGameDayEventIsLiveAndOpensItsRoom() async throws {
    let store = AppStore(storageURL: try file(), arguments: [AppStore.gameDayArgument])
    XCTAssertTrue(store.campus.events.contains { $0.id == AppStore.fixtureGameDayEvent.id })
    XCTAssertNotNil(store.campus.gameDay(), "The fixture game is live")
    XCTAssertTrue(AppStore.fixtureGameDayEvent.canOpenSportsChat(at: .now))
    let joined = await store.perform("join_sports", ["event_id": AppStore.fixtureGameDayEvent.id])
    XCTAssertEqual(joined?.resourceID, "sports:" + AppStore.fixtureGameDayEvent.id)
    XCTAssertNil(AppStore(storageURL: try file(), arguments: []).campus.events.first { $0.id == AppStore.fixtureGameDayEvent.id })
  }

  // MARK: Organization bylines

  func testOrganizationBylineDecodesAndShowsTheSeal() throws {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
    let base = #""id":"p","author":"ring","anonymous":false,"community":"Texas A&M","text":"Hi","score":1,"vote":0,"comments":[],"created":1700000000,"saved":false,"acceptsDM":true"#
    let organization = try decoder.decode(Post.self, from: Data(("{" + base + #","organization":{"id":"o1","name":"Ring Day Committee","verified":true}}"#).utf8))
    XCTAssertEqual(organization.bylineName, "Ring Day Committee"); XCTAssertTrue(organization.showsVerifiedSeal)
    let member = try decoder.decode(Post.self, from: Data(("{" + base + "}").utf8))
    XCTAssertNil(member.organization); XCTAssertEqual(member.bylineName, "@ring"); XCTAssertFalse(member.showsVerifiedSeal)
    let malformed = try decoder.decode(Post.self, from: Data(("{" + base + #","organization":"Ring Day"}"#).utf8))
    XCTAssertNil(malformed.organization, "A malformed byline never costs the post")
    let pending = try decoder.decode(Post.self, from: Data(("{" + base + #","organization":{"id":"o1","name":"Club"}}"#).utf8))
    XCTAssertFalse(pending.showsVerifiedSeal, "Only a verified organization gets the seal")
    let quote = PostQuote(quoting: organization)
    XCTAssertEqual(quote.displayName, "Ring Day Committee"); XCTAssertTrue(quote.showsVerifiedSeal)
    let roundTrip = try decoder.decode(PostQuote.self, from: JSONEncoder().encode(quote))
    XCTAssertEqual(roundTrip.organization, quote.organization)
    let legacyQuote = try decoder.decode(PostQuote.self, from: Data(#"{"id":"q","unavailable":false,"author":"Anonymous","anonymous":true}"#.utf8))
    XCTAssertNil(legacyQuote.organization); XCTAssertFalse(legacyQuote.showsVerifiedSeal)
  }

  // MARK: Profile tiles

  func testPostsTileCountsTheMembersLivePosts() async throws {
    var gone = post(2); gone.deleted = true
    let store = try networkStore { [self] _, _, _, _ in try snapshot([post(1), gone, post(3)], own: ["p1", "p2", "p7"]) }
    await store.refresh()
    XCTAssertEqual(store.ownPostCount, 2, "Older server: deleted posts held here leave the count")
    // The server's live count wins: deleted posts this device never held are not counted.
    let counted = try networkStore { [self] _, _, _, _ in try snapshot([post(1), gone, post(3)], own: ["p1", "p2", "p7", "p8"], postCount: 2) }
    await counted.refresh()
    XCTAssertEqual(counted.ownPostCount, 2, "The snapshot's postCount excludes every deleted post")
    let fixture = AppStore(storageURL: try file(), arguments: [])
    fixture.enter(username: "tile_tester")
    let before = fixture.ownPostCount
    let posted = await fixture.createPost(text: "Mine", anonymous: true, community: .campus, acceptsDM: true, topic: "academics")
    XCTAssertTrue(posted); XCTAssertEqual(fixture.ownPostCount, before + 1)
  }
}
