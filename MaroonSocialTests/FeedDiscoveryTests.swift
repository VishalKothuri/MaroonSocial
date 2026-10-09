import XCTest
import MaroonCore
@testable import MaroonSocial

/// Server search (`posts.search`), the Top sort (`feed.top`) and post links: the contract both
/// sides share, the fallback to today's behaviour on a server without the actions, paging with
/// the opaque cursor, cancellation and the link queue.
@MainActor final class FeedDiscoveryTests: XCTestCase {
  private var directories: [URL] = []
  override func tearDown() {
    directories.forEach { try? FileManager.default.removeItem(at: $0) }
    directories = []
    super.tearDown()
  }
  private static let unknownAction = SocialServiceError(error: "Unknown social action.", code: "invalid")
  private func credentials() -> SocialCredentialStore {
    SocialCredentialStore(read: { String(repeating: "a", count: 64) }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {})
  }
  private func file() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    directories.append(directory)
    return directory.appending(path: "social-cache.json")
  }
  private func networkStore(file: URL? = nil, _ transport: @escaping SocialService.Transport) throws -> AppStore {
    let store = AppStore(storageURL: try file ?? self.file(), arguments: [], socialService: SocialService(credentials: credentials(), transport: transport))
    store.state.username = "discovery_tester"; store.state.onboarded = true; store.connected = true
    return store
  }
  private func encoded<Value: Encodable>(_ value: Value) throws -> Any {
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
    return try JSONSerialization.jsonObject(with: encoder.encode(value))
  }
  private func post(_ id: String, score: Int = 0, topic: String? = nil, community: Community = .campus, text: String? = nil) -> Post {
    var post = Post(id: id, author: "Anonymous", community: community, text: text ?? "Post \(id)", score: score, created: Date(timeIntervalSince1970: 1_000_000))
    post.topic = topic
    return post
  }
  private func page(_ posts: [Post], more: Bool, cursor: Any?) throws -> Data {
    try JSONSerialization.data(withJSONObject: ["posts": try encoded(posts), "more": more, "cursor": cursor ?? NSNull()])
  }
  private func same(_ lhs: Any?, _ rhs: Any) -> Bool {
    guard let lhs, let left = try? JSONSerialization.data(withJSONObject: lhs, options: .sortedKeys),
      let right = try? JSONSerialization.data(withJSONObject: rhs, options: .sortedKeys) else { return false }
    return left == right
  }

  // MARK: Post links

  func testPostLinksParseBothFormsAndRejectEverythingElse() {
    let id = "0F8C2C5E-2B7A-4C1D-9E3F-1A2B3C4D5E6F"
    let lower = id.lowercased()
    XCTAssertEqual(PostLinks.postID(from: URL(string: "maroonsocial://post/\(id)")!), lower)
    XCTAssertEqual(PostLinks.postID(from: URL(string: "MaroonSocial://POST/\(lower)")!), lower)
    XCTAssertEqual(PostLinks.postID(from: URL(string: "https://maroonsocial.chat/p/\(id)")!), lower)
    XCTAssertEqual(PostLinks.postID(from: URL(string: "https://www.maroonsocial.chat/p/\(lower)/")!), lower)
    XCTAssertEqual(PostLinks.postID(from: URL(string: "https://maroonsocial.chat/p/\(lower)?utm=x#top")!), lower)
    for bad in ["https://maroonsocial.chat/p/not-a-uuid", "https://maroonsocial.chat/post/\(lower)", "https://evil.example/p/\(lower)",
                "https://maroonsocial.chat.evil.example/p/\(lower)", "http://maroonsocial.chat/p/\(lower)", "maroonsocial://room/\(lower)",
                "maroonsocial://post/\(lower)/extra", "https://maroonsocial.chat/p/\(lower)/extra", "https://maroonsocial.chat/"] {
      XCTAssertNil(PostLinks.postID(from: URL(string: bad)!), bad)
    }
  }

  func testShareLinkCarriesOnlyTheLinkAndOneLine() {
    XCTAssertEqual(PostLinks.shareURL(for: "0F8C2C5E-2B7A-4C1D-9E3F-1A2B3C4D5E6F").absoluteString, "https://maroonsocial.chat/p/0f8c2c5e-2b7a-4c1d-9e3f-1a2b3c4d5e6f")
    XCTAssertEqual(PostLinks.shareLine, "See this on Maroon Social")
  }

  func testOpenedLinkWaitsUntilSignedInAndOnlyOurLinksComplain() throws {
    let store = try networkStore { _, _, _, _ in Data("{}".utf8) }
    store.state.onboarded = false; store.connected = false
    let id = UUID().uuidString.lowercased()
    XCTAssertTrue(store.openLink(URL(string: "https://maroonsocial.chat/p/\(id)")!))
    XCTAssertEqual(store.pendingPostLink, id, "Queued until the member is signed in and connected")
    XCTAssertFalse(store.openLink(URL(string: "maroonsocial://post/nope")!))
    XCTAssertNotNil(store.notice, "A broken link of ours says so")
    XCTAssertEqual(store.pendingPostLink, id, "A broken link does not replace the queued one")
    store.notice = nil
    XCTAssertFalse(store.openLink(URL(string: "https://example.com/p/\(id)")!))
    XCTAssertNil(store.notice)
  }

  func testFixtureDeepLinkArgumentQueuesThePost() throws {
    let id = "8a4f1c62-3d5e-4b7a-9c0d-2e1f3a4b5c6d"
    let store = AppStore(storageURL: try file(), arguments: ["--uitesting", AppStore.deepLinkArgument, "maroonsocial://post/\(id)"])
    XCTAssertEqual(store.pendingPostLink, id)
  }

  // MARK: Opaque cursors

  func testCursorIsSentBackVerbatim() throws {
    let cursor: [String: Any] = ["rank": 0.0607927, "created": 1_759_900_000.123456, "id": "c2", "nested": ["a": [1, 2], "b": NSNull(), "c": true]]
    let data = try JSONSerialization.data(withJSONObject: ["posts": [], "more": true, "cursor": cursor])
    let decoded = try JSONDecoder().decode(SocialPostsPage.self, from: data)
    XCTAssertTrue(decoded.hasNext)
    XCTAssertTrue(same(decoded.cursor?.foundation, cursor))
    // A cursor that is not an object ends paging.
    let odd = try JSONDecoder().decode(SocialPostsPage.self, from: try JSONSerialization.data(withJSONObject: ["posts": [], "more": true, "cursor": "abc"]))
    XCTAssertNil(odd.cursor); XCTAssertFalse(odd.hasNext)
    XCTAssertTrue(same(JSONValue.object(["offset": .number(30)]).foundation, ["offset": 30]))
  }

  func testFixturePagesUseOffsetCursorsWithoutDuplicates() {
    let posts = (0..<65).map { post("f\($0)") }
    var seen: [String] = []
    var cursor: JSONValue?
    repeat {
      let next = AppStore.fixturePage(posts, cursor: cursor)
      seen += next.posts.map(\.id); cursor = next.hasNext ? next.cursor : nil
    } while cursor != nil
    XCTAssertEqual(seen, posts.map(\.id))
  }

  // MARK: Search

  func testSearchQueriesTheServerDebouncedWithinCommunityAndTopicThenPages() async throws {
    var requests: [[String: Any]] = []
    let store = try networkStore { [self] _, action, payload, _ in
      XCTAssertEqual(action, "posts.search")
      requests.append(payload)
      if payload["cursor"] == nil {
        return try page([post("s1", topic: "academics"), post("s2", topic: "academics")], more: true, cursor: ["rank": 0.5, "id": "s2"])
      }
      // The second page repeats s2 (a moving rank); it is listed once.
      return try page([post("s2", topic: "academics"), post("s3", topic: "academics")], more: false, cursor: nil)
    }
    store.updateSearch("  e", community: .campus, topic: "academics")
    XCTAssertNil(store.search.key, "One character is not a server search")
    store.updateSearch("  ev", community: .campus, topic: "academics")
    store.updateSearch("  evans  ", community: .campus, topic: "academics")
    XCTAssertTrue(store.search.loading, "The loading row shows while the request waits out the debounce")
    await store.searchTask?.value
    XCTAssertEqual(requests.count, 1, "Earlier keystrokes inside the 300 ms window never reach the server")
    XCTAssertEqual(requests.first?["query"] as? String, "evans", "The query is trimmed")
    XCTAssertEqual(requests.first?["community"] as? String, Community.campus.rawValue)
    XCTAssertEqual(requests.first?["topic"] as? String, "academics")
    XCTAssertEqual(requests.first?["limit"] as? Int, 30)
    XCTAssertNil(requests.first?["cursor"])
    XCTAssertEqual(store.searchSupported, true)
    XCTAssertEqual(store.searchResults().map(\.id), ["s1", "s2"])
    XCTAssertTrue(store.search.more)
    await store.loadMoreSearch()
    XCTAssertTrue(same(requests.last?["cursor"], ["rank": 0.5, "id": "s2"]), "The cursor goes back exactly as received")
    XCTAssertEqual(store.searchResults().map(\.id), ["s1", "s2", "s3"])
    XCTAssertFalse(store.search.more)
    // Results stay in the canonical list across a snapshot-free merge (they can be voted on).
    XCTAssertTrue(store.discoveryPostIDs.isSuperset(of: ["s1", "s2", "s3"]))
    // A delta that removes a result (blocked, deleted) removes it from the results too.
    store.removeFromDiscovery(["s2"])
    XCTAssertEqual(store.searchResults().map(\.id), ["s1", "s3"])
    // The same input again asks nothing; clearing the field clears the results.
    store.updateSearch("evans", community: .campus, topic: "academics")
    XCTAssertEqual(requests.count, 2)
    store.updateSearch("", community: .campus, topic: "academics")
    XCTAssertNil(store.search.key); XCTAssertEqual(store.searchResults(), [])
  }

  func testNewInputCancelsTheRequestInFlight() async throws {
    var queries: [String] = []
    let store = try networkStore { [self] _, _, payload, _ in
      let query = payload["query"] as? String ?? ""
      queries.append(query)
      if query == "slow" { try await Task.sleep(for: .seconds(2)) }
      return try page([post(query == "slow" ? "old" : "new")], more: false, cursor: nil)
    }
    store.updateSearch("slow", community: .campus, topic: nil)
    try await Task.sleep(for: .milliseconds(450))
    XCTAssertEqual(queries, ["slow"], "The first request is in flight")
    store.updateSearch("fast", community: .campus, topic: nil)
    await store.searchTask?.value
    XCTAssertEqual(store.search.key?.query, "fast")
    XCTAssertEqual(store.searchResults().map(\.id), ["new"])
    try await Task.sleep(for: .milliseconds(300))
    XCTAssertEqual(store.searchResults().map(\.id), ["new"], "The cancelled answer never lands")
  }

  func testServerWithoutSearchFallsBackToTheLocalFilter() async throws {
    var calls = 0
    let store = try networkStore { _, action, _, _ in
      calls += 1
      XCTAssertEqual(action, "posts.search")
      throw Self.unknownAction
    }
    XCTAssertTrue(store.serverSearchAvailable, "Unknown until the first answer")
    store.updateSearch("evans", community: .campus, topic: nil)
    await store.searchTask?.value
    XCTAssertEqual(store.searchSupported, false)
    XCTAssertFalse(store.serverSearchAvailable)
    XCTAssertEqual(store.search, PostSearchState(), "No server state: the view filters the loaded posts")
    XCTAssertNil(store.notice, "An old server is not an error")
    store.updateSearch("library", community: .campus, topic: nil)
    XCTAssertNil(store.searchTask)
    XCTAssertEqual(calls, 1, "Never asked again")
    // The fallback filter matches body or poll question, as before.
    XCTAssertTrue(PostSearchRules.locallyMatches(post("a", text: "Evans is open"), "evans"))
    XCTAssertFalse(PostSearchRules.locallyMatches(post("b", text: "Library"), "evans"))
  }

  func testSearchErrorShowsRetryAndRateLimitCopy() async throws {
    var fail = true
    let store = try networkStore { [self] _, _, _, _ in
      if fail { throw SocialServiceError(error: "Take a moment before searching again.", code: "rate_limit") }
      return try page([post("r1")], more: false, cursor: nil)
    }
    store.updateSearch("evans", community: .campus, topic: nil)
    await store.searchTask?.value
    XCTAssertEqual(store.search.error, "Take a moment before searching again.")
    XCTAssertNotEqual(store.searchSupported, false, "A refusal is not an old server")
    fail = false
    store.retrySearch()
    await store.searchTask?.value
    XCTAssertNil(store.search.error)
    XCTAssertEqual(store.searchResults().map(\.id), ["r1"])
  }

  func testQueryRules() {
    XCTAssertNil(PostSearchRules.query(" a "))
    XCTAssertEqual(PostSearchRules.query(" ab "), "ab")
    XCTAssertNotNil(PostSearchRules.query(String(repeating: "x", count: 80)))
    XCTAssertNil(PostSearchRules.query(String(repeating: "x", count: 81)))
    XCTAssertEqual(PostSearchRules.clamped(String(repeating: "x", count: 95)).count, 80)
    // The server counts code points (char_length): a toned thumbs-up is one character but two.
    let thumbs = "\u{1F44D}\u{1F3FD}"
    XCTAssertEqual(PostSearchRules.length(thumbs), 2)
    XCTAssertNotNil(PostSearchRules.query(String(repeating: thumbs, count: 40)), "80 code points")
    XCTAssertNil(PostSearchRules.query(String(repeating: thumbs, count: 41)), "82 code points is over the limit")
    let clamped = PostSearchRules.clamped(String(repeating: thumbs, count: 41))
    XCTAssertEqual(PostSearchRules.length(clamped), 80)
    XCTAssertEqual(clamped, String(repeating: thumbs, count: 40), "Cut between whole characters")
    // A flag (two scalars) is never split at the limit: 79 letters leave room for none of it.
    XCTAssertEqual(PostSearchRules.clamped(String(repeating: "x", count: 79) + "\u{1F1FA}\u{1F1F8}"), String(repeating: "x", count: 79))
    XCTAssertEqual(PostSearchRules.length("e\u{301}"), 2, "A combining accent counts as the server counts it")
  }

  func testCancelledNextPageLetsTheRowAskAgain() async throws {
    var cancelNext = true
    var cursors: [Any] = []
    let store = try networkStore { [self] _, _, payload, _ in
      guard let cursor = payload["cursor"] else { return try page([post("p1")], more: true, cursor: ["offset": 1]) }
      cursors.append(cursor)
      if cancelNext { throw CancellationError() }
      return try page([post("p2")], more: false, cursor: nil)
    }
    store.updateSearch("evans", community: .campus, topic: nil)
    await store.searchTask?.value
    XCTAssertTrue(store.search.more)
    // The paging row left the screen while its request ran.
    await store.loadMoreSearch()
    XCTAssertFalse(store.search.loadingMore, "No spinner left behind")
    XCTAssertFalse(store.search.moreFailed)
    cancelNext = false
    await store.loadMoreSearch()
    XCTAssertEqual(cursors.count, 2, "The reappearing row asks again")
    XCTAssertEqual(store.searchResults().map(\.id), ["p1", "p2"])
  }

  func testFirstSearchWithoutAnAnswerFiltersTheLoadedPosts() async throws {
    var failure: Error = URLError(.notConnectedToInternet)
    var calls = 0
    let store = try networkStore { [self] _, _, _, _ in
      calls += 1
      if calls <= 2 { throw failure }
      return try page([post("s1")], more: false, cursor: nil)
    }
    store.updateSearch("evans", community: .campus, topic: nil)
    await store.searchTask?.value
    XCTAssertTrue(store.search.localFallback, "Offline before any answer: the loaded posts are filtered, as before")
    XCTAssertFalse(store.searchShowsServerResults)
    XCTAssertNil(store.search.error); XCTAssertNil(store.searchSupported, "Not an old server: the next query asks again")
    store.updateSearch("evans", community: .campus, topic: nil)
    XCTAssertEqual(calls, 1, "The same query stays on the local filter")
    failure = SocialServiceError(error: "The community service is temporarily unavailable. Please retry.", code: "unavailable")
    store.updateSearch("library", community: .campus, topic: nil)
    await store.searchTask?.value
    XCTAssertTrue(store.search.localFallback, "The gateway's 503 is no answer either")
    store.updateSearch("evans hall", community: .campus, topic: nil)
    await store.searchTask?.value
    XCTAssertTrue(store.searchShowsServerResults); XCTAssertEqual(store.searchSupported, true)
    XCTAssertEqual(store.searchResults().map(\.id), ["s1"])
    // Once the server has answered, a failure shows the error with Try again.
    failure = URLError(.notConnectedToInternet); calls = 0
    store.updateSearch("dorms", community: .campus, topic: nil)
    await store.searchTask?.value
    XCTAssertFalse(store.search.localFallback); XCTAssertNotNil(store.search.error)
  }

  func testPostsOnlySearchAndTopHoldAreReadAgainAfterAMutation() async throws {
    var actions: [String] = []
    var asked: [[String]] = []
    let store = try networkStore { [self] _, action, payload, _ in
      actions.append(action)
      switch action {
      case "posts.search": return try page([post("s1", score: 1), post("s2", score: 1)], more: false, cursor: nil)
      case "feed.top": return try page([post("t1", score: 4), post("s1", score: 1)], more: false, cursor: nil)
      case "feed.posts":
        asked.append(payload["ids"] as? [String] ?? [])
        var voted = post("s1", score: 2); voted.vote = 1
        return try JSONSerialization.data(withJSONObject: ["posts": try encoded([voted, post("t1", score: 4)]), "removed": ["s2"]])
      default: return Data("{}".utf8)
      }
    }
    store.state.topSupported = true
    store.updateSearch("evans", community: .campus, topic: nil)
    await store.searchTask?.value
    let week = TopFeedKey(community: .campus, topic: nil, window: .week)
    await store.loadTopFeed(week)
    XCTAssertEqual(Set(store.discoveryOnlyPostIDs()[.campus] ?? []), ["s1", "s2", "t1"])
    let voted = await store.mutate("post.vote", ["post_id": "s1", "value": 1])
    XCTAssertTrue(voted)
    XCTAssertEqual(asked.map(Set.init), [["s1", "s2", "t1"]], "Each held id once")
    XCTAssertEqual(store.searchResults().map(\.id), ["s1"], "Gone posts leave the results")
    XCTAssertEqual(store.searchResults().first?.vote, 1, "The member's own vote shows")
    XCTAssertEqual(store.topPosts(week).first { $0.id == "s1" }?.score, 2)
    // A deleted post leaves at once, before any read.
    asked = []
    let deleted = await store.mutate("post.delete", ["post_id": "t1"])
    XCTAssertTrue(deleted)
    XCTAssertFalse(store.topPosts(week).contains { $0.id == "t1" })
    XCTAssertFalse(store.search.ids.contains("t1"))
  }

  func testReportAndBlockDropThePostFromResultsAtOnce() async throws {
    let store = try networkStore { [self] _, action, _, _ in
      switch action {
      case "posts.search": return try page([post("a1"), post("a2"), post("a3")], more: false, cursor: nil)
      case "feed.posts": throw URLError(.notConnectedToInternet)
      default: return Data("{}".utf8)
      }
    }
    store.updateSearch("evans", community: .campus, topic: nil)
    await store.searchTask?.value
    _ = await store.mutate("report", ["target_type": "post", "target_id": "a1", "reason": "Spam"])
    _ = await store.mutate("block", ["post_id": "a2"])
    XCTAssertEqual(store.searchResults().map(\.id), ["a3"], "Even when the re-read fails")
  }

  func testFixtureSearchMatchesTextWithinCommunityAndTopic() async throws {
    let store = AppStore(storageURL: try file(), arguments: ["--uitesting"])
    store.updateSearch("evans", community: .campus, topic: nil)
    await store.searchTask?.value
    XCTAssertEqual(store.searchResults().map(\.id), ["demo-question-post"])
    store.updateSearch("evans", community: .campus, topic: "memes")
    await store.searchTask?.value
    XCTAssertTrue(store.search.loaded); XCTAssertEqual(store.searchResults(), [], "Nothing in Memes matches")
    let old = AppStore(storageURL: try file(), arguments: ["--uitesting", AppStore.noSearchTopArgument])
    XCTAssertFalse(old.serverSearchAvailable); XCTAssertFalse(old.topSortAvailable)
    XCTAssertEqual(old.feedSorts, ["New", "Hot"])
  }

  // MARK: Top

  func testTopProbeShowsTopAndAnOldServerKeepsNewAndHot() async throws {
    var answer: Result<Data, Error> = .failure(Self.unknownAction)
    var probes: [[String: Any]] = []
    let url = try file()
    let store = try networkStore(file: url) { _, action, payload, _ in
      XCTAssertEqual(action, "feed.top"); probes.append(payload)
      return try answer.get()
    }
    await store.probeTopSort()
    XCTAssertFalse(store.topSortAvailable); XCTAssertEqual(store.feedSorts, ["New", "Hot"])
    await store.probeTopSort()
    XCTAssertEqual(probes.count, 1, "Probed once per launch")
    answer = .success(try page([], more: false, cursor: nil))
    store.topProbed = false
    await store.probeTopSort()
    XCTAssertEqual(probes.last?["window"] as? String, "week"); XCTAssertEqual(probes.last?["limit"] as? Int, 1)
    XCTAssertTrue(store.topSortAvailable); XCTAssertEqual(store.feedSorts, ["New", "Hot", "Top"])
    // Remembered, so Top shows at the next launch while it is probed again.
    let relaunched = try networkStore(file: url) { _, _, _, _ in throw URLError(.notConnectedToInternet) }
    XCTAssertTrue(relaunched.topSortAvailable)
    await relaunched.probeTopSort()
    XCTAssertTrue(relaunched.topSortAvailable, "A network failure keeps the remembered answer")
    XCTAssertFalse(relaunched.topProbed, "and tries again later")
  }

  func testTopPagesByScoreWithoutDuplicatesAndFollowsTheWindow() async throws {
    var requests: [[String: Any]] = []
    let key = TopFeedKey(community: .campus, topic: "sports", window: .day)
    let sports = try networkStore { [self] _, _, payload, _ in
      requests.append(payload)
      if payload["cursor"] == nil { return try page([post("t1", score: 9, topic: "sports"), post("t2", score: 7, topic: "sports")], more: true, cursor: ["offset": 2]) }
      return try page([post("t2", score: 8, topic: "sports"), post("t3", score: 5, topic: "sports")], more: false, cursor: nil)
    }
    sports.state.topSupported = true
    XCTAssertTrue(sports.topFeedState(key).showsLoading, "Loading until the first page")
    let loaded = await sports.loadTopFeed(key)
    XCTAssertTrue(loaded)
    XCTAssertEqual(requests.first?["window"] as? String, "day"); XCTAssertEqual(requests.first?["topic"] as? String, "sports")
    XCTAssertEqual(requests.first?["community"] as? String, Community.campus.rawValue)
    XCTAssertEqual(sports.topPosts(key).map(\.id), ["t1", "t2"])
    await sports.loadMoreTop(key)
    XCTAssertTrue(same(requests.last?["cursor"], ["offset": 2]))
    XCTAssertEqual(sports.topPosts(key).map(\.id), ["t1", "t2", "t3"])
    XCTAssertFalse(sports.topFeedState(key).more)
    XCTAssertEqual(sports.state.posts.first { $0.id == "t2" }?.score, 8, "The card shows the newest score")
    // Another window is its own list.
    XCTAssertEqual(sports.topPosts(TopFeedKey(community: .campus, topic: "sports", window: .week)), [])
  }

  func testTopOnAServerThatLostTheActionFallsBackToNewAndHot() async throws {
    let store = try networkStore { _, _, _, _ in throw Self.unknownAction }
    store.state.topSupported = true
    let key = TopFeedKey(community: .campus, topic: nil, window: .week)
    let loaded = await store.loadTopFeed(key)
    XCTAssertFalse(loaded)
    XCTAssertFalse(store.topSortAvailable); XCTAssertEqual(store.feedSorts, ["New", "Hot"])
    XCTAssertNil(store.notice)
  }

  func testFixtureTopRanksByScoreInsideTheWindow() async throws {
    let store = AppStore(storageURL: try file(), arguments: ["--uitesting"])
    XCTAssertTrue(store.topSortAvailable)
    let week = TopFeedKey(community: .campus, topic: nil, window: .week)
    await store.loadTopFeed(week)
    let scores = store.topPosts(week).map(\.score)
    XCTAssertFalse(scores.isEmpty); XCTAssertEqual(scores, scores.sorted(by: >))
    let day = TopFeedKey(community: .campus, topic: nil, window: .day)
    await store.loadTopFeed(day)
    XCTAssertFalse(store.topPosts(day).contains { $0.id == "demo-sports-post" }, "A day-old post is outside Today")
    XCTAssertTrue(store.topPosts(week).contains { $0.id == "demo-sports-post" })
  }

  func testSortSwipeMovesThroughTopOnlyWhenOffered() {
    let left = CGPoint(x: -200, y: 0), right = CGPoint(x: 200, y: 0), still = CGPoint.zero
    XCTAssertEqual(CommunitySortSwipeIntent.destination(selection: "Hot", options: ["New", "Hot", "Top"], width: 390, translation: left, velocity: still), "Top")
    XCTAssertEqual(CommunitySortSwipeIntent.destination(selection: "Top", options: ["New", "Hot", "Top"], width: 390, translation: right, velocity: still), "Hot")
    XCTAssertNil(CommunitySortSwipeIntent.destination(selection: "Top", options: ["New", "Hot", "Top"], width: 390, translation: left, velocity: still))
    XCTAssertNil(CommunitySortSwipeIntent.destination(selection: "Hot", width: 390, translation: left, velocity: still), "Old server: Hot is the end")
  }

  func testSignOutForgetsResultsAndTopPages() async throws {
    let store = try networkStore { [self] _, action, _, _ in
      if action == "posts.search" { return try page([post("x1")], more: false, cursor: nil) }
      return try page([post("y1")], more: false, cursor: nil)
    }
    store.state.topSupported = true
    store.updateSearch("evans", community: .campus, topic: nil)
    await store.searchTask?.value
    await store.loadTopFeed(TopFeedKey(community: .campus, topic: nil, window: .week))
    XCTAssertFalse(store.discoveryPostIDs.isEmpty)
    store.resetDiscovery()
    XCTAssertTrue(store.discoveryPostIDs.isEmpty)
    XCTAssertEqual(store.search, PostSearchState()); XCTAssertEqual(store.topWindow, .week)
    XCTAssertNil(store.searchSupported)
  }
}
