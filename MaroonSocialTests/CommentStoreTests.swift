import XCTest
import MaroonCore
@testable import MaroonSocial

@MainActor
final class CommentStoreTests: XCTestCase {
  private func store() throws -> (AppStore, URL) {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = AppStore(storageURL: directory.appending(path: "comments.json"), arguments: [])
    store.enter(username: "replytester")
    return (store, directory)
  }
  func testNestedFixtureReplyPersistsWithoutLosingParentOrAnonymity() async throws {
    let (store, directory) = try store()
    defer { try? FileManager.default.removeItem(at: directory) }
    let post = try XCTUnwrap(store.state.posts.first)
    let parent = try XCTUnwrap(post.comments.first)
    let created = await store.createComment(postID: post.id, text: "  Child reply  ", anonymous: false, parentID: parent.id)
    XCTAssertTrue(created)
    let child = try XCTUnwrap(store.state.posts[0].comments.last)
    XCTAssertEqual(child.parentID, parent.id)
    XCTAssertEqual(child.text, "Child reply")
    XCTAssertFalse(child.anonymous, "Members may reply by name under another member's anonymous post")
    XCTAssertTrue(store.owns(child))
    XCTAssertEqual(child.score, 1); XCTAssertEqual(child.vote, 1)
    store.voteComment(child.id, 1)
    XCTAssertEqual(store.state.posts[0].comments.last?.score, 0, "Tapping the starting upvote removes it")
    XCTAssertEqual(store.karma, 0, "Self-voting must not create karma.")
    let reloaded = AppStore(storageURL: directory.appending(path: "comments.json"), arguments: [])
    XCTAssertEqual(reloaded.state.posts[0].comments.last?.parentID, parent.id)
  }
  func testFixtureRejectsMissingCrossPostAndDeletedParent() async throws {
    let (store, directory) = try store()
    defer { try? FileManager.default.removeItem(at: directory) }
    let post = store.state.posts[0]
    let parent = try XCTUnwrap(post.comments.first)
    let missing = await store.createComment(postID: post.id, text: "No parent", anonymous: true, parentID: "missing")
    let crossPost = await store.createComment(postID: store.state.posts[1].id, text: "Wrong parent", anonymous: true, parentID: parent.id)
    XCTAssertFalse(missing)
    XCTAssertFalse(crossPost)
    store.state.posts[0].comments[0].deleted = true
    let deleted = await store.createComment(postID: post.id, text: "Deleted parent", anonymous: true, parentID: parent.id)
    XCTAssertFalse(deleted)
    XCTAssertEqual(store.state.posts[0].comments.count, 1)
  }
  func testFixtureReplyVotingUsesNetDifferenceAndCountsOwnPost() throws {
    let (store, directory) = try store()
    defer { try? FileManager.default.removeItem(at: directory) }
    let comment = try XCTUnwrap(store.state.posts[0].comments.first)
    store.voteComment(comment.id, 1)
    XCTAssertEqual(store.state.posts[0].comments[0].score, 1)
    store.voteComment(comment.id, -1)
    XCTAssertEqual(store.state.posts[0].comments[0].score, -1)
    store.voteComment(comment.id, -1)
    XCTAssertEqual(store.state.posts[0].comments[0].score, 0)
    let own = Post(author: store.state.username, text: "Own post")
    store.state.posts.append(own)
    store.vote(own.id, 1)
    XCTAssertEqual(store.state.posts.last?.score, 1, "Authors vote on their own posts like anyone else")
    store.vote(own.id, 1)
    XCTAssertEqual(store.state.posts.last?.score, 0, "Tapping the active vote again removes it")
  }
  func testNewPostsAndRepliesStartWithTheAuthorsUpvote() async throws {
    let (store, directory) = try store()
    defer { try? FileManager.default.removeItem(at: directory) }
    let posted = await store.createPost(text: "Fresh post", anonymous: true, community: .campus, acceptsDM: true); XCTAssertTrue(posted)
    let post = try XCTUnwrap(store.state.posts.first { $0.text == "Fresh post" })
    XCTAssertEqual(post.score, 1); XCTAssertEqual(post.vote, 1)
    let replied = await store.createComment(postID: post.id, text: "Fresh reply", anonymous: false); XCTAssertTrue(replied)
    let reply = try XCTUnwrap(store.state.posts.first { $0.id == post.id }?.comments.last)
    XCTAssertEqual(reply.score, 1); XCTAssertEqual(reply.vote, 1)
    XCTAssertTrue(reply.anonymous, "The author of an anonymous post stays anonymous in its own thread")
  }
  func testOthersMayReplyNamedUnderAnAnonymousPost() async throws {
    let (store, directory) = try store()
    defer { try? FileManager.default.removeItem(at: directory) }
    let post = try XCTUnwrap(store.state.posts.first { $0.anonymous && $0.author != store.state.username })
    let replied = await store.createComment(postID: post.id, text: "Named reply", anonymous: false); XCTAssertTrue(replied)
    let reply = try XCTUnwrap(store.state.posts.first { $0.id == post.id }?.comments.last)
    XCTAssertFalse(reply.anonymous)
    XCTAssertEqual(reply.author, store.state.username)
  }
}
