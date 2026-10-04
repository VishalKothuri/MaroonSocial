import Foundation
import Observation

struct RoomCallSummary: Codable, Equatable {
  let id: String
  let mode: String
  let state: String
  let incoming: Bool
}
struct RoomCallSession: Decodable {
  let id: String
  let roomID: String
  let mode: String
  let transport: String
  let state: String
  let initiator: Bool
  let incoming: Bool
  let signals: [RandomChatSignal]
  let endReason: String?
  enum CodingKeys: String, CodingKey {
    case id, mode, transport, state, initiator, incoming, signals
    case roomID = "room_id", endReason = "end_reason"
  }
}
struct RoomCallResponse: Decodable {
  let call: RoomCallSession?
  let transport: String?
  let iceServers: [RandomChatIceServer]?
  enum CodingKeys: String, CodingKey { case call, transport; case iceServers = "ice_servers" }
}

/// Accepted DM calls. Local consent and lifecycle gates precede all media capture.
@Observable @MainActor final class RoomCallService {
  typealias Transport = @MainActor (String, [String: Any]) async throws -> Data
  let roomID: String
  private(set) var call: RoomCallSession?
  private(set) var transport = "direct"
  private(set) var iceServers: [RandomChatIceServer] = []
  private(set) var signals: [RandomChatSignal] = []
  private(set) var consented = false
  private(set) var busy = false
  var error: String?
  var notice: String?
  var canCapture: Bool { active && consented && call?.state == "connected" && !iceServers.isEmpty }
  private var active = false
  private var generation = 0
  private var failures = 0
  private var lastSignal = 0
  private var allowsDirect = false
  private var pollTask: Task<Void, Never>?
  private var loadingMedia = false
  private let requestTransport: Transport

  init(social: SocialService, roomID: String) {
    self.roomID = roomID
    self.requestTransport = { action, payload in try await social.sendData(endpoint: "room-calls", action: action, payload: payload) }
  }
  init(roomID: String, transport: @escaping Transport) {
    self.roomID = roomID
    self.requestTransport = transport
  }
  func activate() async {
    guard !active else { return }
    active = true; generation += 1
    await refresh()
    guard active else { return }
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1.3))
        guard !Task.isCancelled, let self, self.active else { break }
        await self.refresh()
      }
    }
  }
  func invite(mode: String, allowDirect: Bool) async {
    guard active, !busy else { return }
    generation += 1; let version = generation
    busy = true; error = nil; notice = nil
    consented = true; allowsDirect = allowDirect
    defer { if version == generation { busy = false } }
    do {
      let result = try await request("invite", ["mode": mode, "allow_direct": allowDirect, "nonce": UUID().uuidString])
      guard active, version == generation else { if let id = result.call?.id { await endRemote(id) }; return }
      apply(result)
    } catch { if active, version == generation { consented = false; self.error = error.localizedDescription } }
  }
  func accept(allowDirect: Bool) async {
    guard active, !busy, let id = call?.id else { return }
    generation += 1; let version = generation
    busy = true; error = nil; notice = nil
    consented = true; allowsDirect = allowDirect
    defer { if version == generation { busy = false } }
    do {
      let result = try await request("accept", ["call_id": id, "allow_direct": allowDirect])
      guard active, version == generation else { await endRemote(id); return }
      apply(result)
      await prepareMedia(version: version)
    } catch { if active, version == generation { consented = false; self.error = error.localizedDescription } }
  }
  func refresh() async {
    guard active, !busy else { return }
    let version = generation
    do {
      var payload: [String: Any] = ["after": lastSignal]
      if let id = call?.id { payload["call_id"] = id }
      let result = try await request("poll", payload)
      guard active, version == generation else { return }
      failures = 0
      apply(result)
      await prepareMedia(version: version)
    } catch {
      guard active, version == generation else { return }
      failures += 1
      self.error = error.localizedDescription
      let forbidden = (error as? SocialServiceError)?.code == "forbidden" || (error as? SocialServiceError)?.code == "unauthorized"
      if forbidden || failures >= 3 {
        let id = call?.id
        clearLocal()
        notice = "Call stopped because the connection could not be verified."
        if let id { Task { await endRemote(id) } }
      }
    }
  }
  func sendSignal(kind: String, payloadJSON: String) async {
    guard canCapture, let id = call?.id, let bytes = payloadJSON.data(using: .utf8),
          let payload = try? JSONSerialization.jsonObject(with: bytes) else { return }
    let version = generation
    do {
      let result = try await request("signal", ["call_id": id, "kind": kind, "payload": payload, "after": lastSignal])
      guard active, version == generation, call?.id == id else { return }
      apply(result)
    } catch {
      guard active, version == generation else { return }
      self.error = error.localizedDescription
    }
  }
  func end(decline: Bool = false) async {
    let id = call?.id
    clearLocal()
    notice = decline ? "Call declined." : "Call ended."
    if let id { await endRemote(id, decline: decline) }
  }
  func deactivate() {
    let id = call?.id
    active = false
    pollTask?.cancel(); pollTask = nil
    clearLocal()
    if let id { Task { await endRemote(id) } }
  }
  private func clearLocal() {
    generation += 1
    call = nil; iceServers = []; signals = []; lastSignal = 0
    consented = false; allowsDirect = false; busy = false; loadingMedia = false
  }
  private func prepareMedia(version: Int) async {
    guard active, version == generation, consented, call?.state == "connected", iceServers.isEmpty, !loadingMedia, let id = call?.id else { return }
    loadingMedia = true
    defer { if version == generation { loadingMedia = false } }
    do {
      let result = try await request("media", ["call_id": id, "allow_direct": allowsDirect, "after": lastSignal])
      guard active, version == generation, call?.id == id else { return }
      apply(result)
      iceServers = result.iceServers ?? []
    } catch {
      guard active, version == generation else { return }
      self.error = error.localizedDescription
      clearLocal()
      await endRemote(id)
    }
  }
  private func apply(_ response: RoomCallResponse) {
    transport = response.transport ?? transport
    guard let value = response.call, value.state != "ended" else {
      if call != nil { notice = response.call?.endReason == "declined" ? "The call was declined." : "Call ended." }
      call = nil; iceServers = []; signals = []; lastSignal = 0; consented = false
      return
    }
    if call?.id != value.id { signals = []; lastSignal = 0; iceServers = [] }
    call = value
    let existing = Set(signals.map(\.id))
    signals.append(contentsOf: value.signals.filter { !existing.contains($0.id) })
    lastSignal = max(lastSignal, value.signals.map(\.id).max() ?? 0)
  }
  private func request(_ action: String, _ payload: [String: Any] = [:]) async throws -> RoomCallResponse {
    var input = payload; input["room_id"] = roomID
    return try JSONDecoder().decode(RoomCallResponse.self, from: await requestTransport(action, input))
  }
  private func endRemote(_ id: String, decline: Bool = false) async {
    _ = try? await request(decline ? "decline" : "end", ["call_id": id])
  }
}
