import XCTest
@testable import MaroonCore

final class GroupMessageTests: XCTestCase {
  func testLegacyMessagesRemainDecodableWithoutGroupIdentity() throws {
    let message = Message(author: "Partner", text: "Hello")
    let decoded = try JSONDecoder().decode(Message.self, from: JSONEncoder().encode(message))
    XCTAssertNil(decoded.memberKey); XCTAssertNil(decoded.avatar)
    XCTAssertEqual(decoded, message)
  }
  func testGroupScopedMessageIdentitySurvivesCacheRoundTrip() throws {
    var message = Message(author: "NightOwl", text: "Ready to study")
    message.memberKey = "room-scoped-member"; message.avatar = "sage"
    let decoded = try JSONDecoder().decode(Message.self, from: JSONEncoder().encode(message))
    XCTAssertEqual(decoded, message)
    XCTAssertEqual(decoded.author, "NightOwl")
    XCTAssertEqual(decoded.memberKey, "room-scoped-member")
  }
}
