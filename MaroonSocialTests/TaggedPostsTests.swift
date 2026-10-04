import XCTest
import MaroonCore
@testable import MaroonSocial

@MainActor final class TaggedPostsTests: XCTestCase {
  private func credentialStore() -> SocialCredentialStore {
    SocialCredentialStore(read: { String(repeating: "a", count: 64) }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {})
  }
  private func encodedPosts(_ posts: [Post]) throws -> Any {
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
    return try JSONSerialization.jsonObject(with: encoder.encode(posts))
  }
  private func snapshot(_ posts: [Post]) throws -> Data {
    try JSONSerialization.data(withJSONObject: ["snapshot": ["username": "tag_tester", "nsfwEnabled": false,
      "posts": encodedPosts(posts), "courses": [], "activities": [], "conversations": [], "ownPostIDs": [],
      "ownCommentIDs": [], "ownMessageIDs": [], "conversationMeta": [], "attachments": [], "organizations": [], "savedEvents": []]])
  }
  func testServerTagQueryNormalizesAndDecodesCanonicalPostFeatures() async throws {
    var post = Post(id: "older", author: "Anonymous", text: "Older result", created: Date(timeIntervalSince1970: 100))
    post.tags = ["study"]; post.poll = PostPoll(question: "Where?", options: [.init(id: "a", text: "A"), .init(id: "b", text: "B")], endsAt: Date(timeIntervalSince1970: 200))
    let payload = try JSONSerialization.data(withJSONObject: ["posts": encodedPosts([post])])
    let service = SocialService(credentials: credentialStore()) { endpoint, action, input, token in
      XCTAssertEqual(endpoint, "social"); XCTAssertEqual(action, "posts.tag")
      XCTAssertEqual(input["tag"] as? String, "study"); XCTAssertEqual(input["community"] as? String, "Texas A&M")
      XCTAssertNotNil(token); return payload
    }
    let result = try await service.posts(tag: "#Study", community: .campus)
    XCTAssertEqual(result, [post]); XCTAssertEqual(result.first?.poll?.endsAt, Date(timeIntervalSince1970: 200))
  }
  func testNestedOwnersRefreshOneQueryAndKeepFeedSeparateAcrossMutations() async throws {
    let recent = Post(id: "recent", author: "other", text: "New feed post", created: Date(timeIntervalSince1970: 1_000))
    var older = Post(id: "older", author: "Anonymous", text: "Old tagged post", created: Date(timeIntervalSince1970: 100)); older.tags = ["study"]
    older.setVote(1)
    let feed = try snapshot([recent]); let tagData = try JSONSerialization.data(withJSONObject: ["posts": encodedPosts([older])])
    var actions: [String] = []
    let service = SocialService(credentials: credentialStore()) { _, action, _, _ in
      actions.append(action); return action == "posts.tag" ? tagData : feed
    }
    let query = SocialTagQuery(tag: "study", community: .campus); let parent = UUID(); let child = UUID()
    service.retainTagQuery(query, owner: parent); service.retainTagQuery(query, owner: child)
    let response = try await service.perform("post.vote", payload: ["post_id": "older", "value": 1])
    XCTAssertEqual(actions, ["post.vote", "posts.tag"])
    XCTAssertEqual(response.snapshot?.posts, [recent]); XCTAssertEqual(response.tagPages?.first?.posts, [older])
    XCTAssertEqual(AppStore.mergePostSources(feed: response.snapshot!.posts, pages: response.tagPages!), [recent, older])
    service.releaseTagQuery(owner: child); actions = []
    _ = try await service.refresh(); XCTAssertEqual(actions, ["snapshot", "posts.tag"])
    service.releaseTagQuery(owner: parent); actions = []
    let unscoped = try await service.refresh(); XCTAssertEqual(actions, ["snapshot"]); XCTAssertTrue(unscoped.tagPages?.isEmpty == true)
  }
  func testUnavailableTagCannotUndoSuccessfulMutationOrRetainDeletedFallback() async throws {
    let recent = Post(id: "recent", author: "other", text: "New feed post", created: Date(timeIntervalSince1970: 1_000))
    let feed = try snapshot([recent])
    let service = SocialService(credentials: credentialStore()) { _, action, _, _ in
      if action == "posts.tag" { throw SocialServiceError(error: "This community is unavailable.", code: "forbidden") }
      return feed
    }
    let query = SocialTagQuery(tag: "study", community: .campus)
    service.retainTagQuery(query, owner: UUID())
    let response = try await service.perform("post.delete", payload: ["post_id": "old"])
    XCTAssertEqual(response.snapshot?.posts, [recent])
    XCTAssertNotNil(response.tagPages?.first?.error); XCTAssertTrue(response.tagPages?.first?.posts.isEmpty == true)
    XCTAssertEqual(AppStore.mergePostSources(feed: [recent], pages: response.tagPages!), [recent])
  }
  func testMostRecentCanonicalPageWinsOverlapAndFixtureMutationsStayVisible() async throws {
    let queryA = SocialTagQuery(tag: "study", community: .campus); let queryB = SocialTagQuery(tag: "campus", community: .campus)
    var older = Post(id: "one", author: "other", text: "Two tags"); older.tags = ["study", "campus"]
    var canonical = older; canonical.setVote(1)
    let pages = [SocialTagPage(query: queryB, posts: [canonical], loadedAt: Date(timeIntervalSince1970: 2)),
      SocialTagPage(query: queryA, posts: [older], loadedAt: Date(timeIntervalSince1970: 1))]
    XCTAssertEqual(AppStore.mergePostSources(feed: [older], pages: pages), [canonical])
    let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: file) }
    let store = AppStore(storageURL: file, arguments: []); store.enter(username: "tag_tester")
    store.state.posts = [older]
    let scope = store.openTagScope(queryA)
    await store.loadTagPage(queryA); XCTAssertEqual(store.posts(for: queryA), [older])
    store.vote(older.id, 1); XCTAssertEqual(store.posts(for: queryA), [canonical])
    store.state.hiddenPosts.insert(older.id); XCTAssertTrue(store.posts(for: queryA).isEmpty)
    withExtendedLifetime(scope) {}
  }
  func testOverlappingTagPageUsesCanonicalCardValuesAndCannotRestoreRemovedPost() throws {
    let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: file) }
    let store = AppStore(storageURL: file, arguments: [])
    let queryA = SocialTagQuery(tag: "study", community: .campus)
    let queryB = SocialTagQuery(tag: "campus", community: .campus)
    let scopeA = store.openTagScope(queryA); let scopeB = store.openTagScope(queryB)
    var stale = Post(id: "overlap", author: "Anonymous", text: "Two matching tags", created: Date(timeIntervalSince1970: 100))
    stale.tags = ["study", "campus"]
    var canonical = stale; canonical.saved = true; canonical.setVote(1)
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
    var response = try decoder.decode(SocialResponse.self, from: snapshot([]))
    response.tagPages = [
      SocialTagPage(query: queryA, posts: [stale], loadedAt: Date(timeIntervalSince1970: 1)),
      SocialTagPage(query: queryB, posts: [canonical], loadedAt: Date(timeIntervalSince1970: 2)),
    ]
    store.apply(response)
    XCTAssertFalse(store.tagPages[queryA]!.posts[0].saved, "The earlier page deliberately still contains the old bookmark value.")
    XCTAssertEqual(store.posts(for: queryA), [canonical])
    XCTAssertEqual(store.posts(for: queryB), [canonical])
    XCTAssertTrue(store.posts(for: queryA)[0].saved, "The visible button must agree with the canonical value used by toggleSave.")
    store.state.posts[0].deleted = true
    XCTAssertTrue(store.posts(for: queryA).isEmpty)
    store.state.posts = []
    XCTAssertTrue(store.posts(for: queryA).isEmpty, "Query membership must never resurrect a missing canonical post.")
    withExtendedLifetime((scopeA, scopeB)) {}
  }
}
