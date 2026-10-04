import Foundation
import Observation
import Security

struct RandomChatMessage: Decodable, Identifiable, Equatable {
  let id: Int
  let body: String
  let mine: Bool
  let createdAt: String
  enum CodingKeys: String, CodingKey { case id, body, mine; case createdAt = "created_at" }
}
struct RandomChatIceServer: Codable, Equatable {
  let urls: [String]
  let username: String?
  let credential: String?
}
struct RandomChatSignal: Decodable, Identifiable, Equatable {
  let id: Int
  let kind: String
  private let payload: ChatJSON
  var payloadJSON: String {
    guard let data = try? JSONEncoder().encode(payload) else { return "{}" }
    return String(decoding: data, as: UTF8.self)
  }
}
indirect enum ChatJSON: Codable, Equatable {
  case string(String), number(Double), bool(Bool), object([String: ChatJSON]), array([ChatJSON]), null
  init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() { self = .null }
    else if let v = try? c.decode(Bool.self) { self = .bool(v) }
    else if let v = try? c.decode(Double.self) { self = .number(v) }
    else if let v = try? c.decode(String.self) { self = .string(v) }
    else if let v = try? c.decode([String: ChatJSON].self) { self = .object(v) }
    else { self = .array(try c.decode([ChatJSON].self)) }
  }
  func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .null: try c.encodeNil()
    case .bool(let v): try c.encode(v)
    case .number(let v): try c.encode(v)
    case .string(let v): try c.encode(v)
    case .object(let v): try c.encode(v)
    case .array(let v): try c.encode(v)
    }
  }
}
private struct RandomChatResponse: Decodable {
  let state: String
  let room: String?
  let mode: String
  let initiator: Bool
  let messages: [RandomChatMessage]
  let signals: [RandomChatSignal]
  let token: String?
  let continueRoom: String?
  let continueStatus: String?
  let endReason: String?
  let reportID: String?
  let mediaEnabled: Bool?
  let mediaTransport: String?
  let call: Call?
  struct Call: Decodable {
    let iceServers: [RandomChatIceServer]
    let transport: String?
    enum CodingKeys: String, CodingKey { case iceServers = "ice_servers"; case transport }
  }
  enum CodingKeys: String, CodingKey {
    case state, room, mode, initiator, messages, signals, token, call
    case continueRoom = "continue_room", continueStatus = "continue_status"
    case endReason = "end_reason", reportID = "report_id", mediaEnabled = "media_enabled", mediaTransport = "media_transport"
  }
}
private struct RandomChatFailure: Decodable, Error, LocalizedError {
  let error: String
  let code: String?
  var errorDescription: String? { error }
}

/// Participant labels stay anonymous; eligibility, blocks and bans use the signed-in account.
@Observable @MainActor final class RandomChatService {
  enum State: String { case idle, waiting, connected, ended }
  var state: State = .idle
  var roomID: String?
  var mode = "text"
  var initiator = false
  var messages: [RandomChatMessage] = []
  var signals: [RandomChatSignal] = []
  var iceServers: [RandomChatIceServer] = []
  var mediaEnabled = false
  var mediaTransport = "relay"
  var callTransport = "relay"
  private(set) var allowsDirect = false
  var busy = false
  var sending = false
  var error: String?
  var notice: String?
  var reconnecting = false
  var endReason: String?
  var continueRoom: String?
  typealias Transport = (URLRequest) async throws -> (Data, URLResponse)
  private let transport: Transport
  private let credentialStore: any RandomChatCredentialStore
  private var memberRequest: (@MainActor (String, [String: Any]) async throws -> Data)?
  private let injectedTransport: Bool
  private var token: String?
  private var polling: Task<Void, Never>?
  private var generation = 0
  private let instanceID = UUID().uuidString
  private var requestTail: Task<Void, Never>?
  private var active = false
  private var loadingMedia = false
  private var localConversationStopped = false
  private var lastSignal = 0
  private var pendingMessage: (body: String, nonce: String)?

  init(transport: Transport? = nil, credentialStore: (any RandomChatCredentialStore)? = nil) {
    self.transport = transport ?? { try await URLSession.shared.data(for: $0) }
    self.injectedTransport = transport != nil
    let credentials = credentialStore ?? EmptyRandomCredentialStore()
    self.credentialStore = credentials
    self.token = credentials.read()
  }

