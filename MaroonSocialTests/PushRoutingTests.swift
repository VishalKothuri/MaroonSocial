import XCTest
@testable import MaroonSocial

final class PushRoutingTests: XCTestCase {
  private let reference = "c6c4637e-6d89-40dd-8078-c6bc48f9c655"
  func testDevicePayloadIsOnlyAHintWithKnownKindAndUUID() {
    XCTAssertNotNil(PushDestination(userInfo: ["maroon": ["kind": "game_turn", "reference": reference]]))
    XCTAssertNil(PushDestination(userInfo: ["maroon": ["kind": "open_url", "reference": reference]]))
    XCTAssertNil(PushDestination(userInfo: ["maroon": ["kind": "message", "reference": "https://untrusted.example"]]))
    XCTAssertNil(PushDestination(userInfo: ["room_id": "unverified-room"]))
  }
  func testResolvedGameOpensItsGameInsteadOfOnlyTheConversation() {
    let route = ResolvedPushRoute(kind: "game_turn", roomID: "accepted-room", postID: nil, gameID: reference)
    XCTAssertEqual(route.target, .game(reference))
    XCTAssertEqual(ResolvedPushRoute(kind: "game_invite", roomID: nil, postID: nil, gameID: reference).target, .game(reference))
  }
  func testActivityAndRoomRoutesRemainSeparateFromGameHints() {
    XCTAssertEqual(ResolvedPushRoute(kind: "activity", roomID: nil, postID: reference, gameID: nil).target, .post(reference))
    XCTAssertEqual(ResolvedPushRoute(kind: "message", roomID: "accepted-room", postID: nil, gameID: reference).target, .room("accepted-room"))
    XCTAssertNil(ResolvedPushRoute(kind: "game_turn", roomID: nil, postID: nil, gameID: "invalid").target)
    XCTAssertNil(ResolvedPushRoute(kind: "activity", roomID: nil, postID: "invalid", gameID: nil).target)
  }
}
