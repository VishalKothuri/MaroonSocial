import Foundation
import os
import Realtime

/// The `realtime.token` answer. `realtime: false` means "keep polling": the server has no
/// signing key yet (or the realtime migration is not applied).
struct RealtimeGrant: Decodable, Equatable {
  var realtime: Bool
  var token: String? = nil
  /// Seconds since 1970 (server clock).
  var expiresAt: Double? = nil
  /// The token's lifetime in seconds. The refresh is timed from it on this device's clock, so a
  /// device clock that is off cannot let the token lapse before it is refreshed.
  var expiresIn: Double? = nil
  var member: String? = nil
  enum CodingKeys: String, CodingKey { case realtime, token, member, expiresAt = "expires_at", expiresIn = "expires_in" }
}

/// A server poke: ids and a sequence only, never message content. The store answers it with
/// `room.messages after_seq` (or a snapshot for a room it does not hold yet).
struct RealtimePoke: Equatable, Sendable {
  enum Kind: String, Sendable, CaseIterable {
    /// A new message in a room (`room:<id>` topic).
    case message
    /// Something for this member's inbox (`member:<uuid>` topic): a new message, an invitation,
    /// an answered request or a ringing call.
    case inbox
    /// A held message changed (edit, deletion, reaction), or the room itself did (an answered
    /// request, a membership change, a call ringing, answered or ended), in an open room.
    case change
    /// Someone started typing in an open room.
    case typing
    /// Local only: pokes flow again after the member channel (re)joined — or, with a room, after
    /// that room's channel did — so open rooms catch up on whatever was sent meanwhile
    /// (broadcasts are not replayed).
    case resync
    static var broadcastEvents: [Kind] { [.message, .inbox, .change, .typing] }
  }
  var kind: Kind
  var room: String? = nil
  var seq: Int? = nil
}

/// The socket under `RealtimeService`; tests substitute a fake.
@MainActor protocol RealtimeSocket: AnyObject {
  /// Joins a private topic and delivers its pokes. Throws when the join is refused. After the join,
  /// `onStatus` reports each change of the channel's subscription (`false` while the library
  /// rejoins it after a reconnect or once the server closed it, `true` when it is subscribed again).
  func join(_ topic: String, onPoke: @escaping @MainActor (RealtimePoke) -> Void, onStatus: @escaping @MainActor (Bool) -> Void) async throws
  func leave(_ topic: String) async
  /// Pushes a refreshed token to the joined channels.
  func setAuth(_ token: String) async
  /// `true` while the WebSocket is connected; yields the current state first.
  func statusUpdates() -> AsyncStream<Bool>
  func disconnect() async
}

/// Supabase Realtime pokes for DMs, the inbox and game-day chat (caching phase 3).
///
/// One WebSocket and at most three private channels: `member:<uuid>` while the app is active, and
/// `room:<id>` for (at most two) open chats. Pokes flow while the socket is connected and the member
/// channel is subscribed. Whenever they start flowing again (a reconnect, a rejoin) the store gets a
/// `.resync` and catches up. After 10 s without them `connected` turns false and the store polls; a
/// member channel the socket cannot get back within 10 s (refused or closed by the server), or a
/// socket that stays down for a minute, ends the session and a new one starts. A room channel that
/// is away drops out of `joinedRooms`, so its chat polls until it is back. A `{realtime: false}`
/// grant keeps the app on polling and is asked again every ten minutes. Inert in fixture mode
/// (`--uitesting`). Tokens are never logged.
@Observable @MainActor final class RealtimeService {
  enum Mode: String { case inert, polling, realtime }
  /// Delays, injectable for tests.
  struct Timing: Sendable {
    /// A join not confirmed by then counts as refused.
    var joinTimeout: Duration = .seconds(10)
    /// Without pokes for this long (socket down, member channel away) the store polls again; a
    /// member channel still away after this long while the socket is up ends the session.
    var fallback: Duration = .seconds(10)
    /// A socket still down after this long ends the session (the library does not reconnect after
    /// an application close code).
    var socketGrace: Duration = .seconds(60)
    /// The pause before a new session after a lost one.
    var lostRetry: Duration = .seconds(10)
    /// How often the loss watchdog looks.
    var tick: Duration = .seconds(1)
  }
  private(set) var mode: Mode
  /// Pokes are flowing; open rooms and the inbox need no polling.
  var connected: Bool { mode == .realtime }
  /// Rooms whose channel is joined and subscribed.
  private(set) var joinedRooms: Set<String> = []
  var onPoke: (@MainActor (RealtimePoke) -> Void)?