  func bind(social: SocialService) {
    guard !active else { return }
    memberRequest = { action, input in try await social.sendData(endpoint: "random-chat", action: action, payload: input) }
  }

  func activate() async {
    guard !active else { return }
    active = true
    if let capabilities = try? await request("capabilities") {
      mediaEnabled = capabilities.mediaEnabled ?? false
      mediaTransport = capabilities.mediaTransport ?? "relay"
    }
    beginPolling()
  }

  func start(mode selectedMode: String = "text", allowDirect: Bool = false) async {
    guard !busy else { return }
    busy = true
    generation += 1
    let version = generation
    notice = nil
    error = nil
    allowsDirect = allowDirect
    let startAction = localConversationStopped && roomID != nil ? "next" : "join"
    var startPayload: [String: Any] = ["mode": selectedMode, "allow_direct": allowDirect]
    if startAction == "next", let roomID { startPayload["room"] = roomID }
    defer { busy = false }
    do {
      try await ensureCredential()
      guard active, version == generation else { return }
      let result: RandomChatResponse
      do {
        result = try await request(startAction, payload: startPayload)
      } catch let failure as RandomChatFailure where failure.code == "unauthorized" && memberRequest == nil {
        guard active, version == generation else { return }
        // Expired guest identities can be renewed; suspended identities never take this path.
        token = nil
        credentialStore.delete()
        try await ensureCredential()
        guard active, version == generation else { return }
        result = try await request("join", payload: ["mode": selectedMode, "allow_direct": allowDirect])
      }
      guard active, version == generation else { return }
      localConversationStopped = false
      mode = selectedMode
      apply(result)
      beginPolling()
    } catch { if active, version == generation { show(error) } }
  }

  func continueInInbox() async {
    guard active, !busy, let roomID else { return }
    busy = true; let epoch = generation; error = nil
    defer { if epoch == generation { busy = false } }
    do {
      let result = try await request("continue", payload: ["room": roomID])
      guard active, epoch == generation, self.roomID == roomID else { return }
      continueRoom = result.continueRoom
      notice = result.continueStatus == "active" ? "Your anonymous conversation is in Inbox." : "Request sent. They can accept in Inbox to keep chatting anonymously."
    } catch { if active, epoch == generation { show(error) } }
  }

  func next() async {
    guard !busy else { return }
    busy = true
    generation += 1
    let version = generation
    notice = nil
    error = nil
    stopLocalConversation()
    defer { busy = false }
    do {
      var payload: [String: Any] = ["mode": mode, "allow_direct": allowsDirect]
      if let roomID { payload["room"] = roomID }
      let result = try await request("next", payload: payload)
      guard active, version == generation else { return }
      localConversationStopped = false
      apply(result)
    } catch { if active, version == generation { show(error) } }
  }

  @discardableResult func send(_ body: String) async -> Bool {
    let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard state == .connected, let roomID, !sending, !text.isEmpty, text.count <= 2000 else { return false }
    sending = true
    generation += 1
    let version = generation
    error = nil
    defer { sending = false }
    // Preserve the nonce after a network failure; retry never creates a duplicate message.
    let nonce = pendingMessage?.body == text ? pendingMessage!.nonce : UUID().uuidString
    pendingMessage = (text, nonce)
    do {
      let result = try await request("send", payload: ["room": roomID, "body": text, "nonce": nonce])
      guard active, version == generation else { return false }
      apply(result)
      pendingMessage = nil
      return true
    } catch { if active, version == generation { show(error) }; return false }
  }

  func end() async {
    guard !busy else { return }
    busy = true
    generation += 1
    let version = generation
    stopLocalConversation()
    defer { busy = false }
    do {
      guard memberRequest != nil || token != nil else { state = .idle; return }
      var payload: [String: Any] = [:]
      if let roomID { payload["room"] = roomID }
      let result = try await request("leave", payload: payload)
      guard active, version == generation else { return }
      apply(result)
      if state == .waiting || state == .connected { state = .ended }
    } catch {
      guard active, version == generation else { return }
      state = .ended
      iceServers = []
      show(error)
    }
  }

  func block() async { await moderate(action: "block", reason: nil) }
  func report(reason: String) async { await moderate(action: "report", reason: reason) }

