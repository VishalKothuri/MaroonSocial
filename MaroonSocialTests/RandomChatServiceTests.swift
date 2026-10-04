import Foundation
import XCTest
@testable import MaroonSocial

@MainActor final class RandomChatServiceTests: XCTestCase {
  func testExpiredCredentialRenewsButSuspendedCredentialDoesNot() async throws {
    let expired = MemoryChatCredentials("expired")
    let api = ChatTestAPI()
    var joins = 0
    api.handler = { action, _ in
      if action == "join" {
        joins += 1
        if joins == 1 { return .failure("Session expired", code: "unauthorized", status: 401) }
        return .snapshot("waiting")
      }
      if action == "register" { return .snapshot("idle", token: "fresh") }
      return .snapshot("idle")
    }
    let service = RandomChatService(transport: api.send, credentialStore: expired)
    await service.activate()
    await service.start()
    XCTAssertEqual(service.state, .waiting)
    XCTAssertEqual(expired.token, "fresh")
    XCTAssertEqual(expired.deletions, 1)
    XCTAssertEqual(api.actions.filter { $0 == "register" }.count, 1)
    service.deactivate()

    let suspended = MemoryChatCredentials("banned")
    let bannedAPI = ChatTestAPI()
    bannedAPI.handler = { action, _ in
      action == "join" ? .failure("This guest session is suspended.", code: "forbidden", status: 403) : .snapshot("idle")
    }
    let bannedService = RandomChatService(transport: bannedAPI.send, credentialStore: suspended)
    await bannedService.activate()
    await bannedService.start()
    XCTAssertEqual(bannedService.state, .idle)
    XCTAssertTrue(bannedService.error?.contains("suspended") == true)
    XCTAssertEqual(suspended.token, "banned")
    XCTAssertEqual(suspended.deletions, 0)
    XCTAssertFalse(bannedAPI.actions.contains("register"))
    bannedService.deactivate()
  }

  func testDelayedStartCannotReopenChatAfterLeavingAndReactivating() async throws {
    let api = ChatTestAPI()
    let started = expectation(description: "join started")
    var release: CheckedContinuation<ChatTestReply, Never>?
    api.handler = { action, _ in
      if action == "join" {
        return await withCheckedContinuation { continuation in
          release = continuation
          started.fulfill()
        }
      }
      return .snapshot("idle")
    }
    let service = RandomChatService(transport: api.send, credentialStore: MemoryChatCredentials("guest"))
    await service.activate()
    let start = Task { await service.start() }
    await fulfillment(of: [started], timeout: 2)
    service.deactivate()
    let reopened = Task { await service.activate() }
    release?.resume(returning: .snapshot("connected", room: "old-room"))
    await start.value
    await reopened.value
    XCTAssertEqual(service.state, .ended)
    XCTAssertNil(service.roomID)
    let join = try XCTUnwrap(api.actions.firstIndex(of: "join"))
    let leave = try XCTUnwrap(api.actions.firstIndex(of: "leave"))
    XCTAssertLessThan(join, leave)
    XCTAssertEqual(api.actions.last, "capabilities")
    service.deactivate()
  }

  func testDelayedEndResponseCannotReplaceReactivatedState() async throws {
    let api = ChatTestAPI()
    api.handler = { action, _ in
      action == "join" ? .snapshot("connected", room: "room") : .snapshot("idle")
    }
    let service = RandomChatService(transport: api.send, credentialStore: MemoryChatCredentials("guest"))
    await service.activate()
    await service.start()
    let started = expectation(description: "end started")
    var release: CheckedContinuation<ChatTestReply, Never>?
    var held = false
    api.handler = { action, _ in
      if action == "leave", !held {
        held = true
        return await withCheckedContinuation { continuation in
          release = continuation
          started.fulfill()
        }
      }
      return .snapshot("idle")
    }
    let end = Task { await service.end() }
    await fulfillment(of: [started], timeout: 2)
    service.deactivate()
    let reopened = Task { await service.activate() }
    release?.resume(returning: .snapshot("ended", room: "stale-room", message: "stale message"))
    await end.value
    await reopened.value
    XCTAssertEqual(service.state, .ended)
    XCTAssertEqual(service.roomID, "room")
    XCTAssertTrue(service.messages.isEmpty)
    service.deactivate()
  }