  static let maxRooms = 2
  /// Refresh the token this long before it expires.
  static let refreshLead: TimeInterval = 300
  /// The refresh loop also wakes this often to notice an account switch.
  static let identityCheckInterval: TimeInterval = 30
  static let unavailableRetry: Duration = .seconds(600)
  static let failureRetry: Duration = .seconds(120)
  static let refusedRetry: Duration = .seconds(300)

  private let timing: Timing
  private let grant: @MainActor () async throws -> RealtimeGrant
  private let makeSocket: @MainActor (_ token: @escaping @Sendable () async -> String?) -> RealtimeSocket
  private let identity: @MainActor () -> Int
  private let sleep: @MainActor (Duration) async throws -> Void
  private let now: @MainActor () -> Date
  private var socket: RealtimeSocket?
  private var token: String?
  private var tokenIdentity: Int?
  private var memberJoined = false
  /// Live state of the current session: pokes flow while both are true.
  private var socketUp = false
  private var memberSubscribed = false
  /// Pokes stopped since the session's first join; the store catches up when they flow again.
  private var catchUpPending = false
  /// When the member channel went away while the socket was up.
  private var channelLostAt: ContinuousClock.Instant?
  /// Topics whose channel reported itself away (also during the moment between a join and its use).
  private var awayTopics: Set<String> = []
  private var lossTask: Task<Void, Never>?
  private var sessionLost = false
  private var followed: [String: Int] = [:]
  private var followOrder: [String] = []
  private var joiningRooms: Set<String> = []
  private var sessionTask: Task<Duration?, Never>?
  /// The current `run()`'s work; a new `run()` waits for a cancelled one to wind down first.
  private var activeRun: Task<Void, Never>?
  private var lastNote: String?
  private static let log = os.Logger(subsystem: "app.maroonsocial", category: "realtime")

  init(grant: @escaping @MainActor () async throws -> RealtimeGrant,
       makeSocket: @escaping @MainActor (_ token: @escaping @Sendable () async -> String?) -> RealtimeSocket,
       identity: @escaping @MainActor () -> Int = { 0 },
       sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
       now: @escaping @MainActor () -> Date = { .now },
       timing: Timing = Timing()) {
    mode = .polling
    self.grant = grant; self.makeSocket = makeSocket; self.identity = identity; self.sleep = sleep; self.now = now; self.timing = timing
  }
  private init() {
    mode = .inert
    grant = { RealtimeGrant(realtime: false) }
    makeSocket = { _ in InertSocket() }
    identity = { 0 }; sleep = { try await Task.sleep(for: $0) }; now = { .now }; timing = Timing()
  }
  /// Fixture mode and UI tests: never connects, never pokes.
  static func inert() -> RealtimeService { RealtimeService() }
  /// The app's service: Supabase Realtime at `<url>/realtime/v1` with the publishable key, tokens
  /// from the `social` edge function. Without a backend configuration it stays inert.
  static func live(social: SocialService) -> RealtimeService {
    guard let configURL = Bundle.main.url(forResource: "Backend", withExtension: "json"),
      let data = try? Data(contentsOf: configURL),
      let config = try? JSONDecoder().decode(BackendConfig.self, from: data) else { return .inert() }
    return RealtimeService(
      grant: { [weak social] in
        guard let social else { throw CancellationError() }
        return try await social.realtimeGrant()
      },
      makeSocket: { token in SupabaseRealtimeSocket(url: config.url, apiKey: config.publishableKey, accessToken: token) },
      identity: { [weak social] in social?.identityRevision ?? -1 })
  }

