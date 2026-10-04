import XCTest
@testable import MaroonSocial

@MainActor final class DiscoveryServiceTests: XCTestCase {
  private func response(_ state: String, room: Bool = false, media: Bool = false) -> Data {
    let session: [String: Any]? = ["connecting", "connected"].contains(state) ? ["id": "11111111-1111-4111-8111-111111111111", "room": room ? "22222222-2222-4222-8222-222222222222" : NSNull(), "peer": ["username": "PeerName", "tags": ["music"]], "initiator": true, "ends_at": 2000000000] : nil
    var value: [String: Any] = ["state": state, "profile": ["username": "MyName", "tags": ["music"]], "people": [], "incoming": [], "messages": [], "signals": [], "media_transport": "direct", "session": session as Any? ?? NSNull()]
    if media { value["ice_servers"] = [["urls": ["stun:stun.example.invalid:3478"]]] }
    return try! JSONSerialization.data(withJSONObject: value)
  }
  func testEnteringWaitingNeverStartsCaptureOrRequestsMedia() async {
    var actions: [String] = []
    let service = DiscoveryService { action, _ in actions.append(action); return self.response(action == "enter" ? "waiting" : "idle") }
    await service.activate(); await service.enter(allowDirect: true)
    XCTAssertEqual(service.state, "waiting"); XCTAssertFalse(service.canCapture)
    XCTAssertEqual(actions, ["heartbeat", "enter"]); service.deactivate()
  }
  func testBothForegroundConfirmationPrecedesMedia() async {
    var incoming = false; var actions: [String] = []
    let service = DiscoveryService { action, _ in
      actions.append(action)
      if action == "ack" { return self.response("connected", room: true) }
      if action == "media" { return self.response("connected", room: true, media: true) }
      return self.response(incoming ? "connecting" : action == "enter" ? "waiting" : "idle")
    }
    await service.activate(); await service.enter(allowDirect: true); incoming = true
    await service.refresh()
    XCTAssertTrue(service.canCapture); XCTAssertEqual(Array(actions.suffix(3)), ["heartbeat", "ack", "media"])
    service.deactivate(); XCTAssertFalse(service.canCapture); XCTAssertTrue(service.iceServers.isEmpty)
  }
  func testLateMediaCannotRestoreCameraAfterBackground() async {
    var incoming = false; var continuation: CheckedContinuation<Data, Never>?
    let service = DiscoveryService { action, _ in
      if action == "ack" { return self.response("connected", room: true) }
      if action == "media" { return await withCheckedContinuation { continuation = $0 } }
      return self.response(incoming ? "connecting" : action == "enter" ? "waiting" : "idle")
    }
    await service.activate(); await service.enter(allowDirect: true); incoming = true
    let refresh = Task { await service.refresh() }
    for _ in 0..<50 where continuation == nil { await Task.yield() }
    XCTAssertNotNil(continuation); service.deactivate()
    continuation?.resume(returning: response("connected", room: true, media: true)); await refresh.value
    XCTAssertFalse(service.canCapture); XCTAssertEqual(service.state, "idle"); XCTAssertTrue(service.iceServers.isEmpty)
  }
  func testExpiredHandshakeNeverFetchesMedia() async {
    var incoming = false; var actions: [String] = []
    let service = DiscoveryService { action, _ in
      actions.append(action)
      if action == "ack" { throw SocialServiceError(error: "The other person left.", code: "ended") }
      return self.response(incoming ? "connecting" : action == "enter" ? "waiting" : "idle")
    }
    await service.activate(); await service.enter(allowDirect: true); incoming = true; await service.refresh()
    XCTAssertFalse(service.canCapture); XCTAssertFalse(actions.contains("media")); XCTAssertEqual(service.state, "idle"); service.deactivate()
  }
  func testQueuedSignalIsNeverDispatchedAfterBackground() async {
    var joined = false, holdHeartbeat = false
    var held: CheckedContinuation<Data, Never>?
    var actions: [String] = []
    let service = DiscoveryService { action, _ in
      actions.append(action)
      if action == "heartbeat", holdHeartbeat { return await withCheckedContinuation { held = $0 } }
      if action == "ack" { return self.response("connected", room: true) }
      if action == "media" { return self.response("connected", room: true, media: true) }
      return self.response(joined ? "connecting" : "idle")
    }
    await service.activate(); await service.enter(allowDirect: true); joined = true; await service.refresh()
    XCTAssertTrue(service.canCapture)
    holdHeartbeat = true
    let heartbeat = Task { await service.refresh() }
    for _ in 0..<50 where held == nil { await Task.yield() }
    XCTAssertNotNil(held)
    let signal = Task { await service.signal(kind: "ice", payloadJSON: "{\"candidate\":\"fixture\"}") }
    for _ in 0..<10 { await Task.yield() }
    service.deactivate()
    held?.resume(returning: response("connected", room: true)); await heartbeat.value; await signal.value
    for _ in 0..<20 where !actions.contains("leave") { await Task.yield() }
    XCTAssertFalse(actions.contains("signal")); XCTAssertTrue(actions.contains("leave")); XCTAssertFalse(service.canCapture)
  }
  func testFailedProfileSaveCannotEnterUsingPreviouslySavedIdentity() async {
    var actions: [String] = []
    let service = DiscoveryService { action, _ in
      actions.append(action)
      if action == "profile" { throw SocialServiceError(error: "Name unavailable.", code: "conflict") }
      return self.response("idle")
    }
    await service.activate()
    await service.saveAndEnter(username: "ChangedName", tags: ["art"], allowDirect: true)
    XCTAssertEqual(actions, ["heartbeat", "profile"]); XCTAssertEqual(service.profile?.username, "MyName")
    XCTAssertFalse(service.canCapture); service.deactivate()
  }
  func testQueuedEnterCannotDispatchAfterLeavingDuringHeartbeat() async {
    var hold = false; var held: CheckedContinuation<Data, Never>?; var actions: [String] = []
    let service = DiscoveryService { action, _ in
      actions.append(action)
      if action == "heartbeat", hold { return await withCheckedContinuation { held = $0 } }
      return self.response("idle")
    }
    await service.activate(); hold = true
    let heartbeat = Task { await service.refresh() }
    for _ in 0..<50 where held == nil { await Task.yield() }
    let enter = Task { await service.enter(allowDirect: true) }
    for _ in 0..<10 { await Task.yield() }
    service.deactivate(); held?.resume(returning: response("idle"))
    await heartbeat.value; await enter.value
    XCTAssertFalse(actions.contains("enter")); XCTAssertEqual(service.state, "idle")
  }