  func testRetryKeepsMessageNonceAfterUnknownNetworkOutcome() async throws {
    let api = ChatTestAPI()
    var sends = 0
    api.handler = { action, _ in
      if action == "send" {
        sends += 1
        if sends == 1 { throw URLError(.timedOut) }
        return .snapshot("connected", room: "room", message: "Howdy")
      }
      return action == "join" ? .snapshot("connected", room: "room") : .snapshot("idle")
    }
    let service = RandomChatService(transport: api.send, credentialStore: MemoryChatCredentials("guest"))
    await service.activate()
    await service.start()
    let first = await service.send("Howdy")
    let retry = await service.send("Howdy")
    XCTAssertFalse(first)
    XCTAssertTrue(retry)
    let requests = api.bodies.filter { $0["action"] as? String == "send" }
    XCTAssertEqual(requests.count, 2)
    XCTAssertEqual(requests[0]["nonce"] as? String, requests[1]["nonce"] as? String)
    XCTAssertEqual(service.messages.count, 1)
    service.deactivate()
  }

  func testDirectMediaConsentIsExplicitAndCarriedThroughNextAndMedia() async throws {
    let api = ChatTestAPI()
    let mediaRequested = expectation(description: "media requested after consent")
    api.handler = { action, body in
      if action == "join", body["allow_direct"] as? Bool != true {
        return .failure("Direct calls require consent", code: "direct_consent_required", status: 400)
      }
      var reply = ChatTestReply.snapshot(action == "next" ? "waiting" : (action == "join" || action == "media" ? "connected" : "idle"), room: action == "next" ? nil : "media-room").object
      reply["media_enabled"] = true
      reply["media_transport"] = "direct"
      reply["mode"] = "video"
      if action == "media" {
        reply["call"] = ["transport": "direct", "ice_servers": [["urls": ["stun:example.invalid:19302"]]]]
        mediaRequested.fulfill()
      }
      return ChatTestReply(status: 200, object: reply)
    }
    let service = RandomChatService(transport: api.send, credentialStore: MemoryChatCredentials("guest"))
    await service.activate()
    XCTAssertEqual(service.mediaTransport, "direct")
    await service.start(mode: "video")
    XCTAssertEqual(service.state, .idle)
    XCTAssertFalse(service.allowsDirect)
    XCTAssertFalse(api.actions.contains("media"))
    await service.start(mode: "video", allowDirect: true)
    await fulfillment(of: [mediaRequested], timeout: 2)
    for _ in 0..<20 where service.iceServers.isEmpty { await Task.yield() }
    XCTAssertTrue(service.allowsDirect)
    XCTAssertEqual(service.callTransport, "direct")
    await service.next()
    for body in api.bodies where ["next", "media"].contains(body["action"] as? String ?? "") {
      XCTAssertEqual(body["allow_direct"] as? Bool, true)
    }
    service.deactivate()
  }

  func testSafetyActionsStopLocalMediaBeforeDelayedNetworkResponse() async throws {
    for action in ["leave", "next", "block", "report"] {
      let api = ChatTestAPI()
      let mediaReady = expectation(description: "media ready for \(action)")
      let mutationStarted = expectation(description: "delayed \(action)")
      var release: CheckedContinuation<ChatTestReply, Never>?
      api.handler = { requestAction, _ in
        if requestAction == action {
          return await withCheckedContinuation { continuation in
            release = continuation
            mutationStarted.fulfill()
          }
        }
        var reply = ChatTestReply.snapshot(requestAction == "capabilities" ? "idle" : "connected", room: "media-room").object
        reply["mode"] = "video"
        reply["media_enabled"] = true
        reply["media_transport"] = "direct"
        if requestAction == "media" {
          reply["call"] = ["transport": "direct", "ice_servers": [["urls": ["stun:example.invalid:19302"]]]]
          mediaReady.fulfill()
        }
        return ChatTestReply(status: 200, object: reply)
      }
      let service = RandomChatService(transport: api.send, credentialStore: MemoryChatCredentials("guest"))
      await service.activate()
      await service.start(mode: "video", allowDirect: true)
      await fulfillment(of: [mediaReady], timeout: 2)
      for _ in 0..<20 where service.iceServers.isEmpty { await Task.yield() }
      XCTAssertFalse(service.iceServers.isEmpty, "Media should be mounted before \(action)")
      let operation = Task {
        switch action {
        case "leave": await service.end()
        case "next": await service.next()
        case "block": await service.block()
        default: await service.report(reason: "Harassment")
        }
      }
      await fulfillment(of: [mutationStarted], timeout: 2)
      XCTAssertEqual(service.state, .ended, "\(action) must unmount the camera before HTTP completes")
      XCTAssertTrue(service.iceServers.isEmpty, "\(action) must release media immediately")
      release?.resume(returning: .snapshot(action == "next" ? "waiting" : "ended", room: action == "next" ? nil : "media-room"))
      await operation.value
      // Do not delay the best-effort teardown invoked when this test screen closes.
      api.handler = { _, _ in .snapshot("ended", room: "media-room") }
      service.deactivate()
    }
  }

