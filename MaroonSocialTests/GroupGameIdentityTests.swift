import MaroonCore
import XCTest
@testable import MaroonSocial

@MainActor final class GroupGameIdentityTests: XCTestCase {
  private let otherKey = "21111111-1111-4111-8111-111111111111"
  private let selfKey = "32222222-2222-4222-8222-222222222222"

  func testOpponentSelectionRequiresAcceptedScopedIdentityAndExplicitOtherMember() throws {
    // An alias can equal the current account's username. Ownership comes only
    // from isMe, while a legacy username with no scoped key is never selectable.
    let values: [[String: Any]] = [
      member(alias: "account_name", key: otherKey, mine: false),
      member(alias: "My room alias", key: selfKey, mine: true),
      member(alias: "Pending alias", key: UUID().uuidString, mine: false, status: "invited"),
      member(alias: "Removed alias", key: UUID().uuidString, mine: false, status: "declined"),
      member(alias: "Malformed key", key: "account_username", mine: false),
      member(alias: "Unknown ownership", key: UUID().uuidString, mine: nil),
      ["username": "legacy_account_name", "role": "member", "status": "accepted"],
      member(alias: "Duplicate identity", key: otherKey.lowercased(), mine: false)
    ]
    let decoded = try JSONDecoder().decode([SocialGroupMember].self, from: JSONSerialization.data(withJSONObject: values))
    let eligible = GroupGameOpponents.eligible(decoded)
    XCTAssertEqual(eligible.map(\.memberKey), [otherKey])
    XCTAssertEqual(eligible.map(\.username), ["account_name"])
  }

  func testGroupInvitationUsesScopedKeyAndRetainsNonceAfterLostAcknowledgement() async throws {
    let nonce = UUID().uuidString
    var sent: [[String: Any]] = []
    let service = SocialService(credentials: credentials) { endpoint, action, payload, _ in
      XCTAssertEqual(endpoint, "web-pool"); XCTAssertEqual(action, "invite")
      sent.append(payload)
      if sent.count == 1 { throw URLError(.timedOut) }
      return self.gameResponse
    }
    let games = GameService()
    do {
      _ = try await games.invite(room: "private-group", kind: "pool", nonce: nonce, opponentMemberKey: otherKey, using: service)
      XCTFail("The first response was lost")
    } catch { XCTAssertEqual((error as? URLError)?.code, .timedOut) }
    let game = try await games.invite(room: "private-group", kind: "pool", nonce: nonce, opponentMemberKey: otherKey, using: service)
    XCTAssertEqual(sent.count, 2)
    for payload in sent {
      XCTAssertEqual(Set(payload.keys), ["room", "kind", "nonce", "opponent_member_key"])
      XCTAssertEqual(payload["nonce"] as? String, nonce)
      XCTAssertEqual(payload["opponent_member_key"] as? String, otherKey)
      XCTAssertNil(payload["opponent_username"])
    }
    XCTAssertEqual(game.players, ["My room alias", "Other room alias"])
    XCTAssertEqual(game.opponent, "Other room alias")
    XCTAssertFalse(game.canAccept, "The inviter cannot accept on behalf of the selected member")
  }

  func testDirectInvitationDoesNotSendGroupKeyOrUsername() async throws {
    let service = SocialService(credentials: credentials) { endpoint, action, payload, _ in
      XCTAssertEqual(endpoint, "web-pool"); XCTAssertEqual(action, "invite")
      XCTAssertEqual(Set(payload.keys), ["room", "kind", "nonce"])
      return self.gameResponse
    }
    _ = try await GameService().invite(room: "direct-room", kind: "pool", nonce: UUID().uuidString, using: service)
  }

  func testMalformedScopedKeyCannotBecomeAccountUsernameLookup() async throws {
    var contactedServer = false
    let service = SocialService(credentials: credentials) { _, _, _, _ in
      contactedServer = true; return self.gameResponse
    }
    do {
      _ = try await GameService().invite(room: "private-group", kind: "pool", nonce: UUID().uuidString, opponentMemberKey: "real_account_name", using: service)
      XCTFail("An account username is not a room identity")
    } catch { XCTAssertEqual((error as? SocialServiceError)?.code, "invalid") }
    XCTAssertFalse(contactedServer)
  }

  func testInvitationAcceptanceMovesOneRequestIntoGroupUnreadAndRemovalClearsIt() throws {
    var chat = Conversation(id: "private-group", title: "Private group", request: true)
    let pendingJSON = #"{"id":"private-group","kind":"group","status":"active","role":"member","canSend":false,"unread":0,"lastRead":0,"pendingOutgoing":false,"typing":[],"members":[]}"#
    let pending = try JSONDecoder().decode(SocialConversationMeta.self, from: Data(pendingJSON.utf8))
    let requested = InboxCounts(conversations: [chat], metadata: [chat.id: pending])
    XCTAssertEqual(requested.requests, 1); XCTAssertEqual(requested.groups, 0)
    XCTAssertTrue(GroupGameOpponents.eligible(pending.members ?? []).isEmpty)

    var accepted = pending
    accepted.canSend = true; accepted.unread = 2
    accepted.members = try JSONDecoder().decode([SocialGroupMember].self, from: JSONSerialization.data(withJSONObject: [
      member(alias: "My room alias", key: selfKey, mine: true),
      member(alias: "Other room alias", key: otherKey, mine: false)
    ]))
    chat.request = false
    let joined = InboxCounts(conversations: [chat], metadata: [chat.id: accepted])
    XCTAssertEqual(joined.requests, 0); XCTAssertEqual(joined.groups, 2)
    XCTAssertEqual(GroupGameOpponents.eligible(accepted.members ?? []).map(\.memberKey), [otherKey])
    XCTAssertEqual(InboxCounts(conversations: [], metadata: [chat.id: accepted]).total, 0,
      "Stale metadata after membership removal cannot retain a badge")
  }

  private func member(alias: String, key: String, mine: Bool?, status: String = "accepted") -> [String: Any] {
    var result: [String: Any] = ["username": alias, "memberKey": key, "role": "member", "status": status, "avatar": "star"]
    if let mine { result["isMe"] = mine }
    return result
  }
  private var credentials: SocialCredentialStore {
    .init(read: { String(repeating: "a", count: 64) }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {})
  }
  private var gameResponse: Data {
    Data(#"{"game":{"id":"game","roomID":"private-group","kind":"pool","rules":"maroon-web-pool-3.0.0","status":"pending","version":0,"yourSeat":0,"players":["My room alias","Other room alias"],"state":{"turn":0},"updatedAt":1000,"expiresAt":2000}}"#.utf8)
  }
}