  private func moderate(action: String, reason: String?) async {
    guard !busy, let roomID else { return }
    busy = true
    generation += 1
    let version = generation
    stopLocalConversation()
    defer { busy = false }
    do {
      var payload: [String: Any] = ["room": roomID]
      if let reason { payload["reason"] = reason }
      let result = try await request(action, payload: payload)
      guard active, version == generation else { return }
      apply(result)
      notice = action == "report"
        ? "Report saved. This guest is blocked on this device."
        : "This guest is blocked on this device."
      error = nil
    } catch { if active, version == generation { show(error) } }
  }

  private func stopLocalConversation() {
    // User safety controls stop camera/microphone immediately, even when the
    // network request is slow or fails. SwiftUI removes the call view now.
    localConversationStopped = true
    state = .ended
    iceServers = []
  }

  func sendSignal(type: String, payload: String) async {
    guard state == .connected, mode != "text", let roomID,
      let data = payload.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data)
    else { return }
    let version = generation
    do {
      let result = try await request("signal", payload: [
        "room": roomID, "nonce": UUID().uuidString, "kind": type, "payload": json,
      ])
      if self.roomID == roomID, version == generation, active { apply(result) }
    } catch { if active, version == generation { show(error) } }
  }

  func refresh() async {
    guard token != nil, active, !busy, !sending else { return }
    let version = generation
    do {
      let result = try await request("poll")
      guard active, version == generation else { return }
      apply(result)
      if reconnecting { error = nil }
      reconnecting = false
    } catch {
      guard active, version == generation else { return }
      reconnecting = true
      show(error)
    }
  }

  /// Leaving the screen or backgrounding immediately ends matching and releases call media.
  func deactivate() {
    guard active else { return }
    active = false
    generation += 1
    polling?.cancel()
    polling = nil
    iceServers = []
    guard memberRequest != nil || token != nil || busy else { return }
    let oldRoom = roomID
    stopLocalConversation()
    notice = "You left the conversation."
    var payload: [String: Any] = [:]
    if let oldRoom { payload["room"] = oldRoom }
    // Enqueue synchronously, before a later screen can begin a new operation.
    _ = enqueue("leave", payload: payload)
  }

  private func beginPolling() {
    guard active, polling == nil else { return }
    polling = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .milliseconds(1500)) } catch { break }
        guard let self, self.active else { break }
        if self.state == .waiting || self.state == .connected { await self.refresh() }
      }
    }
  }

  private func ensureCredential() async throws {
    if memberRequest != nil { return }
    guard injectedTransport else { throw SocialServiceError(error: "Sign in before starting a conversation.", code: "unauthorized") }
    guard token == nil else { return }
    let result = try await request("register")
    guard let credential = result.token else { throw URLError(.userAuthenticationRequired) }
    token = credential
    mediaEnabled = result.mediaEnabled ?? false
    mediaTransport = result.mediaTransport ?? "relay"
  }

  private func apply(_ result: RandomChatResponse) {
    guard active else {
      if result.state == "connected" || result.state == "waiting" {
        Task { [weak self] in
          var payload: [String: Any] = [:]
          if let room = result.room { payload["room"] = room }
          _ = try? await self?.request("leave", payload: payload)
        }
      }
      return
    }
    let changedRoom = roomID != result.room
    let receivedState = State(rawValue: result.state) ?? .idle
    state = localConversationStopped && (receivedState == .connected || receivedState == .waiting)
      ? .ended : receivedState
    roomID = result.room
    mode = result.mode
    initiator = result.initiator
    messages = result.messages
    endReason = result.endReason
    mediaEnabled = result.mediaEnabled ?? false
    mediaTransport = result.mediaTransport ?? "relay"
    if changedRoom {
      signals = []
      lastSignal = 0
      iceServers = []
      pendingMessage = nil
      continueRoom = nil
    }
    for signal in result.signals where !signals.contains(where: { $0.id == signal.id }) {
      signals.append(signal)
      lastSignal = max(lastSignal, signal.id)
    }
    if let call = result.call {
      iceServers = call.iceServers
      callTransport = call.transport == "direct" && allowsDirect ? "direct" : "relay"
    }
    if state != .connected { iceServers = [] }
    if state == .connected, mode != "text", iceServers.isEmpty, !loadingMedia {
      loadingMedia = true
      let callRoom = roomID
      let version = generation
      Task { [weak self] in
        guard let self else { return }
        defer { if self.generation == version { self.loadingMedia = false } }
        do {
          let response = try await self.request("media", payload: ["room": callRoom ?? "", "allow_direct": self.allowsDirect])
          if self.active, self.generation == version, self.roomID == callRoom, self.state == .connected {
            self.iceServers = response.call?.iceServers ?? []
            self.callTransport = response.call?.transport == "direct" && self.allowsDirect ? "direct" : "relay"
          }
        } catch {
          if self.active, self.generation == version, self.roomID == callRoom, self.state == .connected { self.show(error) }
        }
      }
    }
  }

  private func show(_ failure: Error) {
    if failure is CancellationError { return }
    if let failure = failure as? RandomChatFailure {
      error = failure.error
      if failure.code == "unauthorized" {
        token = nil
        credentialStore.delete()
        state = .idle
        roomID = nil
        messages = []
        signals = []
        iceServers = []
      }
    }
    else if let failure = failure as? SocialServiceError {
      error = failure.localizedDescription
      if ["unauthorized", "forbidden", "verification_required", "account_deleted"].contains(failure.code ?? "") { stopLocalConversation(); state = .ended }
    }
    else if let failure = failure as? ChatCredentialError { error = failure.localizedDescription }
    else { error = "Couldn’t reach chat. Check your connection and try again." }
  }

  private func request(_ action: String, payload: [String: Any] = [:]) async throws -> RandomChatResponse {
    try await enqueue(action, payload: payload).value
  }

  private func enqueue(_ action: String, payload: [String: Any]) -> Task<RandomChatResponse, Error> {
    let previous = requestTail
    let task = Task { @MainActor [self] in
      await previous?.value
      return try await performRequest(action, payload: payload)
    }
    requestTail = Task { _ = try? await task.value }
    return task
  }

  private func performRequest(_ action: String, payload: [String: Any]) async throws -> RandomChatResponse {
    if let memberRequest {
      var input = payload; input["instance"] = instanceID; input["after_signal"] = lastSignal
      return try JSONDecoder().decode(RandomChatResponse.self, from: await memberRequest(action, input))
    }
    guard injectedTransport else { throw SocialServiceError(error: "Sign in before starting a conversation.", code: "unauthorized") }
    guard let url = Bundle.main.url(forResource: "Backend", withExtension: "json") else {
      throw URLError(.badURL)
    }
    let config = try JSONDecoder().decode(BackendConfig.self, from: Data(contentsOf: url))
    var request = URLRequest(url: config.url.appending(path: "functions/v1/random-chat"))
    request.httpMethod = "POST"
    request.timeoutInterval = 18
    request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let token { request.setValue(token, forHTTPHeaderField: "X-Chat-Token") }
    var body = payload
    body["action"] = action
    body["instance"] = instanceID
    body["after_signal"] = lastSignal
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await transport(request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      if let failure = try? JSONDecoder().decode(RandomChatFailure.self, from: data) { throw failure }
      throw URLError(.badServerResponse)
    }
    let result = try JSONDecoder().decode(RandomChatResponse.self, from: data)
    if action == "register", let credential = result.token {
      // Persist before resolving this operation so queued cleanup can authenticate.
      try credentialStore.save(credential)
      token = credential
    }
    return result
  }
}

@MainActor protocol RandomChatCredentialStore {
  func read() -> String?
  func save(_ token: String) throws
  func delete()
}

struct ChatCredentialError: Error, LocalizedError {
  let status: OSStatus
  var errorDescription: String? {
    "This app install couldn’t save a secure chat session (\(status)). Please reinstall a signed build."
  }
}

@MainActor private final class KeychainChatCredentialStore: RandomChatCredentialStore {
  private let service = "com.maroonsocial.randomchat"
  private let account = "guest-session-v1"
  private var query: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
     kSecAttrAccount as String: account]
  }
  func read() -> String? {
    var q = query
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }
  func delete() { SecItemDelete(query as CFDictionary) }
  func save(_ token: String) throws {
    var q = query
    q[kSecValueData as String] = Data(token.utf8)
    q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(q as CFDictionary, nil)
    guard status == errSecSuccess else { throw ChatCredentialError(status: status) }
  }
}

@MainActor private struct EmptyRandomCredentialStore: RandomChatCredentialStore {
  func read() -> String? { nil }
  func save(_ token: String) throws {}
  func delete() {}
}
