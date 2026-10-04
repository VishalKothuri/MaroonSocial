import Foundation
import Observation

struct GroupCallPeer: Decodable, Identifiable, Equatable {
  let seat: String
  let alias: String
  let avatar: String?
  let isMe: Bool
  var id: String { seat }
  enum CodingKeys: String, CodingKey { case seat, alias, avatar; case isMe = "is_me" }
}
struct GroupCallSignal: Decodable, Identifiable {
  let id: Int
  let from: String
  let kind: String
  let payload: ChatJSON
  var payloadJSON: String { String(decoding: (try? JSONEncoder().encode(payload)) ?? Data("{}".utf8), as: UTF8.self) }
}
struct GroupCallSession: Decodable {
  let id: String
  let mode: String
  let transport: String
  let joined: Bool
  let mySeat: String?
  let participants: [GroupCallPeer]
  let signals: [GroupCallSignal]
  let endsAt: Double
  let capacity: Int
  enum CodingKeys: String, CodingKey { case id, mode, transport, joined, participants, signals, capacity; case mySeat = "my_seat", endsAt = "ends_at" }
}
private struct GroupCallResponse: Decodable {
  let call: GroupCallSession?
  let transport: String?
  let iceServers: [RandomChatIceServer]?
  enum CodingKeys: String, CodingKey { case call, transport; case iceServers = "ice_servers" }
}
@Observable @MainActor final class GroupCallService {
  typealias Transport = @MainActor (String, [String: Any]) async throws -> Data
  private(set) var call: GroupCallSession?
  private(set) var transport = "direct"
  private(set) var signals: [GroupCallSignal] = []
  private(set) var iceServers: [RandomChatIceServer] = []
  private(set) var busy = false
  private(set) var consented = false
  var error: String?
  var notice: String?
  var canCapture: Bool { active && consented && call?.joined == true && (call?.participants.count ?? 0) >= 2 && !iceServers.isEmpty }
  let roomID: String
  private let requestTransport: Transport
  private var generation = 0
  private var active = false
  private var allowsDirect = false
  private var lastSignal = 0
  private var failures = 0
  private var pollTask: Task<Void, Never>?
  private var tail: Task<Void, Never>?
  private var pendingInvite: (mode: String, nonce: String)?
  init(social: SocialService, roomID: String) {
    self.roomID = roomID
    self.requestTransport = { action, input in try await social.sendData(endpoint: "group-calls", action: action, payload: input) }
  }
  init(roomID: String, transport: @escaping Transport) { self.roomID = roomID; self.requestTransport = transport }
  func activate() async {
    guard !active else { return }; active = true; generation += 1; let epoch = generation
    await refresh()
    guard active, epoch == generation else { return }
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1.3))
        guard let self, self.active, !Task.isCancelled else { break }
        await self.refresh()
      }
    }
  }
  func join(mode: String, allowDirect: Bool) async {
    guard active, !busy else { return }
    generation += 1; let epoch = generation
    busy = true; consented = true; allowsDirect = allowDirect; error = nil; notice = nil
    defer { if epoch == generation { busy = false } }
    let existing = call?.id
    var input: [String: Any] = ["mode": mode, "allow_direct": allowDirect]
    if let existing { input["call_id"] = existing }
    else {
      if pendingInvite?.mode != mode { pendingInvite = (mode, UUID().uuidString) }
      input["nonce"] = pendingInvite!.nonce
    }
    do {
      let result = try await request(existing == nil ? "invite" : "accept", input)
      guard active, epoch == generation else { return }
      apply(result); pendingInvite = nil
      await prepareMedia(epoch: epoch)
    } catch { if active, epoch == generation { consented = false; self.error = error.localizedDescription } }
  }
  func refresh() async {
    guard active, !busy else { return }; let epoch = generation
    do {
      let result = try await request("poll", ["after": lastSignal])
      guard active, epoch == generation else { return }
      apply(result); failures = 0
      await prepareMedia(epoch: epoch)
    } catch {
      guard active, epoch == generation else { return }
      failures += 1; self.error = error.localizedDescription
      if ["unauthorized", "forbidden", "verification_required", "account_deleted"].contains((error as? SocialServiceError)?.code ?? "") || failures >= 3 {
        let id = call?.id; clearLocal(); notice = "Call stopped because membership could not be verified."
        if let id { _ = enqueue("end", ["call_id": id]) }
      }
    }
  }
  func signal(to: String, kind: String, payloadJSON: String) async {
    guard canCapture, let id = call?.id, call?.participants.contains(where: { $0.seat == to && !$0.isMe }) == true,
          let data = payloadJSON.data(using: .utf8), let payload = try? JSONSerialization.jsonObject(with: data) else { return }
    let epoch = generation
    do {
      let response = try await request("signal", ["call_id": id, "to": to, "kind": kind, "payload": payload, "nonce": UUID().uuidString, "after": lastSignal, "allow_direct": allowsDirect])
      guard active, epoch == generation, call?.id == id else { return }; apply(response)
    } catch { if active, epoch == generation { self.error = error.localizedDescription } }
  }
  func end() async {
    let id = call?.id; clearLocal(); notice = "You left the call."
    if let id { _ = try? await enqueue("end", ["call_id": id]).value }
  }
  func deactivate() {
    active = false; pollTask?.cancel(); pollTask = nil
    let id = call?.id; clearLocal()
    if let id { _ = enqueue("end", ["call_id": id]) }
  }
  private func clearLocal() {
    generation += 1; consented = false; allowsDirect = false; iceServers = []; signals = []; lastSignal = 0; call = nil; busy = false; pendingInvite = nil
  }
  private func prepareMedia(epoch: Int) async {
    guard active, epoch == generation, consented, call?.joined == true, (call?.participants.count ?? 0) >= 2, iceServers.isEmpty, let id = call?.id else { return }
    do {
      let result = try await request("media", ["call_id": id, "allow_direct": allowsDirect, "after": lastSignal])
      guard active, epoch == generation, call?.id == id else { return }
      apply(result); iceServers = result.iceServers ?? []
    } catch {
      guard active, epoch == generation else { return }
      self.error = error.localizedDescription; clearLocal(); _ = try? await enqueue("end", ["call_id": id]).value
    }
  }
  private func apply(_ response: GroupCallResponse) {
    transport = response.transport ?? transport
    guard let value = response.call else { call = nil; iceServers = []; signals = []; lastSignal = 0; consented = false; return }
    if call?.id != value.id || call?.mySeat != value.mySeat { iceServers = []; signals = []; lastSignal = 0 }
    call = value
    if !value.joined { consented = false; iceServers = [] }
    let received = Set(signals.map(\.id)); signals.append(contentsOf: value.signals.filter { !received.contains($0.id) })
    lastSignal = max(lastSignal, value.signals.map(\.id).max() ?? 0)
  }
  private func request(_ action: String, _ payload: [String: Any]) async throws -> GroupCallResponse { try await enqueue(action, payload).value }
  private func enqueue(_ action: String, _ payload: [String: Any]) -> Task<GroupCallResponse, Error> {
    let previous = tail, epoch = generation
    let task = Task { @MainActor [self] in
      await previous?.value
      guard action == "end" || (active && epoch == generation && !Task.isCancelled) else { throw CancellationError() }
      var input = payload; input["room_id"] = roomID
      let result = try JSONDecoder().decode(GroupCallResponse.self, from: await requestTransport(action, input))
      // A join can finish after leaving before its call ID was known locally.
      // Compensate before releasing the queue, so its delayed end can never
      // overtake a newer join to the same group call.
      if ["invite", "accept"].contains(action), (!active || epoch != generation), let id = result.call?.id {
        _ = try? await requestTransport("end", ["room_id": roomID, "call_id": id])
      }
      return result
    }
    tail = Task { _ = try? await task.value }; return task
  }
}
