import XCTest
import MaroonCore
@testable import MaroonSocial

@MainActor final class PostFeatureStoreTests: XCTestCase {
  func testPollLinkTagsAndMediaPersistWithAuthorVotingAndChangingAnswer() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appending(path: "posts.json")
    let store = AppStore(storageURL: file, arguments: []); store.enter(username: "poll_tester")
    let media = MediaAttachment(kind: .image, data: Data([1, 2, 3]))
    let created = await store.createPost(text: "", anonymous: true, community: .campus, acceptsDM: true, media: media,
      poll: .init(question: "Where should we study?", options: ["Library", "Coffee"]), linkURL: "tamu.edu", tags: ["#Study", "CAMPUS"])
    XCTAssertTrue(created)
    let post = try XCTUnwrap(store.state.posts.first); let poll = try XCTUnwrap(post.poll)
    XCTAssertEqual(post.media, media); XCTAssertEqual(post.tags, ["study", "campus"]); XCTAssertEqual(post.linkURL, "https://tamu.edu")
    XCTAssertTrue(store.owns(post))
    let first = await store.votePoll(postID: post.id, optionID: poll.options[0].id)
    let second = await store.votePoll(postID: post.id, optionID: poll.options[1].id)
    XCTAssertTrue(first); XCTAssertTrue(second)
    XCTAssertEqual(store.state.posts[0].poll?.totalVotes, 1)
    XCTAssertEqual(store.state.posts[0].poll?.options.map(\.votes), [0, 1])
    let restored = AppStore(storageURL: file, arguments: [])
    XCTAssertEqual(restored.state.posts[0], store.state.posts[0])
  }
  func testInvalidExpiredAndFailedPersistenceLeavePostsAndVotesUnchanged() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = AppStore(storageURL: directory.appending(path: "posts.json"), arguments: [])
    store.enter(username: "poll_tester")
    let initial = store.state.posts
    let invalid = await store.createPost(text: "", anonymous: true, community: .campus, acceptsDM: false, tags: ["campus"])
    XCTAssertFalse(invalid); XCTAssertEqual(store.state.posts, initial)
    var post = Post(author: "poll_tester", text: "")
    post.poll = PostPoll(question: "Where?", options: [.init(id: "a", text: "A"), .init(id: "b", text: "B")], endsAt: .now.addingTimeInterval(-1))
    store.state.posts.insert(post, at: 0)
    let expired = await store.votePoll(postID: post.id, optionID: "a"); XCTAssertFalse(expired)
    store.state.posts[0].poll?.endsAt = .now.addingTimeInterval(3600)
    let before = store.state.posts
    try FileManager.default.removeItem(at: directory)
    let failedVote = await store.votePoll(postID: post.id, optionID: "a"); XCTAssertFalse(failedVote)
    XCTAssertEqual(store.state.posts, before)
    let failedPost = await store.createPost(text: "", anonymous: true, community: .campus, acceptsDM: false, linkURL: "tamu.edu")
    XCTAssertFalse(failedPost); XCTAssertEqual(store.state.posts, before)
  }
}
