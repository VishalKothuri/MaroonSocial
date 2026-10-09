import XCTest
import MaroonCore
@testable import MaroonSocial

/// Caching phase 3: Realtime pokes replace room polling; game-day chat stays small and in memory.
@MainActor final class RealtimePokeTests: XCTestCase {
  private var directories: [URL] = []
  override func tearDown() {
    directories.forEach { try? FileManager.default.removeItem(at: $0) }
    directories = []
    super.tearDown()
  }
  private func credentials() -> SocialCredentialStore {
    SocialCredentialStore(read: { String(repeating: "a", count: 64) }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {})
  }
  private func file() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    directories.append(directory)
    return directory.appending(path: "social-cache.json")
  }
  private func networkStore(_ transport: @escaping SocialService.Transport) throws -> AppStore {
    let store = AppStore(storageURL: try file(), arguments: [], socialService: SocialService(credentials: credentials(), transport: transport), realtime: .inert())
    store.state.username = "poke_tester"; store.state.onboarded = true; store.connected = true
    return store
  }
  private func message(_ sequence: Int) -> [String: Any] {
    ["id": "m\(sequence)", "author": "Them", "text": "Message \(sequence)", "created": 1_000 + sequence, "sequence": sequence]
  }
  private func meta(_ id: String, kind: String = "dm") -> [String: Any] {
    ["id": id, "kind": kind, "status": "active", "role": "member", "canSend": true, "unread": 0, "lastRead": 0, "pendingOutgoing": false]
  }
  private func snapshot(conversations: [[String: Any]], meta: [[String: Any]] = []) throws -> Data {
    try JSONSerialization.data(withJSONObject: ["snapshot": ["username": "poke_tester", "nsfwEnabled": false, "posts": [], "courses": [], "activities": [],
      "conversations": conversations, "ownPostIDs": [], "ownCommentIDs": [], "ownMessageIDs": [], "conversationMeta": meta,
      "attachments": [], "organizations": [], "savedEvents": [], "serverNow": 500]])
  }
  private func room(_ id: String, _ sequences: ClosedRange<Int>) -> [String: Any] {
    ["id": id, "title": id, "subtitle": "", "request": false, "anonymous": false, "messages": sequences.map(message)]
  }

  func testEachPokeRequestsOneAfterSequencePageAndMergesWithoutDuplicates() async throws {
    var afterSequences: [Int] = []
    var snapshots = 0
    var latest = 3
    let store = try networkStore { [self] _, action, payload, _ in
      if action == "snapshot" { snapshots += 1; return try snapshot(conversations: [room("room-1", 1...3)], meta: [meta("room-1")]) }
      XCTAssertEqual(action, "room.messages")
      XCTAssertEqual(payload["room_id"] as? String, "room-1")
      let after = try XCTUnwrap(payload["after_seq"] as? Int)
      afterSequences.append(after)
      // The page repeats the cursor's message once: merging must not duplicate it.
      let page = (after...latest).map(message)
      return try JSONSerialization.data(withJSONObject: ["room_id": "room-1", "messages": page, "more": false, "meta": meta("room-1"), "now": 600])
    }
    await store.refresh()
    XCTAssertEqual(snapshots, 1)

    latest = 4
    await store.receive(RealtimePoke(kind: .message, room: "room-1", seq: 4))
    // The inbox poke for the same message is already held: no second request.
    await store.receive(RealtimePoke(kind: .inbox, room: "room-1", seq: 4))
    latest = 5
    await store.receive(RealtimePoke(kind: .message, room: "room-1", seq: 5))
    latest = 6
    await store.receive(RealtimePoke(kind: .inbox, room: "room-1", seq: 6))
    XCTAssertEqual(afterSequences, [3, 4, 5], "exactly one room.messages after_seq request per new poke")
    XCTAssertEqual(store.state.conversations.first?.messages.compactMap(\.sequence), [1, 2, 3, 4, 5, 6])
    XCTAssertEqual(Set(store.state.conversations.first?.messages.map(\.id) ?? []).count, 6, "no duplicates")
    XCTAssertEqual(store.state.roomCursors?["room-1"], 6)

    // Stale pokes and pokes that only matter to an open chat fetch nothing.
    await store.receive(RealtimePoke(kind: .message, room: "room-1", seq: 2))
    await store.receive(RealtimePoke(kind: .change, room: "room-1"))
    await store.receive(RealtimePoke(kind: .typing, room: "room-1"))
    XCTAssertEqual(afterSequences, [3, 4, 5])
    // A room this device does not hold yet (a new request) is picked up by one snapshot.
    await store.receive(RealtimePoke(kind: .inbox, room: "room-new", seq: 1))
    XCTAssertEqual(snapshots, 2)
    XCTAssertEqual(afterSequences, [3, 4, 5])
  }

  func testPokesQueuedTogetherStillCostOneRequestEach() async throws {
    var afterSequences: [Int] = []
    let store = try networkStore { [self] _, action, payload, _ in
      if action == "snapshot" { return try snapshot(conversations: [room("room-1", 1...3)], meta: [meta("room-1")]) }
      let after = try XCTUnwrap(payload["after_seq"] as? Int)
      afterSequences.append(after)
      return try JSONSerialization.data(withJSONObject: ["room_id": "room-1", "messages": [message(after + 1)], "more": false])
    }
    await store.refresh()
    // A room poke and the inbox poke for the same message arrive back to back.
    store.enqueue(RealtimePoke(kind: .message, room: "room-1", seq: 4))
    store.enqueue(RealtimePoke(kind: .inbox, room: "room-1", seq: 4))
    await store.receive(RealtimePoke(kind: .message, room: "room-1", seq: 5))
    XCTAssertEqual(afterSequences, [3, 4])
    XCTAssertEqual(store.state.conversations.first?.messages.compactMap(\.sequence), [1, 2, 3, 4, 5])
  }

  func testTokenEndpointWithoutRealtimeKeepsPolling() async throws {
    var actions: [String] = []
    let social = SocialService(credentials: credentials(), transport: { _, action, _, _ in
      actions.append(action)
      return try JSONSerialization.data(withJSONObject: ["realtime": false])
    })
    let grant = try await social.realtimeGrant()
    XCTAssertEqual(grant, RealtimeGrant(realtime: false))
    var sockets = 0
    var sleeps: [Duration] = []
    let service = RealtimeService(grant: { try await social.realtimeGrant() }, makeSocket: { _ in sockets += 1; return FakeSocket() },
      sleep: { duration in sleeps.append(duration); throw CancellationError() })
    await service.run()
    XCTAssertEqual(actions, ["realtime.token", "realtime.token"])
    XCTAssertEqual(sockets, 0, "no socket without a token")
    XCTAssertEqual(service.mode, .polling)
    XCTAssertFalse(service.connected)
    XCTAssertFalse(service.receives(room: "room-1"))
    XCTAssertEqual(sleeps, [RealtimeService.unavailableRetry], "asks again later instead of hammering")

    // The store keeps its polling: an inert or polling service never claims a room.
    let store = AppStore(storageURL: try file(), arguments: [], socialService: social, realtime: service)
    XCTAssertFalse(store.realtime.receives(room: "room-1"))
  }

  func testRefusedJoinFallsBackToPolling() async {
    let socket = FakeSocket(); socket.refuse = true
    var sleeps: [Duration] = []
    let service = RealtimeService(grant: { RealtimeGrant(realtime: true, token: "token-a", expiresAt: Date.now.timeIntervalSince1970 + 3600, member: "member-1") },
      makeSocket: { _ in socket }, sleep: { duration in sleeps.append(duration); throw CancellationError() })
    await service.run()
    XCTAssertEqual(socket.joined, [])
    XCTAssertTrue(socket.disconnected)
    XCTAssertEqual(service.mode, .polling)
    XCTAssertEqual(sleeps, [RealtimeService.refusedRetry])
  }

  func testTokenRefreshesFiveMinutesBeforeExpiry() async throws {
    XCTAssertEqual(RealtimeService.refreshDelay(expiresAt: 10_000 + 3600, now: Date(timeIntervalSince1970: 10_000)), 3300)
    XCTAssertEqual(RealtimeService.refreshDelay(expiresAt: 10_000 + 100, now: Date(timeIntervalSince1970: 10_000)), 30, "never sooner than 30 s")

    let start = 1_800_000_000.0
    var clock = start
    var grants = [RealtimeGrant(realtime: true, token: "token-a", expiresAt: start + 3600, member: "member-1"),
      RealtimeGrant(realtime: true, token: "token-b", expiresAt: start + 7200, member: "member-1")]
    var grantTimes: [Double] = []
    let socket = FakeSocket()
    let refreshed = expectation(description: "setAuth")
    var refreshedOnce = false
    socket.onSetAuth = { _ in if !refreshedOnce { refreshedOnce = true; refreshed.fulfill() } }
    var tokenSeenBySocket: (@Sendable () async -> String?)?
    let service = RealtimeService(grant: { grantTimes.append(clock); return grants.count > 1 ? grants.removeFirst() : grants[0] },
      makeSocket: { token in tokenSeenBySocket = token; return socket },
      sleep: { duration in
        // A virtual clock until the first refresh, then a real (cancellable) wait.
        if refreshedOnce { try await Task.sleep(for: .seconds(3600)); return }
        try Task.checkCancellation()
        clock += Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        await Task.yield()
      },
      now: { Date(timeIntervalSince1970: clock) })
    let run = Task { await service.run() }
    await fulfillment(of: [refreshed], timeout: 10)
    XCTAssertEqual(socket.joined, ["member:member-1"])
    XCTAssertEqual(service.mode, .realtime)
    XCTAssertEqual(socket.tokens, ["token-b"])
    XCTAssertEqual(grantTimes.count, 2)
    let refreshAt = try XCTUnwrap(grantTimes.last)
    XCTAssertGreaterThanOrEqual(refreshAt, start + 3600 - 300)
    XCTAssertLessThan(refreshAt, start + 3600 - 300 + 31, "refreshed five minutes before expiry")
    let current = await tokenSeenBySocket?()
    XCTAssertEqual(current, "token-b", "a rejoin uses the refreshed token")
    run.cancel()
    await run.value
    XCTAssertTrue(socket.disconnected)
    XCTAssertEqual(service.mode, .polling)
  }

  func testOpenRoomsJoinAtMostTwoChannelsAndLeaveOnClose() async throws {
    let socket = FakeSocket()
    let service = RealtimeService(grant: { RealtimeGrant(realtime: true, token: "token-a", expiresAt: Date.now.timeIntervalSince1970 + 3600, member: "member-1") },
      makeSocket: { _ in socket }, sleep: { try await Task.sleep(for: $0) })
    var pokes: [RealtimePoke] = []
    service.onPoke = { pokes.append($0) }
    let run = Task { await service.run() }
    try await waitUntil { service.connected }
    XCTAssertEqual(pokes.first?.kind, .resync, "joining catches open rooms up")
    service.follow("room-1"); service.follow("room-2"); service.follow("room-3")
    try await waitUntil { service.joinedRooms == ["room-2", "room-3"] }
    XCTAssertFalse(service.receives(room: "room-1"), "a third open room keeps polling")
    service.unfollow("room-3")
    try await waitUntil { service.joinedRooms == ["room-1", "room-2"] }
    XCTAssertTrue(socket.left.contains("room:room-3"))
    socket.deliver(RealtimePoke(kind: .message, room: "room-1", seq: 9), on: "room:room-1")
    XCTAssertEqual(pokes.last, RealtimePoke(kind: .message, room: "room-1", seq: 9))
    run.cancel(); await run.value
    XCTAssertFalse(service.connected)
    XCTAssertTrue(service.joinedRooms.isEmpty)
  }

  func testInertServiceNeverConnects() async {
    let service = RealtimeService.inert()
    await service.run()
    service.follow("room-1")
    XCTAssertEqual(service.mode, .inert)
    XCTAssertFalse(service.receives(room: "room-1"))
    let fixtures = AppStore(storageURL: try? file(), arguments: ["--uitesting"])
    XCTAssertEqual(fixtures.realtime.mode, .inert, "UI tests run without realtime")
  }

  func testGameRoomKeepsTheLastFiftyMessagesAndIsNeverPersisted() async throws {
    let cache = try file()
    let store = AppStore(storageURL: cache, arguments: [], socialService: SocialService(credentials: credentials(), transport: { [self] _, action, payload, _ in
      if action == "snapshot" {
        return try snapshot(conversations: [room("sports:game-1", 1...50), room("room-1", 1...3)], meta: [meta("sports:game-1", kind: "sports"), meta("room-1")])
      }
      let after = try XCTUnwrap(payload["after_seq"] as? Int)
      return try JSONSerialization.data(withJSONObject: ["room_id": "sports:game-1", "messages": ((after + 1)...(after + 10)).map(message), "more": false,
        "meta": meta("sports:game-1", kind: "sports")])
    }), realtime: .inert())
    store.state.username = "poke_tester"; store.state.onboarded = true; store.connected = true
    await store.refresh()
    // Closed game rooms ignore pokes; an open one fetches and trims.
    await store.receive(RealtimePoke(kind: .message, room: "sports:game-1", seq: 51))
    XCTAssertEqual(store.state.conversations.first { $0.id == "sports:game-1" }?.messages.count, 50)
    await store.syncRoom("sports:game-1")
    let messages = try XCTUnwrap(store.state.conversations.first { $0.id == "sports:game-1" }?.messages)
    XCTAssertEqual(messages.compactMap(\.sequence), Array(11...60), "only the newest 50 stay in memory")
    XCTAssertFalse(store.hasEarlierMessages("sports:game-1"), "game chat never pages history in")

    XCTAssertTrue(store.save())
    let saved = try JSONDecoder().decode(LocalState.self, from: Data(contentsOf: cache))
    XCTAssertEqual(saved.conversations.first { $0.id == "sports:game-1" }?.messages, [], "game chat is not written to the cache")
    XCTAssertNil(saved.roomCursors?["sports:game-1"])
    XCTAssertEqual(saved.conversations.first { $0.id == "room-1" }?.messages.count, 3, "other rooms are still cached")
    XCTAssertEqual(AppStore.trimmedGameRoom((1...80).map { sequence in var value = Message(author: "Them", text: "\(sequence)"); value.sequence = sequence; return value }).count, 50)
  }

  /// A drop shorter than the 10 s fallback (supabase-swift reconnects after 7 s) keeps realtime on,
  /// and the catch-up runs only once the member channel is subscribed on the new socket — not when
  /// the socket merely reports connected. A room channel that is away polls until it is back.
  func testShortSocketDropCatchesUpAfterTheMemberChannelRejoins() async throws {
    let socket = FakeSocket()
    let service = RealtimeService(grant: { RealtimeGrant(realtime: true, token: "token-a", expiresAt: Date.now.timeIntervalSince1970 + 900, member: "member-1") },
      makeSocket: { _ in socket }, timing: fastTiming)
    var pokes: [RealtimePoke] = []
    service.onPoke = { pokes.append($0) }
    let run = Task { await service.run() }
    try await waitUntil { service.connected }
    service.follow("room-1")
    try await waitUntil { service.receives(room: "room-1") }
    XCTAssertEqual(pokes, [RealtimePoke(kind: .resync), RealtimePoke(kind: .resync, room: "room-1")], "the first join and the room's join each catch up")
    pokes = []

    socket.socket(up: false)
    try await Task.sleep(for: .milliseconds(60))
    socket.socket(up: true)
    try await Task.sleep(for: .milliseconds(60))
    XCTAssertEqual(pokes, [], "no catch-up before the channels have rejoined")
    // The library resets every channel on the new socket, then subscribes it again.
    socket.channel("member:member-1", up: false); socket.channel("room:room-1", up: false)
    XCTAssertFalse(service.receives(room: "room-1"), "a rejoining room polls")
    socket.channel("member:member-1", up: true)
    XCTAssertEqual(pokes, [RealtimePoke(kind: .resync)], "one catch-up once the member channel is back")
    socket.channel("room:room-1", up: true)
    XCTAssertTrue(service.receives(room: "room-1"))
    XCTAssertEqual(pokes.last, RealtimePoke(kind: .resync, room: "room-1"))
    XCTAssertEqual(service.mode, .realtime, "a short drop never left realtime")
    XCTAssertEqual(socket.joined, ["member:member-1", "room:room-1"], "the library rejoined; no second session")
    run.cancel(); await run.value
  }

  /// A member channel that the server closed (or whose rejoin failed) while the socket stays up:
  /// polling after the fallback, then a new session with a fresh token and join.
  func testLostMemberChannelFallsBackToPollingAndStartsANewSession() async throws {
    var sockets: [FakeSocket] = []
    var grants = 0
    let service = RealtimeService(grant: { grants += 1; return RealtimeGrant(realtime: true, token: "token-\(grants)", expiresAt: Date.now.timeIntervalSince1970 + 900, member: "member-1") },
      makeSocket: { _ in let socket = FakeSocket(); sockets.append(socket); return socket }, timing: fastTiming)
    var pokes: [RealtimePoke] = []
    service.onPoke = { pokes.append($0) }
    let run = Task { await service.run() }
    try await waitUntil { service.connected }
    service.follow("room-1")
    try await waitUntil { service.receives(room: "room-1") }
    sockets[0].channel("member:member-1", up: false)
    sockets[0].channel("room:room-1", up: false)
    XCTAssertFalse(service.receives(room: "room-1"), "a closed room channel polls at once")
    try await waitUntil { sockets.count == 2 && service.connected }
    XCTAssertTrue(sockets[0].disconnected)
    XCTAssertEqual(grants, 2, "the new session asks for a fresh token")
    try await waitUntil { service.receives(room: "room-1") }
    XCTAssertEqual(sockets[1].joined, ["member:member-1", "room:room-1"])
    run.cancel(); await run.value
  }

  /// A socket that stays down past the fallback switches to polling; when the library reconnects
  /// and rejoins, realtime resumes with a catch-up.
  func testLongSocketDropPollsAndResumesWithACatchUp() async throws {
    let socket = FakeSocket()
    let service = RealtimeService(grant: { RealtimeGrant(realtime: true, token: "token-a", expiresAt: Date.now.timeIntervalSince1970 + 900, member: "member-1") },
      makeSocket: { _ in socket }, timing: fastTiming)
    var pokes: [RealtimePoke] = []
    service.onPoke = { pokes.append($0) }
    let run = Task { await service.run() }
    try await waitUntil { service.connected }
    pokes = []
    socket.socket(up: false)
    try await waitUntil { service.mode == .polling }
    socket.socket(up: true)
    try await Task.sleep(for: .milliseconds(60))
    XCTAssertEqual(service.mode, .polling, "the socket alone is not enough: the member channel is still rejoining")
    socket.channel("member:member-1", up: false); socket.channel("member:member-1", up: true)
    XCTAssertEqual(service.mode, .realtime)
    XCTAssertEqual(pokes, [RealtimePoke(kind: .resync)])
    run.cancel(); await run.value
  }

  /// The scene left and re-entered the foreground while the member join was still pending: the new
  /// run waits for the old one to wind down and connects instead of returning at once.
  func testRunTakesOverFromARunStillWindingDown() async throws {
    let socket = FakeSocket(); socket.hang = true
    let service = RealtimeService(grant: { RealtimeGrant(realtime: true, token: "token-a", expiresAt: Date.now.timeIntervalSince1970 + 900, member: "member-1") },
      makeSocket: { _ in socket }, timing: RealtimeService.Timing(joinTimeout: .seconds(30)))
    let first = Task { await service.run() }
    try await waitUntil { socket.joinAttempts == 1 }
    first.cancel()
    socket.hang = false
    let second = Task { await service.run() }
    try await waitUntil { service.connected }
    XCTAssertEqual(socket.joinAttempts, 2)
    XCTAssertEqual(socket.joined, ["member:member-1"])
    await first.value
    XCTAssertTrue(service.connected, "the cancelled run's teardown does not touch the new session")
    second.cancel(); await second.value
    XCTAssertFalse(service.connected)
  }

  /// A device clock 10 minutes behind the server: the refresh is timed from `expires_in` on the
  /// device's own clock, so it still happens five minutes before the token expires.
  func testRefreshUsesTheGrantLifetimeOnTheDeviceClock() async throws {
    let serverNow = 1_800_000_000.0
    var clock = serverNow - 600
    let start = clock
    var grantTimes: [Double] = []
    let socket = FakeSocket()
    let refreshed = expectation(description: "setAuth")
    var refreshedOnce = false
    socket.onSetAuth = { _ in if !refreshedOnce { refreshedOnce = true; refreshed.fulfill() } }
    let service = RealtimeService(grant: {
        grantTimes.append(clock)
        return RealtimeGrant(realtime: true, token: "token-\(grantTimes.count)", expiresAt: serverNow + 900, expiresIn: 900, member: "member-1")
      },
      makeSocket: { _ in socket },
      sleep: { duration in
        if refreshedOnce { try await Task.sleep(for: .seconds(3600)); return }
        try Task.checkCancellation()
        clock += Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        await Task.yield()
      },
      now: { Date(timeIntervalSince1970: clock) })
    let run = Task { await service.run() }
    await fulfillment(of: [refreshed], timeout: 10)
    let refreshAt = try XCTUnwrap(grantTimes.last)
    XCTAssertEqual(refreshAt - start, 600, accuracy: 31, "refreshed 10 minutes into a 15-minute token")
    run.cancel(); await run.value
  }

  /// An inbox poke that needs a snapshot while a mutation is in flight is not dropped: the snapshot
  /// runs once the mutation is done. One that lands during a refresh gets a snapshot started after it.
  func testSnapshotRequestsWaitForMutationsAndRefreshesInFlight() async throws {
    var snapshots = 0
    var gate: CheckedContinuation<Void, Never>?
    var holdSnapshot = false
    let store = try networkStore { [self] _, action, _, _ in
      XCTAssertEqual(action, "snapshot")
      snapshots += 1
      if holdSnapshot { holdSnapshot = false; await withCheckedContinuation { gate = $0 } }
      return try snapshot(conversations: [room("room-1", 1...3)], meta: [meta("room-1")])
    }
    await store.refresh()
    XCTAssertEqual(snapshots, 1)

    store.busy = true
    await store.receive(RealtimePoke(kind: .inbox, room: "room-new", seq: 1))
    XCTAssertEqual(snapshots, 1, "a mutation in flight blocks the refresh")
    XCTAssertTrue(store.snapshotRequested, "the request is kept")
    store.busy = false
    await store.refresh()
    XCTAssertEqual(snapshots, 2)
    XCTAssertFalse(store.snapshotRequested)

    holdSnapshot = true
    let inFlight = Task { await store.refresh() }
    try await waitUntil { gate != nil }
    let poke = Task { await store.receive(RealtimePoke(kind: .inbox, room: "room-1")) }
    try await Task.sleep(for: .milliseconds(50))
    XCTAssertEqual(snapshots, 3)
    gate?.resume(); gate = nil
    await inFlight.value; await poke.value
    XCTAssertEqual(snapshots, 4, "a second snapshot starts after the poke; the one in flight may predate the invitation")
    XCTAssertFalse(store.snapshotRequested)
  }

  /// This device's own typing ping comes back as a poke and costs no request; queued change pokes
  /// for a room share one read; a shown typing indicator expires locally after the server window.
  func testOwnTypingEchoIsIgnoredAndTypingExpiresLocally() async throws {
    var actions: [String] = []
    var typing: [String] = []
    let store = try networkStore { [self] _, action, payload, _ in
      actions.append(action)
      switch action {
      case "snapshot": return try snapshot(conversations: [room("room-1", 1...3)], meta: [meta("room-1")])
      case "room.typing": return try JSONSerialization.data(withJSONObject: ["ok": true])
      default:
        var roomMeta = meta("room-1"); roomMeta["typing"] = typing
        return try JSONSerialization.data(withJSONObject: ["room_id": "room-1", "messages": [], "more": false, "meta": roomMeta, "now": 600])
      }
    }
    await store.refresh()
    let follow = Task { await store.followRoom("room-1") }
    try await waitUntil { actions.filter { $0 == "room.messages" }.count == 1 }

    await store.sendTyping("room-1")
    await store.receive(RealtimePoke(kind: .typing, room: "room-1"))
    XCTAssertEqual(actions.filter { $0 == "room.messages" }.count, 1, "own typing echo fetches nothing")
    XCTAssertEqual(actions.filter { $0 == "room.typing" }.count, 1)

    typing = ["Them"]
    store.enqueue(RealtimePoke(kind: .change, room: "room-1"))
    store.enqueue(RealtimePoke(kind: .change, room: "room-1"))
    await store.receive(RealtimePoke(kind: .change, room: "room-1"))
    XCTAssertEqual(actions.filter { $0 == "room.messages" }.count, 2, "queued change pokes share one read")
    XCTAssertEqual(store.conversationMeta["room-1"]?.typing, ["Them"])
    store.expireTyping("room-1", now: .now.addingTimeInterval(3))
    XCTAssertEqual(store.conversationMeta["room-1"]?.typing, ["Them"], "inside the server's 8 s window")
    store.expireTyping("room-1", now: .now.addingTimeInterval(AppStore.typingWindow + 1))
    XCTAssertNil(store.conversationMeta["room-1"]?.typing, "cleared without another request")
    XCTAssertEqual(actions.filter { $0 == "room.messages" }.count, 2)
    follow.cancel(); await follow.value
  }

  private var fastTiming: RealtimeService.Timing {
    RealtimeService.Timing(joinTimeout: .seconds(5), fallback: .milliseconds(300), socketGrace: .seconds(2), lostRetry: .milliseconds(20), tick: .milliseconds(20))
  }

  private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async throws {
    let deadline = Date.now.addingTimeInterval(timeout)
    while !condition() {
      guard Date.now < deadline else { XCTFail("condition not met in time"); return }
      try await Task.sleep(for: .milliseconds(20))
    }
  }
}

