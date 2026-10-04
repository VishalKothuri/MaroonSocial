import XCTest
@testable import MaroonSocial

@MainActor final class RoomCallServiceTests: XCTestCase {
  func testRemoteConnectedCallDoesNotCaptureWithoutFreshLocalConsent() async {
    let api = CallTestAPI()
    api.handler = { action, _ in api.connected(media: action == "media") }
    let service = RoomCallService(roomID: "room", transport: api.send)
    await service.activate()
    XCTAssertEqual(service.call?.state, "connected")
    XCTAssertFalse(service.consented)
    XCTAssertFalse(service.canCapture)
    XCTAssertFalse(api.actions.contains("media"))
    await service.accept(allowDirect: true)
    XCTAssertTrue(service.canCapture)
    service.deactivate()
    XCTAssertFalse(service.canCapture)
    XCTAssertTrue(service.iceServers.isEmpty)
  }
  func testEndStopsCaptureBeforeDelayedNetworkResponse() async {
    let api = CallTestAPI()
    api.handler = { action, _ in api.connected(media: action == "media") }
    let service = RoomCallService(roomID: "room", transport: api.send)
    await service.activate(); await service.accept(allowDirect: true)
    XCTAssertTrue(service.canCapture)
    let sent = expectation(description: "end sent")
    var release: CheckedContinuation<Data, Never>?
    api.handler = { action, _ in
      if action == "end" { return await withCheckedContinuation { release = $0; sent.fulfill() } }
      return api.connected()
    }
    let end = Task { await service.end() }
    await fulfillment(of: [sent], timeout: 2)
    XCTAssertFalse(service.canCapture)
    XCTAssertNil(service.call)
    XCTAssertTrue(service.iceServers.isEmpty)
    release?.resume(returning: api.connected())
    await end.value
    XCTAssertFalse(service.canCapture)
    XCTAssertNil(service.call)
    service.deactivate()
  }
  func testDelayedInviteAfterLeavingIsEndedWithoutStartingCapture() async {
    let api = CallTestAPI()
    let sent = expectation(description: "invite sent")
    var release: CheckedContinuation<Data, Never>?
    api.handler = { action, _ in
      if action == "invite" { return await withCheckedContinuation { release = $0; sent.fulfill() } }
      return api.empty()
    }
    let service = RoomCallService(roomID: "room", transport: api.send)
    await service.activate()
    let invite = Task { await service.invite(mode: "video", allowDirect: true) }
    await fulfillment(of: [sent], timeout: 2)
    service.deactivate()
    release?.resume(returning: api.connected())
    await invite.value
    XCTAssertFalse(service.canCapture)
    XCTAssertNil(service.call)
    XCTAssertTrue(api.actions.contains("end"))
    XCTAssertFalse(api.actions.contains("media"))
  }
  func testDelayedMediaConfigCannotRestartCaptureAfterBackground() async {
    let api = CallTestAPI()
    let sent = expectation(description: "media sent")
    var release: CheckedContinuation<Data, Never>?
    api.handler = { action, _ in
      if action == "media" { return await withCheckedContinuation { release = $0; sent.fulfill() } }
      return api.connected()
    }
    let service = RoomCallService(roomID: "room", transport: api.send)
    await service.activate()
    let accept = Task { await service.accept(allowDirect: true) }
    await fulfillment(of: [sent], timeout: 2)
    service.deactivate()
    release?.resume(returning: api.connected(media: true))
    await accept.value
    XCTAssertFalse(service.canCapture)
    XCTAssertNil(service.call)
    XCTAssertTrue(service.iceServers.isEmpty)
  }
  func testMembershipRevocationImmediatelyRemovesCapture() async {
    let api = CallTestAPI()
    api.handler = { action, _ in api.connected(media: action == "media") }
    let service = RoomCallService(roomID: "room", transport: api.send)
    await service.activate(); await service.accept(allowDirect: true)
    XCTAssertTrue(service.canCapture)
    api.handler = { _, _ in throw SocialServiceError(error: "This conversation is blocked.", code: "forbidden") }
    await service.refresh()
    XCTAssertFalse(service.canCapture)
    XCTAssertNil(service.call)
    service.deactivate()
  }
}
@MainActor private final class CallTestAPI {
  var actions: [String] = []
  var handler: ((String, [String: Any]) async throws -> Data)?
  func send(_ action: String, _ payload: [String: Any]) async throws -> Data {
    actions.append(action)
    return try await handler?(action, payload) ?? empty()
  }
  func empty() -> Data { Data(#"{"call":null,"transport":"direct"}"#.utf8) }
  func connected(media: Bool = false) -> Data {
    var response: [String: Any] = ["transport": "direct", "call": ["id": "call", "room_id": "room", "mode": "video", "transport": "direct", "state": "connected", "initiator": true, "incoming": false, "signals": []]]
    if media { response["ice_servers"] = [["urls": ["stun:stun.example.test:19302"]]] }
    return try! JSONSerialization.data(withJSONObject: response)
  }
}
