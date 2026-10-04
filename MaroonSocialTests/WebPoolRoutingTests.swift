import XCTest
@testable import MaroonSocial

@MainActor final class WebPoolRoutingTests: XCTestCase {
  private var credentials: SocialCredentialStore { .init(read: { String(repeating: "a", count: 64) }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {}) }
  private func response(_ rules: String, id: String = "match", version: Int = 0, status: String = "pending") -> Data {
    Data("""
    {"game":{"id":"\(id)","roomID":"room","kind":"pool","rules":"\(rules)","status":"\(status)","version":\(version),"yourSeat":1,"players":["RoomOne","RoomTwo"],"state":{"turn":0},"updatedAt":1000,"expiresAt":2000}}
    """.utf8)
  }
  func testNewPoolInvitationAndAcceptanceUseHostedEndpointWhileChessKeepsExistingEngine() async throws {
    var requests: [(String, String)] = []
    let social = SocialService(credentials: credentials) { endpoint, action, payload, _ in
      requests.append((endpoint, action))
      XCTAssertNil(payload["state"], "Only the server constructs a new physical table")
      return self.response(endpoint == "web-pool" ? "maroon-web-pool-3.0.0" : "maroon-games-2.2.0")
    }
    let service = GameService()
    let pool = try await service.invite(room: "room", kind: "pool", nonce: UUID().uuidString, using: social)
    XCTAssertTrue(pool.usesHostedPool); service.game = pool
    await service.act("accept", using: social)
    _ = try await service.invite(room: "room", kind: "chess", nonce: UUID().uuidString, using: social)
    XCTAssertEqual(requests.map(\.0), ["web-pool", "web-pool", "games"])
    XCTAssertEqual(requests.map(\.1), ["invite", "accept", "invite"])
  }
  func testHistoricalMatchFallsBackOnlyOnNotFoundAndRemembersItsOriginalEndpoint() async {
    var requests: [String] = []
    let social = SocialService(credentials: credentials) { endpoint, _, _, _ in
      requests.append(endpoint)
      if endpoint == "web-pool" { throw SocialServiceError(error: "Not a hosted match.", code: "not_found") }
      return self.response("maroon-games-2.1.0")
    }
    let service = GameService()
    await service.fetch("match", using: social); await service.fetch("match", using: social)
    XCTAssertEqual(requests, ["web-pool", "games", "games"])
    XCTAssertEqual(service.game?.rules, "maroon-games-2.1.0")
    XCTAssertFalse(service.game?.usesHostedPool ?? true)
  }
  func testAuthorizationFailureNeverFallsBackIntoAnotherGameEndpoint() async {
    var requests: [String] = []
    let social = SocialService(credentials: credentials) { endpoint, _, _, _ in
      requests.append(endpoint); throw SocialServiceError(error: "This conversation is closed.", code: "forbidden")
    }
    let service = GameService(); await service.fetch("match", using: social)
    XCTAssertEqual(requests, ["web-pool"]); XCTAssertNil(service.game)
    XCTAssertEqual(service.error, "This conversation is closed.")
  }
  func testSavedMatchListContainsBothEnginesInUpdateOrder() async {
    let social = SocialService(credentials: credentials) { endpoint, action, _, _ in
      XCTAssertEqual(action, "list")
      let rules = endpoint == "web-pool" ? "maroon-web-pool-3.0.0" : "maroon-games-2.1.0"
      let item = try JSONSerialization.jsonObject(with: self.response(rules, id: endpoint)) as! [String: Any]
      return try JSONSerialization.data(withJSONObject: ["games": [item["game"]!]])
    }
    let service = GameService(); await service.list(using: social)
    XCTAssertEqual(Set(service.games.map(\.id)), ["games", "web-pool"])
    XCTAssertEqual(service.games.filter(\.usesHostedPool).count, 1)
  }
}