@MainActor private final class FakeSocket: RealtimeSocket {
  var refuse = false
  /// Joins wait until cancelled (a slow network).
  var hang = false
  private(set) var joinAttempts = 0
  private(set) var joined: [String] = []
  private(set) var left: [String] = []
  private(set) var tokens: [String] = []
  private(set) var disconnected = false
  var onSetAuth: ((String) -> Void)?
  private var handlers: [String: @MainActor (RealtimePoke) -> Void] = [:]
  private var statusHandlers: [String: @MainActor (Bool) -> Void] = [:]
  private var status: AsyncStream<Bool>.Continuation?
  func join(_ topic: String, onPoke: @escaping @MainActor (RealtimePoke) -> Void, onStatus: @escaping @MainActor (Bool) -> Void) async throws {
    joinAttempts += 1
    if hang { try await Task.sleep(for: .seconds(3600)) }
    if refuse { throw URLError(.userAuthenticationRequired) }
    joined.append(topic); handlers[topic] = onPoke; statusHandlers[topic] = onStatus
  }
  func leave(_ topic: String) async { left.append(topic); handlers.removeValue(forKey: topic); statusHandlers.removeValue(forKey: topic) }
  func setAuth(_ token: String) async { tokens.append(token); onSetAuth?(token) }
  func statusUpdates() -> AsyncStream<Bool> {
    AsyncStream { continuation in continuation.yield(true); status = continuation }
  }
  func disconnect() async { disconnected = true; handlers = [:]; statusHandlers = [:]; status?.finish() }
  func deliver(_ poke: RealtimePoke, on topic: String) { handlers[topic]?(poke) }
  /// The WebSocket dropped (`false`) or reconnected (`true`).
  func socket(up: Bool) { status?.yield(up) }
  /// A joined channel left `subscribed` (rejoining, closed by the server) or came back.
  func channel(_ topic: String, up: Bool) { statusHandlers[topic]?(up) }
}
