import XCTest
@testable import MaroonSocial

@MainActor final class GroupFormRulesTests: XCTestCase {
  func testAccountInvitesNormalizeDeduplicateAndRespectAccountBounds() throws {
    XCTAssertEqual(try GroupFormRules.usernames(" @Aggie_One, aggie_two\nAGGIE_ONE "), ["aggie_one", "aggie_two"])
    XCTAssertEqual(try GroupFormRules.usernames(""), [])
    XCTAssertEqual(try GroupFormRules.usernames(String(repeating: "a", count: 20)).count, 1)
    for input in ["ab", String(repeating: "a", count: 21), "with-dash", "two@signs", "@@aggie", "café", "🙂🙂🙂"] {
      XCTAssertThrowsError(try GroupFormRules.usernames(input), input)
    }
    let twenty = (0..<20).map { "aggie_\($0)" }.joined(separator: ",")
    XCTAssertEqual(try GroupFormRules.usernames(twenty + ",AGGIE_0").count, 20)
    XCTAssertThrowsError(try GroupFormRules.usernames(twenty + ",one_more"))
  }
  func testRoomAliasesUseTheirOwnASCII24CharacterLimit() {
    for alias in ["owl", " Maroon_Fox ", String(repeating: "a", count: 24)] { XCTAssertTrue(GroupFormRules.validAlias(alias), alias) }
    for alias in ["", "  ", "ab", String(repeating: "a", count: 25), "café", "two words", "@owl", "fox-dog"] { XCTAssertFalse(GroupFormRules.validAlias(alias), alias) }
    XCTAssertFalse((try? GroupFormRules.usernames(String(repeating: "a", count: 24))) != nil, "A valid 24-character room alias is not necessarily a valid account username.")
  }
  func testAliasRosterAndOwnerPendingInvitesDecodeSeparatelyAndClearWhenOwnershipChanges() async throws {
    var owner = true, joined = true
    let service = CommunitiesService { _, _ in
      try JSONSerialization.data(withJSONObject: [
        "community": ["id": "room", "title": "Study group", "description": "A campus study group", "category": "Study Group", "capacity": 200,
          "member_count": 1, "joined": joined, "owner": owner, "closed": false, "is_public": false, "created_at": 1000,
          "avatar": "sage", "my_alias": "NightOwl", "my_avatar": "gold", "invited": false],
        "members": [["alias": "NightOwl", "member_key": "scoped-member", "avatar": "gold", "is_me": true, "role": "owner"]],
        "pending": [["username": "invited_account", "invitation_key": "scoped-invitation"]], "bans": []])
    }
    _ = await service.act("detail", ["room_id": "room"])
    XCTAssertEqual(service.community?.myAlias, "NightOwl")
    XCTAssertEqual(service.members.first?.displayName, "NightOwl")
    XCTAssertEqual(service.members.first?.username, "", "An account username is not required to display a group member.")
    XCTAssertEqual(service.members.first?.id, "scoped-member")
    XCTAssertEqual(service.pending.first?.id, "scoped-invitation")
    owner = false
    _ = await service.act("detail", ["room_id": "room"])
    XCTAssertTrue(service.pending.isEmpty); XCTAssertEqual(service.members.count, 1)
    joined = false
    _ = await service.act("detail", ["room_id": "room"])
    XCTAssertTrue(service.members.isEmpty); XCTAssertTrue(service.pending.isEmpty)
  }
  func testAcceptSendsChosenRoomIdentityWithoutAnAccountUsername() async {
    var captured: [String: Any] = [:]
    let service = CommunitiesService { action, payload in
      XCTAssertEqual(action, "accept"); captured = payload
      return Data(#"{"room_id":"invited-room"}"#.utf8)
    }
    let id = await service.act("accept", ["room_id": "invited-room", "alias": "IndependentOwl", "member_avatar": "sage"])
    XCTAssertEqual(id, "invited-room")
    XCTAssertEqual(captured["alias"] as? String, "IndependentOwl")
    XCTAssertEqual(captured["member_avatar"] as? String, "sage")
    XCTAssertNil(captured["username"])
  }
}