  /// Pokes arrive for this room (its channel is subscribed and pokes are flowing).
  func receives(room: String) -> Bool { connected && joinedRooms.contains(room) }

  /// Seconds until the token should be refreshed: five minutes before it expires, at least 30 s.
  static func refreshDelay(expiresAt: Double, now: Date) -> TimeInterval {
    max(30, expiresAt - refreshLead - now.timeIntervalSince1970)
  }

  /// Runs until the calling task is cancelled (the app leaves the foreground). A call while an
  /// earlier, cancelled run is still winding down (a join or teardown in flight) takes over once
  /// it has finished instead of returning, so a quick background/foreground keeps realtime.
  func run() async {
    guard mode != .inert else { return }
    let previous = activeRun
    previous?.cancel()
    let body = Task { [weak self] in
      await previous?.value
      guard !Task.isCancelled, let self else { return }
      await self.loop()
    }
    activeRun = body
    await withTaskCancellationHandler { await body.value } onCancel: { body.cancel() }
    if activeRun == body { activeRun = nil }
  }
  /// Drops the current connection and starts over (account switch or deletion).
  func restart() {
    guard mode != .inert else { return }
    sessionTask?.cancel()
  }

  func follow(_ room: String) {
    guard mode != .inert else { return }
    followed[room, default: 0] += 1
    guard followed[room] == 1 else { return }
    followOrder.removeAll { $0 == room }; followOrder.append(room)
    Task { await syncRoomChannels() }
  }
  func unfollow(_ room: String) {
    guard mode != .inert, let count = followed[room] else { return }
    if count > 1 { followed[room] = count - 1; return }
    followed.removeValue(forKey: room); followOrder.removeAll { $0 == room }
    Task { await syncRoomChannels() }
  }

  private func loop() async {
    while !Task.isCancelled {
      sessionLost = false
      let task = Task { await self.session() }
      sessionTask = task
      var retry = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
      sessionTask = nil
      await teardown()
      if Task.isCancelled { break }
      if sessionLost { retry = timing.lostRetry }
      guard let retry else { continue }
      do { try await sleep(retry) } catch { break }
    }
    await teardown()
  }

