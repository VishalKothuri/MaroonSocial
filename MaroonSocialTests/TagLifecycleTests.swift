import XCTest
@testable import MaroonSocial

@MainActor final class TagLifecycleTests: XCTestCase {
  func testRestoreUsesOnePollAndRequiresFreshConsent() async {
    var requests: [String] = []
    let service = TagService { action, _ in
      requests.append(action)
      return self.snapshot(state: "seeking")
    }
    await service.restoreSession()
    XCTAssertEqual(requests, ["poll"])
    XCTAssertTrue(service.hasSession)
    XCTAssertTrue(service.needsResume)
    XCTAssertFalse(service.location.running)
    XCTAssertNil(service.consentLobby)
    await service.activate()
    XCTAssertEqual(requests, ["poll"], "Restoration already activated foreground state polling")
    service.deactivate()
  }

  func testEmptyRestoreDoesNotPreventLaterOpeningTag() async {
    var polls = 0
    let service = TagService { _, _ in
      polls += 1
      return Data("{\"state\":\"idle\",\"server_time\":1000}".utf8)
    }
    await service.restoreSession()
    XCTAssertFalse(service.hasSession)
    await service.activate()
    XCTAssertEqual(polls, 2, "An idle launch check must not leave the service active")
    service.deactivate()
  }

  func testBackgroundPausesLateCreationAndForegroundDoesNotRecapture() async {
    let sent = expectation(description: "creation in flight")
    let paused = expectation(description: "server pause acknowledges created lobby")
    var release: CheckedContinuation<Data, Never>?
    var requests: [String] = []
    var serverPaused = false
    let service = TagService { action, payload in
      requests.append(action)
      if action == "create" { return await withCheckedContinuation { release = $0; sent.fulfill() } }
      if action == "pause" {
        XCTAssertEqual(payload["lobby"] as? String, "match")
        serverPaused = true; paused.fulfill()
      }
      return serverPaused ? self.snapshot(state: "hiding", paused: 1_000) : Data("{\"state\":\"idle\",\"server_time\":1000}".utf8)
    }
    await service.activate()
    let create = Task { await service.create(title: "Test", area: "Synthetic area", duration: 5, hiding: 30, capacity: 2, radius: 150) }
    await fulfillment(of: [sent], timeout: 2)
    service.background()
    release?.resume(returning: snapshot(state: "lobby"))
    await create.value
    await fulfillment(of: [paused], timeout: 2)
    await service.activate()
    XCTAssertEqual(service.lobby?.id, "match")
    XCTAssertTrue(service.needsResume)
    XCTAssertFalse(service.sharing)
    XCTAssertFalse(service.location.running)
    XCTAssertFalse(requests.contains("leave"), "Backgrounding retains the match while removing its location")
    XCTAssertNotNil(service.pauseCountdown)
    service.deactivate()
  }

  func testResumeFailureKeepsSensorsOffAndRematchLostReplyRetainsNonce() async {
    var nonces: [String] = []
    let service = TagService { action, payload in
      if action == "resume" { throw URLError(.notConnectedToInternet) }
      if action == "rematch" {
        nonces.append(payload["nonce"] as? String ?? "")
        if nonces.count == 1 { throw URLError(.timedOut) }
        return self.snapshot(state: "lobby", id: "fresh-match")
      }
      return self.snapshot(state: "seeking", paused: 1_000)
    }
    await service.activate()
    await service.resume()
    XCTAssertNil(service.consentLobby)
    XCTAssertFalse(service.location.running)
    XCTAssertNotNil(service.error)
    await service.rematch()
    await service.rematch()
    XCTAssertEqual(nonces.count, 2)
    XCTAssertFalse(nonces[0].isEmpty)
    XCTAssertEqual(nonces[0], nonces[1])
    XCTAssertEqual(service.lobby?.id, "fresh-match")
    XCTAssertFalse(service.sharing)
    XCTAssertNil(service.consentLobby)
    service.deactivate()
  }

  func testCompletedResultsDecodeCountsWithoutLocationAndSafeDurationCopy() throws {
    let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
    let data = Data("""
      {"duration_seconds":120,"total_catches":1,"players":[
       {"id":"s","username":"seeker","role":"seeker","caught":false,"left":false,"catches":1,"survived_seconds":null},
       {"id":"h","username":"hider","role":"hider","caught":true,"left":false,"catches":0,"survived_seconds":65}]}
      """.utf8)
    let result = try decoder.decode(TagResults.self, from: data)
    XCTAssertEqual(result.totalCatches, 1)
    XCTAssertEqual(result.players[0].summary, "1 confirmed catch")
    XCTAssertEqual(result.players[1].summary, "Caught after 1m 5s")
    let invalidDuration = TagResultPlayer(id: "h", username: "hider", role: "hider", caught: false, left: true, catches: 0, survivedSeconds: -5)
    XCTAssertEqual(invalidDuration.summary, "Left after 0m 0s")
  }

  private func snapshot(state: String, id: String = "match", paused: Int? = nil) -> Data {
    Data("""
      {"state":"\(state)","server_time":1000,
       "lobby":{"id":"\(id)","code":"AABBCCDD","title":"Synthetic match","area":"Synthetic area","capacity":2,"duration_seconds":300,"hide_seconds":30,"radius_m":150,"host":true,"expires_at":2000},
       "me":{"id":"self","role":"seeker","ready":false,"consented":false,"caught":false,"outside":false,"location_fresh":false,"paused_at":\(paused.map(String.init) ?? "null")},
       "players":[],"hints":[],"catches":[],"messages":[],"next_hint_at":1030}
      """.utf8)
  }
}
