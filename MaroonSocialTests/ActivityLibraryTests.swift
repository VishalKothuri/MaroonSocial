import XCTest
import MaroonCore
@testable import MaroonSocial

@MainActor final class ActivityLibraryTests: XCTestCase {
  private func credentials() -> SocialCredentialStore {
    SocialCredentialStore(read: { String(repeating: "a", count: 64) }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {})
  }
  private func snapshot(_ posts: [Post]) throws -> Data {
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
    let encoded = try JSONSerialization.jsonObject(with: encoder.encode(posts))
    return try JSONSerialization.data(withJSONObject: ["snapshot": ["username": "library_tester", "nsfwEnabled": false,
      "posts": encoded, "courses": [], "activities": [], "conversations": [], "ownPostIDs": [],
      "ownCommentIDs": [], "ownMessageIDs": [], "conversationMeta": [], "attachments": [], "organizations": [], "savedEvents": []]])
  }
  func testLibraryScopesRefreshEveryLoadedPageOnceAfterMutation() async throws {
    // Exactly representable fractional dates keep full Post equality meaningful across JSON round trips.
    let recent = Post(id: "recent", author: "other", text: "Feed", created: Date(timeIntervalSince1970: 1_700_000_000.25))
    let old = Post(id: "old", author: "library_tester", text: "Older collection post", created: Date(timeIntervalSince1970: 1_699_000_000.5))
    let feed = try snapshot([recent])
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
    let documents = try JSONSerialization.jsonObject(with: encoder.encode([old]))
    let payload = try JSONSerialization.data(withJSONObject: ["posts": documents, "comments": [], "hasMore": false])
    var requests: [String] = []
    let service = SocialService(credentials: credentials()) { _, action, input, _ in
      requests.append(action == "library" ? "library:\(input["offset"] as? Int ?? -1)" : action)
      return action == "library" ? payload : feed
    }
    let first = SocialLibraryQuery(kind: .posts)
    let next = SocialLibraryQuery(kind: .posts, offset: 50)
    let owners = [UUID(), UUID(), UUID()]
    service.retainLibraryQuery(first, owner: owners[0]); service.retainLibraryQuery(first, owner: owners[1]); service.retainLibraryQuery(next, owner: owners[2])
    let result = try await service.perform("post.vote", payload: ["post_id": "old", "value": 1])
    XCTAssertEqual(requests, ["post.vote", "library:0", "library:50"])
    XCTAssertEqual(result.snapshot?.posts, [recent]); XCTAssertEqual(result.libraryPages?.count, 2)
    XCTAssertEqual(result.libraryPages?.first?.posts, [old])
    owners.forEach { service.releaseLibraryQuery(owner: $0) }
    requests = []; _ = try await service.refresh(); XCTAssertEqual(requests, ["snapshot"])
  }
  func testCollectionFailureCannotUndoSuccessfulPostMutationOrKeepBlockedPost() async throws {
    let feed = try snapshot([])
    let service = SocialService(credentials: credentials()) { _, action, _, _ in
      if action == "library" { throw SocialServiceError(error: "Post unavailable", code: "forbidden") }
      return feed
    }
    let query = SocialLibraryQuery(kind: .post, postID: "blocked")
    service.retainLibraryQuery(query, owner: UUID())
    let result = try await service.perform("block", payload: [:])
    XCTAssertNotNil(result.snapshot)
    XCTAssertEqual(result.libraryPages?.first?.posts, [])
    XCTAssertNotNil(result.libraryPages?.first?.error)
  }
  func testLibraryPostsRemainOutsideFeedAndFollowRefreshedValues() throws {
    let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: file) }
    let store = AppStore(storageURL: file, arguments: [])
    let query = SocialLibraryQuery(kind: .saved)
    let scope = store.openLibraryScope(query)
    let recent = Post(id: "recent", author: "other", text: "Current feed", created: Date(timeIntervalSince1970: 1_700_000_000.25))
    var old = Post(id: "old", author: "other", text: "Older saved post", created: Date(timeIntervalSince1970: 1_699_000_000.5)); old.saved = true
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
    var result = try decoder.decode(SocialResponse.self, from: snapshot([recent]))
    result.libraryPages = [SocialLibraryPage(query: query, posts: [old])]
    store.apply(result)
    XCTAssertEqual(store.feedPostIDs, ["recent"])
    XCTAssertEqual(store.libraryPosts([query]), [old])
    old.setVote(1); result.libraryPages = [SocialLibraryPage(query: query, posts: [old])]
    store.apply(result); XCTAssertEqual(store.libraryPosts([query]).first?.score, 1)
    result.libraryPages = [SocialLibraryPage(query: query, error: "Blocked")]
    store.apply(result); XCTAssertEqual(store.state.posts, [recent]); XCTAssertTrue(store.libraryPosts([query]).isEmpty)
    withExtendedLifetime(scope) {}
  }
  func testUsernameNormalizationAndValidation() {
    XCTAssertEqual(AccountUsernameRules.normalized("  Aggie_26 \n"), "aggie_26")
    XCTAssertTrue(AccountUsernameRules.valid(" Aggie_26 "))
    XCTAssertFalse(AccountUsernameRules.valid("ab"))
    XCTAssertFalse(AccountUsernameRules.valid("name with spaces"))
    XCTAssertFalse(AccountUsernameRules.valid("name😀"))
    XCTAssertFalse(AccountUsernameRules.valid(String(repeating: "a", count: 21)))
  }
}