  func testFailedEndCannotReopenOldCallWhenRetryPollFindsServerRoom() async throws {
    let api = ChatTestAPI()
    var nextAttempts = 0
    api.handler = { action, _ in
      if action == "leave" { throw URLError(.networkConnectionLost) }
      if action == "next" {
        nextAttempts += 1
        if nextAttempts == 1 { throw URLError(.networkConnectionLost) }
        return .snapshot("waiting")
      }
      return .snapshot(action == "capabilities" ? "idle" : "connected", room: "old-room")
    }
    let service = RandomChatService(transport: api.send, credentialStore: MemoryChatCredentials("guest"))
    await service.activate()
    await service.start()
    XCTAssertEqual(service.state, .connected)
    await service.end()
    XCTAssertEqual(service.state, .ended)
    await service.refresh()
    XCTAssertEqual(service.state, .ended, "Retry polling must not revive a conversation the user ended")
    XCTAssertTrue(service.iceServers.isEmpty)
    await service.start()
    XCTAssertEqual(service.state, .ended, "A failed new-match request must preserve local teardown")
    await service.refresh()
    XCTAssertEqual(service.state, .ended)
    await service.start()
    XCTAssertEqual(service.state, .waiting)
    XCTAssertEqual(api.actions.filter { $0 == "join" }.count, 1)
    XCTAssertEqual(api.actions.filter { $0 == "next" }.count, 2, "Meet someone new must end the old server room")
    api.handler = { _, _ in .snapshot("ended") }
    service.deactivate()
  }

  func testSecureStorageFailureIsActionableAndNeverStartsMatching() async throws {
    let credentials = MemoryChatCredentials(nil)
    credentials.saveError = ChatCredentialError(status: -34018)
    let api = ChatTestAPI()
    api.handler = { action, _ in .snapshot("idle", token: action == "register" ? "new-token" : nil) }
    let service = RandomChatService(transport: api.send, credentialStore: credentials)
    await service.activate()
    await service.start()
    XCTAssertTrue(service.error?.contains("-34018") == true)
    XCTAssertFalse(api.actions.contains("join"))
    service.deactivate()
  }
}

@MainActor private final class MemoryChatCredentials: RandomChatCredentialStore {
  var token: String?
  var deletions = 0
  var saveError: Error?
  init(_ token: String?) { self.token = token }
  func read() -> String? { token }
  func save(_ token: String) throws {
    if let saveError { throw saveError }
    self.token = token
  }
  func delete() { token = nil; deletions += 1 }
}

private struct ChatTestReply {
  let status: Int
  let object: [String: Any]
  static func snapshot(_ state: String, room: String? = nil, token: String? = nil, message: String? = nil) -> ChatTestReply {
    var body: [String: Any] = ["state": state, "mode": "text", "initiator": false, "signals": [], "media_enabled": false]
    body["room"] = room
    body["token"] = token
    body["messages"] = message.map { [["id": 1, "body": $0, "mine": true, "created_at": "2026-10-02T00:00:00Z"]] } ?? []
    return ChatTestReply(status: 200, object: body)
  }
  static func failure(_ message: String, code: String, status: Int) -> ChatTestReply {
    ChatTestReply(status: status, object: ["error": message, "code": code])
  }
}

@MainActor private final class ChatTestAPI {
  var bodies: [[String: Any]] = []
  var actions: [String] { bodies.compactMap { $0["action"] as? String } }
  var handler: (String, [String: Any]) async throws -> ChatTestReply = { _, _ in .snapshot("idle") }
  func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
    let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
    bodies.append(body)
    let reply = try await handler(body["action"] as! String, body)
    return (try JSONSerialization.data(withJSONObject: reply.object),
      HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!)
  }
}
