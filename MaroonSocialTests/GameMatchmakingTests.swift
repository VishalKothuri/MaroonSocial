import XCTest
@testable import MaroonSocial

@MainActor final class GameMatchmakingTests: XCTestCase {
  private var social: SocialService { SocialService() }
  func testSearchPollAndCancellationReuseNonceAndNeverRestart() async throws {
    var calls: [(String, String)] = []
    let service = GameMatchmakingService(kind: "pool") { action, payload in
      calls.append((action, payload["nonce"] as! String))
      return Data((action == "match.cancel" ? #"{"queue":{"status":"cancelled"}}"# : #"{"queue":{"status":"waiting"}}"#).utf8)
    }
    await service.find(using: social); XCTAssertTrue(service.searching)
    await service.find(using: social); XCTAssertEqual(calls.count, 1)
    await service.poll(using: social); await service.cancel(using: social)
    await service.poll(using: social)
    XCTAssertEqual(calls.map(\.0), ["match.join", "match.status", "match.cancel"])
    XCTAssertEqual(Set(calls.map(\.1)).count, 1); XCTAssertFalse(service.searching)
  }
  func testCancelledInFlightJoinCannotReopenLobby() async throws {
    var pending: CheckedContinuation<Data, Error>?
    let service = GameMatchmakingService(kind: "pong") { action, _ in
      if action == "match.join" { return try await withCheckedThrowingContinuation { pending = $0 } }
      return Data(#"{"queue":{"status":"cancelled"}}"#.utf8)
    }
    let task = Task { await service.find(using: social) }
    while pending == nil { await Task.yield() }
    await service.cancel(using: social)
    pending?.resume(returning: Data(#"{"queue":{"status":"waiting"}}"#.utf8))
    await task.value
    XCTAssertFalse(service.searching); XCTAssertNil(service.game); XCTAssertFalse(service.busy)
  }
  func testExpiredSearchStopsPollingAndNextSearchGetsNewNonce() async {
    var ids: [String] = []
    let service = GameMatchmakingService(kind: "chess") { action, payload in
      ids.append(payload["nonce"] as! String)
      return Data((action == "match.status" ? #"{"queue":{"status":"expired"}}"# : #"{"queue":{"status":"waiting"}}"#).utf8)
    }
    await service.find(using: social); await service.poll(using: social)
    XCTAssertFalse(service.searching); XCTAssertNotNil(service.error)
    await service.find(using: social)
    XCTAssertEqual(ids[0], ids[1]); XCTAssertNotEqual(ids[1], ids[2]); XCTAssertTrue(service.searching)
  }
  func testLostJoinAcknowledgementRetriesSameSearch() async {
    var ids: [String] = []
    let service = GameMatchmakingService(kind: "pool") { _, payload in
      ids.append(payload["nonce"] as! String)
      if ids.count == 1 { throw URLError(.networkConnectionLost) }
      return Data(#"{"queue":{"status":"waiting"}}"#.utf8)
    }
    await service.find(using: social)
    XCTAssertFalse(service.searching); XCTAssertNotNil(service.error)
    await service.find(using: social)
    XCTAssertEqual(ids.count, 2); XCTAssertEqual(ids[0], ids[1])
    XCTAssertTrue(service.searching); XCTAssertNil(service.error)
  }
  func testLateOldCancelCannotOverwriteNewSearchCancellation() async {
    var oldCancel: CheckedContinuation<Data, Error>?
    var cancelCount = 0
    let service = GameMatchmakingService(kind: "pool") { action, _ in
      if action == "match.cancel" {
        cancelCount += 1
        if cancelCount == 1 { return try await withCheckedThrowingContinuation { oldCancel = $0 } }
        return Data(#"{"queue":{"status":"cancelled"}}"#.utf8)
      }
      return Data(#"{"queue":{"status":"waiting"}}"#.utf8)
    }
    await service.find(using: social)
    let cancellation = Task { await service.cancel(using: social) }
    while oldCancel == nil { await Task.yield() }
    await service.find(using: social); await service.cancel(using: social)
    oldCancel?.resume(throwing: URLError(.timedOut)); await cancellation.value
    XCTAssertFalse(service.searching); XCTAssertNil(service.error)
  }
  func testSeatOneCannotControlSeatZeroAndFinishedMatchesNeverAllowInput() throws {
    let json = #"{"id":"id","roomID":"room","kind":"pool","rules":"maroon-games-2.1.0","status":"active","version":0,"yourSeat":1,"players":["Player 1","Player 2"],"state":{"turn":0},"updatedAt":0,"expiresAt":0}"#
    let game = try JSONDecoder().decode(OnlineGame.self, from: Data(json.utf8))
    XCTAssertFalse(game.yourTurn); XCTAssertEqual(game.detail, "Player 1’s turn")
    let own = try JSONDecoder().decode(OnlineGame.self, from: Data(json.replacingOccurrences(of: #""turn":0"#, with: #""turn":1"#).utf8))
    XCTAssertTrue(own.yourTurn)
    let ended = try JSONDecoder().decode(OnlineGame.self, from: Data(json.replacingOccurrences(of: #""status":"active""#, with: #""status":"finished""#).utf8))
    XCTAssertFalse(ended.yourTurn)
  }
}