  func testSavedProfileTagOrderDoesNotBlockEntering() async {
    var actions: [String] = []
    let service = DiscoveryService { action, _ in
      actions.append(action)
      return try! JSONSerialization.data(withJSONObject: ["state": action == "enter" ? "waiting" : "idle", "profile": ["username": "MyName", "tags": ["art", "music"]]])
    }
    await service.activate(); await service.saveAndEnter(username: "MyName", tags: ["music", "art"], allowDirect: true)
    XCTAssertEqual(actions, ["heartbeat", "enter"]); XCTAssertEqual(service.state, "waiting"); service.deactivate()
  }

  func testSuccessfulExpiredRequestRetryReleasesNonceForNewRequest() async {
    var nonces: [String] = []
    let service = DiscoveryService { action, input in
      if action == "request" {
        nonces.append(input["nonce"] as! String)
        if nonces.count == 1 { throw URLError(.timedOut) }
      }
      // The original request expired before its lost response was retried.
      return self.response("waiting")
    }
    await service.activate()
    let person = DiscoveryPerson(id: UUID().uuidString, username: "Peer", tags: ["music"])
    await service.request(person); await service.request(person); await service.request(person)
    XCTAssertEqual(nonces.count, 3); XCTAssertEqual(nonces[0], nonces[1]); XCTAssertNotEqual(nonces[1], nonces[2]); service.deactivate()
  }

}
