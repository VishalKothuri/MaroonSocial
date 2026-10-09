import Foundation
import Observation

struct DiscoveryProfile: Decodable, Equatable { let username: String; let tags: [String] }
struct DiscoveryPerson: Decodable, Identifiable, Equatable { let id: String; let username: String; let tags: [String] }
struct DiscoveryIncoming: Decodable, Identifiable, Equatable {
  let id: String; let from: DiscoveryProfile; let expiresAt: Double
  enum CodingKeys: String, CodingKey { case id, from; case expiresAt = "expires_at" }
}
struct DiscoveryOutgoing: Decodable, Equatable {
  let id: String; let to: DiscoveryProfile; let expiresAt: Double
  enum CodingKeys: String, CodingKey { case id, to; case expiresAt = "expires_at" }
}
struct DiscoverySession: Decodable, Equatable {
  let id: String; let room: String?; let peer: DiscoveryProfile; let initiator: Bool; let endsAt: Double
  enum CodingKeys: String, CodingKey { case id, room, peer, initiator; case endsAt = "ends_at" }
}
private struct DiscoveryResponse: Decodable {
  let profile: DiscoveryProfile?
  let state: String
  let people: [DiscoveryPerson]?
  let incoming: [DiscoveryIncoming]?
  let outgoing: DiscoveryOutgoing?
  let session: DiscoverySession?
  let messages: [RandomChatMessage]?
  let signals: [RandomChatSignal]?
  let mediaTransport: String?
  let iceServers: [RandomChatIceServer]?
  let continueRoom: String?
  enum CodingKeys: String, CodingKey { case profile, state, people, incoming, outgoing, session, messages, signals; case mediaTransport = "media_transport", iceServers = "ice_servers", continueRoom = "continue_room" }
}
@Observable @MainActor final class DiscoveryService {
  typealias Transport = @MainActor (String, [String: Any]) async throws -> Data
  private(set) var profile: DiscoveryProfile?
  private(set) var state = "idle"
  private(set) var people: [DiscoveryPerson] = []
  private(set) var incoming: [DiscoveryIncoming] = []
  private(set) var outgoing: DiscoveryOutgoing?
  private(set) var session: DiscoverySession?
  private(set) var messages: [RandomChatMessage] = []
  private(set) var signals: [RandomChatSignal] = []
  private(set) var transport = "direct"
  private(set) var iceServers: [RandomChatIceServer] = []
  private(set) var busy = false
  private(set) var sending = false
  var error: String?
  var notice: String?
  var canCapture: Bool { active && state == "connected" && acknowledged == session?.id && !iceServers.isEmpty }
  private let instance = UUID().uuidString
  private let sendRequest: Transport
  private var generation = 0
  private var active = false
  private var allowsDirect = false
  private var acknowledged: String?
  private var acknowledging = false
  private var preparingMedia = false
  private var lastSignal = 0
  private var failures = 0
  private var polling: Task<Void, Never>?
  private var tail: Task<Void, Never>?
  private var pendingMessage: (sessionID: String, text: String, nonce: String)?
  private var pendingRequest: (target: String, nonce: String)?
  init(social: SocialService) { sendRequest = { action, input in try await social.sendData(endpoint: "discovery", action: action, payload: input) } }
  init(transport: @escaping Transport) { sendRequest = transport }
  func activate() async {
    guard !active else { return }; active = true; generation += 1; let epoch = generation
    await refresh()
    guard active, epoch == generation else { return }
    polling = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1.3))
        guard let self, self.active, !Task.isCancelled else { break }
        if ["waiting", "connecting", "connected"].contains(self.state) { await self.refresh() }
      }
    }
  }
  func saveProfile(username: String, tags: [String]) async { await mutate("profile", ["username": username, "tags": tags]) }
  func enter(allowDirect: Bool) async { allowsDirect = allowDirect; await mutate("enter", ["allow_direct": allowDirect]) }
  func saveAndEnter(username: String, tags: [String], allowDirect: Bool) async {
    let epoch = generation
    let matches = { [self] in profile?.username == username && Set(profile?.tags ?? []) == Set(tags) }
    if !matches() { await saveProfile(username: username, tags: tags) }
    guard active, epoch == generation, matches() else { return }
    await enter(allowDirect: allowDirect)
  }
  func request(_ person: DiscoveryPerson) async {
    if pendingRequest?.target != person.id { pendingRequest = (person.id, UUID().uuidString) }
    let succeeded = await mutate("request", ["target": person.id, "nonce": pendingRequest!.nonce])
    if succeeded { pendingRequest = nil }
  }
  func accept(_ request: DiscoveryIncoming) async { await mutate("accept", ["request_id": request.id]); await prepare() }
  func decline(_ request: DiscoveryIncoming) async { await mutate("decline", ["request_id": request.id]) }
  func cancelRequest() async { if let outgoing { await mutate("cancel", ["request_id": outgoing.id]) } }
  func continueInInbox() async { if let session { await mutate("continue", ["session_id": session.id]) } }
  func moderate(reason: String?) async {
    guard let session else { return }
    stopLocal(); let epoch = generation
    do { _ = try await requestData(reason == nil ? "block" : "report", ["session_id": session.id, "reason": reason ?? "Blocked"]); if epoch == generation { notice = reason == nil ? "Account blocked." : "Report saved. This account is blocked." } }
    catch { if epoch == generation { self.error = error.localizedDescription } }
  }
  func refresh() async {
    guard active, !busy else { return }; let epoch = generation
    do {
      let value = try await requestData("heartbeat")
      guard active, epoch == generation else { return }
      apply(value); failures = 0
      await prepare()
    } catch {
      guard active, epoch == generation else { return }; failures += 1; self.error = error.localizedDescription
      if failures >= 2 || ["unauthorized", "forbidden", "verification_required", "conflict"].contains((error as? SocialServiceError)?.code ?? "") {
        stopLocal(); notice = "Waiting and video stopped because your connection could not be verified."
        _ = enqueue("leave", [:])
      }
    }
  }
  @discardableResult func send(_ text: String) async -> Bool {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard active, state == "connected", !sending, let session, !value.isEmpty, value.count <= 2000 else { return false }
    sending = true; let epoch = generation; defer { if epoch == generation { sending = false } }
    if pendingMessage?.sessionID != session.id || pendingMessage?.text != value { pendingMessage = (session.id, value, UUID().uuidString) }
    do {
      let result = try await requestData("send", ["session_id": session.id, "body": value, "nonce": pendingMessage!.nonce])
      guard active, epoch == generation, self.session?.id == session.id else { return false }
      apply(result); pendingMessage = nil; return true
    } catch { if epoch == generation { self.error = error.localizedDescription }; return false }
  }
  func signal(kind: String, payloadJSON: String) async {
    guard canCapture, let session, let bytes = payloadJSON.data(using: .utf8), let payload = try? JSONSerialization.jsonObject(with: bytes) else { return }
    let epoch = generation
    do {
      let result = try await requestData("signal", ["session_id": session.id, "kind": kind, "payload": payload, "nonce": UUID().uuidString])
      guard active, epoch == generation, self.session?.id == session.id else { return }; apply(result)
    } catch { if epoch == generation { self.error = error.localizedDescription } }
  }
  func leave() async { stopLocal(); _ = try? await requestData("leave") }
  func deactivate() { active = false; polling?.cancel(); polling = nil; stopLocal(); _ = enqueue("leave", [:]) }
  private func stopLocal() {
    generation += 1; state = "idle"; people = []; incoming = []; outgoing = nil; session = nil; messages = []; signals = []; iceServers = []; acknowledged = nil; acknowledging = false; preparingMedia = false; lastSignal = 0; busy = false; sending = false; allowsDirect = false; pendingMessage = nil; pendingRequest = nil
  }
  @discardableResult private func mutate(_ action: String, _ input: [String: Any]) async -> Bool {
    guard active, !busy else { return false }; busy = true; let epoch = generation; error = nil; notice = nil
    defer { if epoch == generation { busy = false } }
    do {
      let value = try await requestData(action, input)
      guard active, epoch == generation else { return false }; apply(value)
      if value.continueRoom != nil { notice = "Request sent to Inbox using your discovery names. They must accept before messaging continues." }
      return true
    } catch { if epoch == generation { self.error = error.localizedDescription }; return false }
  }
  private func prepare() async {
    let epoch = generation
    guard active, let session else { return }
    if state == "connecting", acknowledged != session.id, !acknowledging {
      acknowledging = true
      defer { if epoch == generation { acknowledging = false } }
      do {
        let value = try await requestData("ack", ["session_id": session.id])
        guard active, epoch == generation, self.session?.id == session.id else { return }
        acknowledged = session.id; apply(value)
      } catch {
        guard epoch == generation else { return }
        // The admission wrapper's deadlock backstop (code "retry", HTTP 400) is transient: keep the session and acknowledge again on the next heartbeat.
        if (error as? SocialServiceError)?.code == "retry" { return }
        self.error = error.localizedDescription; stopLocal(); _ = enqueue("leave", [:]); return
      }
    }
    guard active, epoch == generation, state == "connected", acknowledged == session.id, iceServers.isEmpty, !preparingMedia else { return }
    preparingMedia = true; defer { if epoch == generation { preparingMedia = false } }
    do {
      let value = try await requestData("media", ["session_id": session.id, "allow_direct": allowsDirect])
      guard active, epoch == generation, self.session?.id == session.id else { return }
      apply(value); iceServers = value.iceServers ?? []
    } catch { if epoch == generation { self.error = error.localizedDescription; stopLocal(); _ = enqueue("leave", [:]) } }
  }
  private func apply(_ value: DiscoveryResponse) {
    profile = value.profile; state = value.state; people = value.people ?? []; incoming = value.incoming ?? []; outgoing = value.outgoing
    if session?.id != value.session?.id { acknowledged = nil; lastSignal = 0; signals = []; messages = []; iceServers = []; pendingMessage = nil; pendingRequest = nil }
    session = value.session; transport = value.mediaTransport ?? "direct"; messages = value.messages ?? []
    let seen = Set(signals.map(\.id)); signals.append(contentsOf: (value.signals ?? []).filter { !seen.contains($0.id) }); lastSignal = max(lastSignal, signals.map(\.id).max() ?? 0)
    if state != "connected" { iceServers = [] }
  }
  private func requestData(_ action: String, _ input: [String: Any] = [:]) async throws -> DiscoveryResponse { try await enqueue(action, input).value }
  private func enqueue(_ action: String, _ input: [String: Any]) -> Task<DiscoveryResponse, Error> {
    let previous = tail, epoch = generation
    // Cleanup deliberately stays ordered behind in-flight work. Everything else
    // must still belong to this active foreground generation before dispatch.
    let cleanup = ["leave", "block", "report"].contains(action)
    let task = Task { @MainActor [self] in
      await previous?.value
      guard cleanup || (active && epoch == generation && !Task.isCancelled) else { throw CancellationError() }
      var payload = input; payload["instance"] = instance; payload["after_signal"] = lastSignal
      return try JSONDecoder().decode(DiscoveryResponse.self, from: await sendRequest(action, payload))
    }
    tail = Task { _ = try? await task.value }; return task
  }
}
