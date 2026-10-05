import Foundation
import XCTest
@testable import MaroonSocial

final class SourcePostTagTests: XCTestCase {
  private let base = #""id":"room","kind":"dm","status":"pending","role":"member","canSend":false,"unread":0,"lastRead":0,"pendingOutgoing":false,"typing":[],"members":[]"#
  private func decode(_ extra: String) throws -> SocialConversationMeta {
    try JSONDecoder().decode(SocialConversationMeta.self, from: Data("{\(base)\(extra)}".utf8))
  }
  func testSnapshotSourcePostDecodesPresentDeletedNullAndAbsent() throws {
    XCTAssertEqual(try decode(#","sourcePost":{"postID":"post-1","excerpt":"Study room tonight?","deleted":false,"fromReply":false}"#).sourcePost,
      SourcePostContext(postID: "post-1", excerpt: "Study room tonight?"))
    XCTAssertEqual(try decode(#","sourcePost":{"postID":"post-1","excerpt":null,"deleted":true,"fromReply":true}"#).sourcePost,
      SourcePostContext(postID: "post-1", excerpt: nil, deleted: true, fromReply: true))
    XCTAssertNil(try decode(#","sourcePost":null"#).sourcePost, "Username, organization, discovery and random rooms send null")
    XCTAssertNil(try decode("").sourcePost, "Older snapshots omit the key")
    XCTAssertEqual(try decode(#","sourcePost":{"postID":"post-2"}"#).sourcePost, SourcePostContext(postID: "post-2"), "Missing flags mean a live post")
  }
  func testSourcePostCarriesNoAuthorField() throws {
    let encoded = try JSONEncoder().encode(SourcePostContext(postID: "post-1", excerpt: "x"))
    let keys = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any]).keys
    XCTAssertEqual(Set(keys), ["postID", "excerpt", "deleted", "fromReply"])
  }
  func testLiveTagShowsTitleOneLineExcerptAndIsTappable() {
    let display = SourcePostTagText.display(SourcePostContext(postID: "p", excerpt: "  Line one\nline two   with   spaces \n"))
    XCTAssertEqual(display.title, "From this post")
    XCTAssertEqual(display.excerpt, "Line one line two with spaces")
    XCTAssertTrue(display.tappable)
    XCTAssertEqual(display.identifier, "sourcePostTag")
    XCTAssertEqual(display.accessibilityLabel, "From this post: Line one line two with spaces")
  }
  func testEmptyExcerptStillTagsALivePost() {
    for excerpt in [nil, "", " \n "] {
      let display = SourcePostTagText.display(SourcePostContext(postID: "p", excerpt: excerpt))
      XCTAssertEqual(display.excerpt, "…"); XCTAssertTrue(display.tappable); XCTAssertEqual(display.title, "From this post")
    }
  }
  func testDeletedTagShowsPlaceholderAndIsNotTappableEvenWithStaleExcerpt() {
    let display = SourcePostTagText.display(SourcePostContext(postID: "p", excerpt: "stale text", deleted: true))
    XCTAssertEqual(display.title, "From a post that was deleted")
    XCTAssertEqual(display.excerpt, "…")
    XCTAssertFalse(display.tappable)
    XCTAssertEqual(display.identifier, "sourcePostTagDeleted")
    XCTAssertEqual(display.accessibilityLabel, "From a post that was deleted")
  }
  func testReplyOriginKeepsTheSameTitleAndNamesTheReplyForAssistiveTechnology() {
    let display = SourcePostTagText.display(SourcePostContext(postID: "p", excerpt: "Hi", fromReply: true))
    XCTAssertEqual(display.title, "From this post")
    XCTAssertEqual(display.accessibilityLabel, "From this post, via a reply: Hi")
  }
  @MainActor func testFixtureInboxSeedsALiveTagAndADeletedPlaceholder() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = AppStore(storageURL: directory.appending(path: "state.json"), arguments: [])
    let request = try XCTUnwrap(store.conversationMeta["demo-request"]?.sourcePost)
    XCTAssertFalse(request.deleted)
    XCTAssertEqual(store.state.posts.first { $0.id == request.postID }?.text, request.excerpt, "The live tag opens a post that exists in the preview feed")
    let deleted = try XCTUnwrap(store.conversationMeta["demo-deleted-post-chat"]?.sourcePost)
    XCTAssertTrue(deleted.deleted); XCTAssertNil(deleted.excerpt)
    XCTAssertTrue(store.state.conversations.contains { $0.id == "demo-deleted-post-chat" && !$0.request })
    XCTAssertEqual(store.inboxCounts.requests, 1)
    XCTAssertEqual(store.inboxCounts.messages, 0, "Seeded metadata invents no unread badge")
  }
}
