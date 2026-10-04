import XCTest
@testable import MaroonSocial

@MainActor final class GroupCallServiceTests: XCTestCase {
  private func response(joined: Bool = false, media: Bool = false, empty: Bool = false) -> Data {
    var data: [String: Any] = ["transport": "direct", "call": NSNull()]
    if !empty {
      data["call"] = ["id": "11111111-1111-4111-8111-111111111111", "mode": "video", "transport": "direct", "joined": joined, "my_seat": joined ? "22222222-2222-4222-8222-222222222222" : NSNull(), "participants": [["seat": "22222222-2222-4222-8222-222222222222", "alias": "Me", "is_me": true], ["seat": "33333333-3333-4333-8333-333333333333", "alias": "Peer", "is_me": false]], "signals": [], "ends_at": 2000000000, "capacity": 4]
    }
    if media { data["ice_servers"] = [["urls": ["stun:stun.example.invalid:3478"]]] }
    return try! JSONSerialization.data(withJSONObject: data)
  }
  func testGroupPollNeverCapturesWithoutExplicitJoin() async {
    var actions: [String] = []
    let service = GroupCallService(roomID: "room") { action, _ in actions.append(action); return self.response() }
    await service.activate()
    XCTAssertFalse(service.canCapture); XCTAssertEqual(actions, ["poll"]); service.deactivate()
  }
  func testDelayedEndMustFinishBeforeRejoinIsDispatched() async {
    var actions: [String] = []; var end: CheckedContinuation<Data, Never>?
    let service = GroupCallService(roomID: "room") { action, _ in
      actions.append(action)
      if action == "end" { return await withCheckedContinuation { end = $0 } }
      if action == "poll" { return self.response() }
      return self.response(joined: true, media: action == "media")
    }
    await service.activate(); await service.join(mode: "video", allowDirect: true)
    XCTAssertTrue(service.canCapture)
    let leave = Task { await service.end() }
    for _ in 0..<50 where end == nil { await Task.yield() }
    XCTAssertNotNil(end); XCTAssertFalse(service.canCapture)
    let rejoin = Task { await service.join(mode: "video", allowDirect: true) }
    for _ in 0..<20 { await Task.yield() }
    XCTAssertEqual(actions.last, "end")
    end?.resume(returning: response(empty: true)); await leave.value; await rejoin.value
    XCTAssertEqual(Array(actions.suffix(3)), ["end", "invite", "media"])
    XCTAssertTrue(service.canCapture)
    // Resume subsequent cleanup immediately instead of leaving a held task.
    end = nil
    let cleanup = Task { await service.end() }
    for _ in 0..<50 where end == nil { await Task.yield() }; XCTAssertNotNil(end); end?.resume(returning: response(empty: true)); await cleanup.value; service.deactivate()
  }
  func testLateJoinIsCompensatedBeforeReactivationPoll() async {
    var actions: [String] = []; var invite: CheckedContinuation<Data, Never>?; var end: CheckedContinuation<Data, Never>?
    let service = GroupCallService(roomID: "room") { action, _ in
      actions.append(action)
      if action == "invite" { return await withCheckedContinuation { invite = $0 } }
      if action == "end" { return await withCheckedContinuation { end = $0 } }
      return self.response(empty: true)
    }
    await service.activate()
    let join = Task { await service.join(mode: "video", allowDirect: true) }
    for _ in 0..<50 where invite == nil { await Task.yield() }
    service.deactivate(); let reactivate = Task { await service.activate() }
    invite?.resume(returning: response(joined: true))
    for _ in 0..<50 where end == nil { await Task.yield() }
    XCTAssertNotNil(end); XCTAssertEqual(actions, ["poll", "invite", "end"]); XCTAssertFalse(service.canCapture)
    end?.resume(returning: response(empty: true)); await join.value; await reactivate.value
    XCTAssertEqual(actions, ["poll", "invite", "end", "poll"]); XCTAssertNil(service.call); XCTAssertFalse(service.canCapture); service.deactivate()
  }
  func testBackgroundImmediatelyStopsCaptureAndRejectsLateMedia() async {
    var media: CheckedContinuation<Data, Never>?
    let service = GroupCallService(roomID: "room") { action, _ in
      if action == "media" { return await withCheckedContinuation { media = $0 } }
      return self.response(joined: action == "accept")
    }
    await service.activate(); let join = Task { await service.join(mode: "video", allowDirect: true) }
    for _ in 0..<50 where media == nil { await Task.yield() }
    XCTAssertNotNil(media); service.deactivate(); XCTAssertFalse(service.canCapture)
    media?.resume(returning: response(joined: true, media: true)); await join.value
    XCTAssertFalse(service.canCapture); XCTAssertTrue(service.iceServers.isEmpty); XCTAssertNil(service.call)
  }
}
