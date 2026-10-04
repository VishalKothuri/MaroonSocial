import XCTest
import MaroonCore
@testable import MaroonSocial

@MainActor final class CommunityFeedTests: XCTestCase {
  private func response(community: Community, posts: [Post]) throws -> SocialResponse {
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
    let postJSON = try JSONSerialization.jsonObject(with: encoder.encode(posts))
    let data = try JSONSerialization.data(withJSONObject: ["snapshot": ["username": "cohort_tester", "feedCommunity": community.rawValue,
      "nsfwEnabled": false, "posts": postJSON, "courses": [], "activities": [], "conversations": [], "ownPostIDs": [],
      "ownCommentIDs": [], "ownMessageIDs": [], "conversationMeta": [], "attachments": [], "organizations": [], "savedEvents": []]])
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
    return try decoder.decode(SocialResponse.self, from: data)
  }
  func testLateOldCommunityResponseCannotReplaceSelectedFeed() async throws {
    let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: file) }
    let store = AppStore(storageURL: file, arguments: [])
    let campus = Post(id: "campus", author: "Anonymous", text: "Main campus")
    let freshmen = Post(id: "freshmen", author: "Anonymous", community: .freshmen, text: "Freshman chat")
    XCTAssertEqual(store.feedCommunity, .campus)
    store.apply(try response(community: .campus, posts: [campus]))
    await store.selectCommunity(.freshmen)
    store.apply(try response(community: .freshmen, posts: [freshmen]))
    store.apply(try response(community: .campus, posts: [campus]))
    XCTAssertEqual(store.feedPostIDs, [freshmen.id])
    XCTAssertEqual(store.state.posts.map(\.id), [freshmen.id])
    await store.selectCommunity(.campus)
    store.apply(try response(community: .campus, posts: [campus]))
    XCTAssertEqual(store.state.posts.map(\.id), [campus.id])
  }
  func testTransportScopesRefreshAndMutationsToSelectedCommunity() async throws {
    let credentials = SocialCredentialStore(read: { String(repeating: "a", count: 64) }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {})
    var received: [String] = []
    let service = SocialService(credentials: credentials) { endpoint, _, payload, _ in
      XCTAssertEqual(endpoint, "social")
      received.append(try XCTUnwrap(payload["feed_community"] as? String))
      return Data("{}".utf8)
    }
    _ = try await service.refresh()
    service.feedCommunity = .graduates
    _ = try await service.perform("post.vote", payload: ["post_id": "example", "value": 1])
    _ = try await service.refresh()
    XCTAssertEqual(received, ["Texas A&M", "Graduates", "Graduates"])
  }
}