@MainActor final class NotificationsServiceTests: XCTestCase {
  private func credentials() -> SocialCredentialStore {
    SocialCredentialStore(read: { String(repeating: "a", count: 64) }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {})
  }
  private var inbox: Data {
    Data("""
    {"items":[{"id":"one","kind":"comment","title":"New comment","body":"Reply","postID":"post","created":100,"read":false},{"id":"two","kind":"announcement","title":"Announcement","body":"Owner update","created":200,"read":false}],"unreadCount":2}
    """.utf8)
  }
  func testAcknowledgementSendsOnlyDisplayedIDsAndPreservesAnnouncementKind() async throws {
    let payload = inbox
    var acknowledged: [String] = []
    let service = SocialService(credentials: credentials()) { _, action, input, _ in
      if action == "notifications" { return payload }
      XCTAssertEqual(action, "notifications.read_all"); acknowledged = input["ids"] as? [String] ?? []
      return Data("{\"read\":true}".utf8)
    }
    let model = NotificationsModel(); await model.refresh(using: service)
    XCTAssertEqual(model.items.last?.kind, .announcement); XCTAssertNil(model.items.last?.postID)
    XCTAssertEqual(model.items.first?.created, Date(timeIntervalSince1970: 100))
    await model.markAllRead(using: service)
    XCTAssertEqual(acknowledged, ["one", "two"]); XCTAssertEqual(model.unreadCount, 0); XCTAssertTrue(model.items.allSatisfy(\.read))
  }
  func testDelayedRefreshCannotUndoAReadAcknowledgement() async throws {
    let payload = inbox
    var reads = 0
    var delayed: CheckedContinuation<Data, Error>?
    let service = SocialService(credentials: credentials()) { _, action, _, _ in
      if action != "notifications" { return Data("{\"read\":true}".utf8) }
      reads += 1
      if reads == 1 { return payload }
      return try await withCheckedThrowingContinuation { delayed = $0 }
    }
    let model = NotificationsModel(); await model.refresh(using: service)
    let refresh = Task { await model.refresh(using: service) }
    while delayed == nil { await Task.yield() }
    let read = await model.markRead(model.items[0], using: service)
    XCTAssertTrue(read); XCTAssertEqual(model.unreadCount, 1)
    delayed?.resume(returning: payload); await refresh.value
    XCTAssertTrue(model.items[0].read); XCTAssertEqual(model.unreadCount, 1)
  }
  func testConcurrentReadTapsAreNotDropped() async throws {
    let payload = inbox
    var calls: [String] = []
    let service = SocialService(credentials: credentials()) { _, action, input, _ in
      if action == "notifications" { return payload }
      calls.append(input["id"] as? String ?? "")
      await Task.yield()
      return Data("{\"read\":true}".utf8)
    }
    let model = NotificationsModel(); await model.refresh(using: service)
    let firstItem = model.items[0]; let secondItem = model.items[1]
    async let first = model.markRead(firstItem, using: service)
    async let second = model.markRead(secondItem, using: service)
    let result = await (first, second)
    XCTAssertTrue(result.0); XCTAssertTrue(result.1); XCTAssertEqual(Set(calls), ["one", "two"])
    XCTAssertEqual(model.unreadCount, 0); XCTAssertFalse(model.updating)
  }
  func testResetDiscardsAnEarlierAccountsInflightInbox() async throws {
    let payload = inbox
    var delayed: CheckedContinuation<Data, Error>?
    let service = SocialService(credentials: credentials()) { _, _, _, _ in try await withCheckedThrowingContinuation { delayed = $0 } }
    let model = NotificationsModel()
    let refresh = Task { await model.refresh(using: service) }
    while delayed == nil { await Task.yield() }
    model.reset(); delayed?.resume(returning: payload); await refresh.value
    XCTAssertTrue(model.items.isEmpty); XCTAssertEqual(model.unreadCount, 0); XCTAssertFalse(model.loading)
  }
  func testFailedReadLeavesNotificationUnreadForRetry() async {
    let payload = inbox
    let service = SocialService(credentials: credentials()) { _, action, _, _ in
      if action == "notifications" { return payload }
      throw URLError(.notConnectedToInternet)
    }
    let model = NotificationsModel(); await model.refresh(using: service)
    let result = await model.markRead(model.items[0], using: service)
    XCTAssertFalse(result); XCTAssertFalse(model.items[0].read); XCTAssertEqual(model.unreadCount, 2); XCTAssertNotNil(model.error)
  }
}
