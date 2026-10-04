import XCTest
@testable import MaroonCore

final class CommentTests: XCTestCase {
  func testLegacyReplyDecodesWithRootAndZeroVotes() throws {
    let data = Data(#"{"id":"old","author":"Aggie abcd","text":"Old reply","anonymous":true,"created":100}"#.utf8)
    let reply = try JSONDecoder().decode(Comment.self, from: data)
    XCTAssertNil(reply.parentID)
    XCTAssertEqual(reply.score, 0)
    XCTAssertEqual(reply.vote, 0)
  }
  func testNestedReplyRoundTripKeepsParentAndVote() throws {
    var reply = Comment(author: "Aggie abcd", text: "Nested reply", parentID: "parent")
    reply.setVote(-1)
    let decoded = try JSONDecoder().decode(Comment.self, from: JSONEncoder().encode(reply))
    XCTAssertEqual(decoded, reply)
    XCTAssertEqual(decoded.parentID, "parent")
  }
  func testReplyVoteChangesAndRemovalUseNetDifference() {
    var reply = Comment(author: "Aggie abcd", text: "Reply")
    reply.score = 5
    reply.setVote(1)
    XCTAssertEqual(reply.score, 6)
    reply.setVote(-1)
    XCTAssertEqual(reply.score, 4)
    reply.setVote(-1)
    XCTAssertEqual(reply.score, 5)
    XCTAssertEqual(reply.vote, 0)
  }
}