  /// One connection: grant, member channel, room channels, then token refreshes until something
  /// fails. Returns the delay before the next attempt (nil: start over now).
  private func session() async -> Duration? {
    let revision = identity()
    let first: RealtimeGrant
    do { first = try await grant() } catch {
      if Task.isCancelled { return nil }
      note("Realtime token request failed; polling.")
      return Self.failureRetry
    }
    if Task.isCancelled || identity() != revision { return nil }
    guard first.realtime, let token = first.token, !token.isEmpty, let member = first.member, var expiresAt = localExpiry(first) else {
      note("Realtime unavailable on the server; polling.")
      return Self.unavailableRetry
    }
    self.token = token; tokenIdentity = revision
    let socket = makeSocket { [weak self] in await self?.currentToken }
    self.socket = socket
    let memberTopic = "member:" + member
    let joined = await join(socket, memberTopic) { [weak self, weak socket] up in
      guard let socket else { return }
      self?.channelStatus(memberTopic, up: up, on: socket)
    }
    guard joined else {
      if Task.isCancelled { return nil }
      note("Realtime join refused or timed out; polling.")
      return Self.refusedRetry
    }
    memberJoined = true; socketUp = true; memberSubscribed = !awayTopics.contains(memberTopic)
    setMode(.realtime)
    onPoke?(RealtimePoke(kind: .resync))
    if !memberSubscribed { evaluate() }
    await syncRoomChannels()
    let statuses = socket.statusUpdates()
    let watcher = Task { [weak socket] in
      for await up in statuses {
        guard let socket else { return }
        self.socketStatus(up, on: socket)
      }
    }
    defer { watcher.cancel() }
    var refreshAt = expiresAt - Self.refreshLead
    while !Task.isCancelled {
      let wait = min(Self.identityCheckInterval, max(1, refreshAt - now().timeIntervalSince1970))
      do { try await sleep(.milliseconds(Int(wait * 1000))) } catch { return nil }
      if identity() != revision { return nil }
      guard now().timeIntervalSince1970 >= refreshAt else { continue }
      let next = try? await grant()
      if Task.isCancelled || identity() != revision { return nil }
      guard let next, next.realtime, let fresh = next.token, !fresh.isEmpty, next.member == member, let nextExpiry = localExpiry(next) else {
        // Keep the current token while it lasts; try again in 30 s.
        if now().timeIntervalSince1970 >= expiresAt - 30 { note("Realtime token refresh failed; polling."); return Self.failureRetry }
        refreshAt = now().timeIntervalSince1970 + 30
        continue
      }
      self.token = fresh; expiresAt = nextExpiry; refreshAt = Self.refreshDelay(expiresAt: nextExpiry, now: now()) + now().timeIntervalSince1970
      // Realtime re-checks every joined channel's policy with the new token.
      await socket.setAuth(fresh)
    }
    return nil
  }
  /// The socket asks for the token on every join; a token from a previous account is never reused.
  private var currentToken: String? { tokenIdentity == identity() ? token : nil }
  /// The grant's expiry on this device's clock (`expires_in` from now); older servers send only
  /// the server-clock `expires_at`.
  private func localExpiry(_ grant: RealtimeGrant) -> Double? {
    if let lifetime = grant.expiresIn, lifetime > 0 { return now().timeIntervalSince1970 + lifetime }
    return grant.expiresAt
  }

  /// Joins within `joinTimeout`; a cancelled caller (the session ending) stops waiting at once.
  private func join(_ socket: RealtimeSocket, _ topic: String, onStatus: @escaping @MainActor (Bool) -> Void) async -> Bool {
    let box = JoinBox()
    let timeout = timing.joinTimeout
    return await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        box.continuation = continuation
        guard !Task.isCancelled else { box.finish(false); return }
        box.attempt = Task {
          do {
            try await socket.join(topic, onPoke: { [weak self] poke in self?.onPoke?(poke) }, onStatus: onStatus)
            box.finish(true)
          } catch { box.finish(false) }
        }
        box.timer = Task {
          try? await Task.sleep(for: timeout)
          guard !Task.isCancelled else { return }
          box.attempt?.cancel(); box.finish(false)
        }
      }
    } onCancel: {
      Task { @MainActor in box.attempt?.cancel(); box.finish(false) }
    }
  }
  private var desiredRooms: Set<String> { Set(followOrder.suffix(Self.maxRooms)) }
  private func syncRoomChannels() async {
    guard memberJoined, let socket else { return }
    let desired = desiredRooms
    for room in joinedRooms.subtracting(desired) {
      joinedRooms.remove(room)
      await socket.leave("room:" + room)
    }
    for room in desired.subtracting(joinedRooms).subtracting(joiningRooms).sorted() {
      let topic = "room:" + room
      joiningRooms.insert(room); awayTopics.remove(topic)
      let joined = await join(socket, topic) { [weak self, weak socket] up in
        guard let socket else { return }
        self?.channelStatus(topic, up: up, on: socket)
      }
      joiningRooms.remove(room)
      guard self.socket === socket else { return }
      if joined, desiredRooms.contains(room), !awayTopics.contains(topic) {
        joinedRooms.insert(room)
        // A message sent between the chat's first read and this join produced no poke here.
        onPoke?(RealtimePoke(kind: .resync, room: room))
      } else if joined { await socket.leave("room:" + room) }
    }
  }
  /// A joined channel's subscription changed (see `RealtimeSocket.join`).
  private func channelStatus(_ topic: String, up: Bool, on socket: RealtimeSocket) {
    guard self.socket === socket else { return }
    if up { awayTopics.remove(topic) } else { awayTopics.insert(topic) }
    guard memberJoined else { return }
    if topic.hasPrefix("member:") {
      memberSubscribed = up
      evaluate()
    } else if topic.hasPrefix("room:") {
      roomStatus(String(topic.dropFirst(5)), up: up)
    }
  }
  /// A room channel that is away (rejoining after a reconnect, or closed by the server) leaves
  /// `joinedRooms`, so its chat polls; when it is subscribed again the room catches up.
  private func roomStatus(_ room: String, up: Bool) {
    if up {
      guard desiredRooms.contains(room), !joiningRooms.contains(room), joinedRooms.insert(room).inserted else { return }
      onPoke?(RealtimePoke(kind: .resync, room: room))
    } else {
      joinedRooms.remove(room)
    }
  }
  private func socketStatus(_ up: Bool, on socket: RealtimeSocket) {
    guard self.socket === socket, memberJoined, up != socketUp else { return }
    socketUp = up
    // The library reports the socket connected before it rejoins the channels: pokes flow again
    // (and the catch-up must run) only once the member channel is subscribed on the new socket.
    if !up { memberSubscribed = false }
    evaluate()
  }
  /// Called on every socket or member-channel change.
  private func evaluate() {
    if socketUp && memberSubscribed {
      lossTask?.cancel(); lossTask = nil; channelLostAt = nil
      guard catchUpPending else { return }
      catchUpPending = false
      setMode(.realtime)
      // Broadcasts sent while the channel was away are not replayed: fetch what was missed.
      onPoke?(RealtimePoke(kind: .resync))
      return
    }
    catchUpPending = true
    channelLostAt = socketUp ? (channelLostAt ?? .now) : nil
    if lossTask == nil { lossTask = Task { await self.watchLoss() } }
  }
  /// While pokes are not flowing: poll after `fallback`; end the session when the member channel
  /// stays away on a connected socket, or the socket stays down past `socketGrace`.
  private func watchLoss() async {
    let start = ContinuousClock.now
    while !Task.isCancelled {
      do { try await Task.sleep(for: timing.tick) } catch { return }
      guard !Task.isCancelled, lossTask != nil else { return }
      let down = ContinuousClock.now - start
      if mode == .realtime, down >= timing.fallback {
        setMode(.polling, reason: socketUp ? "member channel lost" : "socket down for more than 10 s")
      }
      let channelDown = channelLostAt.map { ContinuousClock.now - $0 } ?? .zero
      if channelDown >= timing.fallback || down >= timing.socketGrace {
        lossTask = nil
        sessionLost = true
        sessionTask?.cancel()
        return
      }
    }
  }
  private func teardown() async {
    lossTask?.cancel(); lossTask = nil; channelLostAt = nil; catchUpPending = false; awayTopics = []
    joinedRooms = []; joiningRooms = []; memberJoined = false; memberSubscribed = false; socketUp = false
    token = nil; tokenIdentity = nil
    if let socket { self.socket = nil; await socket.disconnect() }
    if mode == .realtime { setMode(.polling, reason: "disconnected") }
  }
  private func setMode(_ next: Mode, reason: String? = nil) {
    guard next != mode else { return }
    mode = next
    switch next {
    case .realtime: Self.log.notice("Realtime pokes active; room polling paused."); lastNote = nil
    case .polling: Self.log.notice("Realtime off (\(reason ?? "unavailable", privacy: .public)); polling.")
    case .inert: break
    }
  }
  /// Logs a reason for staying on polling once (not on every retry).
  private func note(_ message: String) {
    guard message != lastNote else { return }
    lastNote = message
    Self.log.notice("\(message, privacy: .public)")
  }
}

@MainActor private final class JoinBox {
  var continuation: CheckedContinuation<Bool, Never>?
  var attempt: Task<Void, Never>?
  var timer: Task<Void, Never>?
  func finish(_ value: Bool) {
    guard let continuation else { return }
    self.continuation = nil
    timer?.cancel()
    continuation.resume(returning: value)
  }
}

@MainActor private final class InertSocket: RealtimeSocket {
  func join(_ topic: String, onPoke: @escaping @MainActor (RealtimePoke) -> Void, onStatus: @escaping @MainActor (Bool) -> Void) async throws { throw CancellationError() }
  func leave(_ topic: String) async {}
  func setAuth(_ token: String) async {}
  func statusUpdates() -> AsyncStream<Bool> { AsyncStream { $0.finish() } }
  func disconnect() async {}
}

/// supabase-swift `RealtimeClientV2` behind `RealtimeSocket`: private broadcast channels only.
@MainActor final class SupabaseRealtimeSocket: RealtimeSocket {
  private let client: RealtimeClientV2
  private var channels: [String: (channel: RealtimeChannelV2, listeners: [Task<Void, Never>])] = [:]
  init(url: URL, apiKey: String, accessToken: @escaping @Sendable () async -> String?) {
    client = RealtimeClientV2(
      url: url.appending(path: "realtime/v1"),
      // Default retry ladder (5 attempts) for joins and the library's rejoins after a reconnect.
      options: RealtimeClientOptions(headers: ["apikey": apiKey], accessToken: { await accessToken() }, handleAppLifecycle: false))
  }
  func join(_ topic: String, onPoke: @escaping @MainActor (RealtimePoke) -> Void, onStatus: @escaping @MainActor (Bool) -> Void) async throws {
    if channels[topic] != nil { await leave(topic) }
    let channel = client.channel(topic) { $0.isPrivate = true }
    var listeners: [Task<Void, Never>] = []
    for kind in RealtimePoke.Kind.broadcastEvents {
      let stream = channel.broadcastStream(event: kind.rawValue)
      listeners.append(Task { @MainActor in
        for await message in stream {
          let payload = message["payload"]?.objectValue
          let seq = payload?["seq"]?.intValue ?? payload?["seq"]?.doubleValue.map { Int($0) }
          onPoke(RealtimePoke(kind: kind, room: payload?["room"]?.stringValue, seq: seq))
        }
      })
    }
    channels[topic] = (channel, listeners)
    do { try await channel.subscribeWithError() } catch { await leave(topic); throw error }
    guard channels[topic]?.channel === channel else { throw CancellationError() }
    // After the join the library resubscribes the channel after a reconnect (unsubscribed →
    // subscribing → subscribed) and drops it when the server closes it or sends an error. Only
    // changes are reported; the stream starts with the current (subscribed) state.
    let statuses = channel.statusChange
    channels[topic]?.listeners.append(Task { @MainActor in
      var subscribed = true
      for await status in statuses {
        let up = status == .subscribed
        guard up != subscribed else { continue }
        subscribed = up
        onStatus(up)
      }
    })
  }
  func leave(_ topic: String) async {
    guard let entry = channels.removeValue(forKey: topic) else { return }
    entry.listeners.forEach { $0.cancel() }
    await client.removeChannel(entry.channel)
  }
  func setAuth(_ token: String) async { await client.setAuth(token) }
  func statusUpdates() -> AsyncStream<Bool> {
    let source = client.statusChange
    return AsyncStream { continuation in
      let task = Task { for await status in source { continuation.yield(status == .connected) }; continuation.finish() }
      continuation.onTermination = { _ in task.cancel() }
    }
  }
  func disconnect() async {
    for entry in channels.values { entry.listeners.forEach { $0.cancel() } }
    channels = [:]
    await client.removeAllChannels()
    client.disconnect()
  }
}
