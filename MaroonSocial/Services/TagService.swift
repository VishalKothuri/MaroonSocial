import CoreLocation
import Foundation
import Observation

struct TagLobby: Decodable, Identifiable {
  let id: String
  let code: String
  let title: String
  let area: String
  let capacity: Int
  let durationSeconds: Int
  let hideSeconds: Int
  let radiusM: Int
  let host: Bool
  let seekAt: Double?
  let endsAt: Double?
  let expiresAt: Double
  let winner: String?
  let centerLat: Double?
  let centerLon: Double?
}
struct TagPlayer: Decodable, Identifiable {
  let id: String
  let username: String
  let role: String
  let ready: Bool
  let caught: Bool
  let online: Bool
}
struct TagSelf: Decodable {
  let id: String
  let role: String
  let ready: Bool
  let consented: Bool
  let caught: Bool
  let outside: Bool
  let locationFresh: Bool
  let pausedAt: Double?
}
struct TagHint: Decodable, Identifiable {
  let id: String
  let username: String
  let direction: String
  let distance: String
  let recordedAt: Double
}
struct TagCatch: Decodable, Identifiable {
  let id: String
  let requester: String
  let target: String
  let requesterName: String
  let targetName: String
  let expiresAt: Double
}
struct TagMessage: Decodable, Identifiable {
  let id: Int
  let body: String
  let username: String
  let team: String?
  let createdAt: Double
}
struct TagSnapshot: Decodable {
  let state: String
  let serverTime: Double
  let lobby: TagLobby?
  let me: TagSelf?
  let players: [TagPlayer]?
  let hints: [TagHint]?
  let catches: [TagCatch]?
  let messages: [TagMessage]?
  let nextHintAt: Double?
  let results: TagResults?
  let rematchCode: String?
}

/// One foreground game session. Never starts sensors before the per-match consent control.
@Observable @MainActor final class TagLocation: NSObject, @preconcurrency CLLocationManagerDelegate {
  var running = false
  var denied = false
  var heading = 0.0
  var hasHeading = false
  var error: String?
  var latest: CLLocation?
  var onLocation: ((CLLocation) -> Void)?
  private let manager: CLLocationManager
  private let stationaryManager: CLLocationManager
  private var refreshTask: Task<Void, Never>?
  private var lastRefreshAt = Date.distantPast
  init(manager: CLLocationManager = CLLocationManager(), stationaryManager: CLLocationManager = CLLocationManager()) {
    self.manager = manager
    self.stationaryManager = stationaryManager
    super.init()
    for source in [manager, stationaryManager] {
      source.delegate = self
      source.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
      source.distanceFilter = kCLDistanceFilterNone
      source.pausesLocationUpdatesAutomatically = false
    }
  }
  func start() {
    guard !running else { return }
    running = true
    error = nil
    switch manager.authorizationStatus {
    case .notDetermined: manager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorizedWhenInUse: beginUpdates()
    default: denied = true; error = "Location access is off. Enable it in Settings or leave the match."
    }
  }
  private func beginUpdates() {
    guard running else { return }
    manager.startUpdatingLocation()
    if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    guard refreshTask == nil else { return }
    refreshTask = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(3)) } catch { break }
        guard let self, self.running else { break }
        self.refreshIfNeeded()
      }
    }
  }
  // requestLocation() does nothing on a manager already running standard updates.
  // A separate one-shot manager refreshes genuinely stationary fixes, independent
  // of network polling. Cached/stale results are still rejected below.
  func refreshIfNeeded(now: Date = .now) {
    guard running, [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus),
          latest == nil || now.timeIntervalSince(latest!.timestamp) >= 10 || latest!.horizontalAccuracy > 75,
          now.timeIntervalSince(lastRefreshAt) >= 12 else { return }
    lastRefreshAt = now
    stationaryManager.stopUpdatingLocation()
    stationaryManager.requestLocation()
  }
  func stop() {
    running = false
    refreshTask?.cancel(); refreshTask = nil
    lastRefreshAt = .distantPast
    stationaryManager.stopUpdatingLocation()
    manager.stopUpdatingLocation()
    manager.stopUpdatingHeading()
    latest = nil
    hasHeading = false
  }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    denied = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    if denied {
      error = "Location access is off. Enable it in Settings or leave the match."
      latest = nil
      self.manager.stopUpdatingLocation()
      stationaryManager.stopUpdatingLocation()
      self.manager.stopUpdatingHeading()
      refreshTask?.cancel(); refreshTask = nil
    } else if [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus) { beginUpdates() }
  }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard running, !denied, [.authorizedAlways, .authorizedWhenInUse].contains(self.manager.authorizationStatus),
          let location = locations.max(by: { $0.timestamp < $1.timestamp }), location.horizontalAccuracy >= 0,
          (-10..<20).contains(Date.now.timeIntervalSince(location.timestamp)),
          latest == nil || location.timestamp > latest!.timestamp else { return }
    latest = location
    if location.horizontalAccuracy > 75 {
      error = "GPS accuracy is low. Move to open sky; no hint is shared until accuracy improves."
      return
    }
    error = nil
    onLocation?(location)
  }
  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    guard running, !denied, newHeading.headingAccuracy >= 0 else { return }
    hasHeading = true
    heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard running else { return }
    if let latest, Date.now.timeIntervalSince(latest.timestamp) < 20, latest.horizontalAccuracy <= 75 { return }
    self.error = "Waiting for a fresh GPS position. Hints pause while your location is unavailable."
  }
}

@Observable @MainActor final class TagService {
  typealias Transport = @MainActor (String, [String: Any]) async throws -> Data
  let location = TagLocation()
  private let requestTransport: Transport
  var snapshot: TagSnapshot?
  var busy = false
  var error: String?
  var notice: String?
  var message = ""
  private(set) var consentLobby: String?
  private var active = false
  private var generation = 0
  private var polling: Task<Void, Never>?
  private var tail: Task<Void, Never>?
  private var lastLocationSent = Date.distantPast
  private var clockOffset = 0.0
  private var lastLobby: String?
  private var createNonce = UUID().uuidString
  private var rematchNonce = UUID().uuidString
  private var pendingMessage: (String, String)?
  var state: String { snapshot?.state ?? "idle" }
  var lobby: TagLobby? { snapshot?.lobby }
  var me: TagSelf? { snapshot?.me }
  var players: [TagPlayer] { snapshot?.players ?? [] }
  var hints: [TagHint] { snapshot?.hints ?? [] }
  var catches: [TagCatch] { snapshot?.catches ?? [] }
  var messages: [TagMessage] { (snapshot?.messages ?? []).sorted { $0.id < $1.id } }
  var playing: Bool { state == "hiding" || state == "seeking" }
  var now: Date { .now.addingTimeInterval(clockOffset) }
  var sharing: Bool { active && playing && consentLobby == lobby?.id && me?.caught == false }
  var hasSession: Bool { lobby != nil }
  var needsResume: Bool { playing && me?.caught == false && (consentLobby != lobby?.id || me?.pausedAt != nil) }
  var hintCountdown: Int? {
    guard state == "seeking", me?.role == "seeker", sharing, let deadline = snapshot?.nextHintAt else { return nil }
    return max(0, Int(ceil(deadline - now.timeIntervalSince1970)))
  }
  var pauseCountdown: Int? {
    guard let paused = me?.pausedAt else { return nil }
    return max(0, Int(ceil(paused + 90 - now.timeIntervalSince1970)))
  }
  convenience init(social: SocialService) {
    self.init(transport: { action, payload in try await social.sendData(endpoint: "tag-game", action: action, payload: payload) })
  }
  init(transport: @escaping Transport) {
    requestTransport = transport
    location.onLocation = { [weak self] position in self?.sendLocation(position) }
  }
  /// A launch-time account check restores only server state. It cannot restore
  /// GPS consent from a previous process, and an empty account gets no timer.
  func restoreSession() async {
    guard !active, !busy, snapshot == nil else { return }
    active = true
    let version = generation
    await poll()
    guard active, generation == version else { return }
    if lobby == nil { active = false }
  }
  func activate() async {
    guard !active else { return }
    active = true
    await poll()
  }
  private func updatePolling() {
    guard active, lobby != nil else {
      polling?.cancel(); polling = nil
      return
    }
    guard polling == nil else { return }
    polling = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(3)) } catch { break }
        guard let self, self.active, self.lobby != nil else { break }
        await self.poll()
        if self.sharing, let latest = self.location.latest,
           Date.now.timeIntervalSince(latest.timestamp) < 20 { self.sendLocation(latest) }
      }
    }
  }
  func create(title: String, area: String, duration: Int, hiding: Int, capacity: Int, radius: Int) async {
    await act("create", payload: ["nonce": createNonce, "title": title, "area": area,
                                  "duration_seconds": duration * 60, "hide_seconds": hiding,
                                  "capacity": capacity, "radius_m": radius])
  }
  func join(code: String) async { await act("join", payload: ["code": code]) }
  func choose(role: String) async { await act("role", payload: ["role": role]) }
  func ready(consent: Bool) async {
    guard let lobby else { return }
    if consent { consentLobby = lobby.id }
    else { consentLobby = nil; location.stop() }
    await act("ready", payload: ["ready": consent, "consent": consent])
  }
  func start() async { await act("start") }
  func rematch() async {
    consentLobby = nil; location.stop()
    if await act("rematch", payload: ["nonce": rematchNonce]) { rematchNonce = UUID().uuidString }
  }
  func joinRematch() async {
    guard let code = snapshot?.rematchCode else { return }
    consentLobby = nil; location.stop()
    await join(code: code)
  }
  func pause() async {
    consentLobby = nil; location.stop()
    await act("pause")
  }
  func resume() async {
    guard let lobby, playing, me?.caught == false else { return }
    consentLobby = lobby.id
    if !(await act("resume", payload: ["consent": true])) { consentLobby = nil; location.stop() }
  }
  /// Root app lifecycle owns this; changing tabs does not end the session.
  /// No capture or polling continues in the background, and foregrounding
  /// requires an explicit resume before sensors can restart.
  func background() {
    guard active else { return }
    active = false; generation += 1; consentLobby = nil; location.stop()
    let epoch = generation
    polling?.cancel(); polling = nil
    let previous = tail
    tail = Task { @MainActor [self] in
      await previous?.value
      guard let lastLobby else { return }
      do {
        let data = try await requestTransport("pause", ["lobby": lastLobby])
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        let value = try decoder.decode(TagSnapshot.self, from: data)
        // Keep the paused snapshot for the root banner. A newer foreground poll
        // remains queued behind this write and supplies the authoritative state.
        if !active, generation == epoch { snapshot = value; clockOffset = value.serverTime - Date.now.timeIntervalSince1970 }
      } catch { if generation == epoch { notice = "Location is off. Reopen Tag to check your match." } }
    }
  }
  func moderate(player: String, reason: String? = nil) async {
    consentLobby = nil
    location.stop()
    var payload: [String: Any] = ["target": player]
    if let reason { payload["reason"] = reason }
    if await act(reason == nil ? "block" : "report", payload: payload) {
      notice = reason == nil ? "Player blocked. You left the lobby." : "Report submitted and player blocked. You left the lobby."
    }
  }
  func catchPlayer(_ id: String) async { await act("catch", payload: ["target": id]) }
  func confirm(_ id: String, accept: Bool) async { await act("confirm", payload: ["catch": id, "accept": accept]) }
  func send(team: Bool) async {
    let body = message.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !body.isEmpty, body.count <= 500 else { return }
    let nonce = pendingMessage?.0 == body ? pendingMessage!.1 : UUID().uuidString
    pendingMessage = (body, nonce)
    if await act("message", payload: ["body": body, "nonce": nonce, "team": team]) {
      message = ""; pendingMessage = nil
    }
  }
  func leave() async {
    consentLobby = nil
    location.stop()
    if await act("leave") { snapshot = nil; createNonce = UUID().uuidString }
  }
  func end() async { consentLobby = nil; location.stop(); await act("end") }
  func deactivate() {
    guard active || snapshot != nil else { return }
    active = false
    generation += 1
    consentLobby = nil
    location.stop()
    polling?.cancel(); polling = nil
    // Queue after any in-flight create/join. Its response records the exact lobby
    // even when the view disappeared, so cleanup cannot leave a future lobby.
    let previous = tail
    let task = Task { @MainActor [self] in
      await previous?.value
      guard let lastLobby else { return }
      _ = try? await requestTransport("leave", ["lobby": lastLobby])
    }
    tail = task
    snapshot = nil
  }
  private func poll() async {
    guard active, !busy else { return }
    let version = generation
    do {
      let response = try await request("poll")
      guard active, generation == version else { return }
      apply(response)
      error = nil
    } catch {
      if active, generation == version {
        self.error = error.localizedDescription
        stopSharingIfRevoked(error)
      }
    }
  }
  @discardableResult private func act(_ action: String, payload: [String: Any] = [:]) async -> Bool {
    guard active, !busy else { return false }
    busy = true
    generation += 1
    let version = generation
    defer { busy = false }
    do {
      let response = try await request(action, payload: payload)
      guard active, version == generation else { return false }
      error = nil
      apply(response)
      return true
    } catch { if active, generation == version { self.error = error.localizedDescription; stopSharingIfRevoked(error) }; return false }
  }
  private func sendLocation(_ value: CLLocation) {
    guard sharing, value.horizontalAccuracy >= 0, value.horizontalAccuracy <= 75,
      Date.now.timeIntervalSince(value.timestamp) < 20,
      Date.now.timeIntervalSince(lastLocationSent) >= 6 else { return }
    lastLocationSent = .now
    let version = generation
    Task {
      do {
        let response = try await request("location", payload: [
          "latitude": (value.coordinate.latitude * 10_000).rounded() / 10_000,
          "longitude": (value.coordinate.longitude * 10_000).rounded() / 10_000,
          "accuracy": value.horizontalAccuracy, "captured_at": value.timestamp.timeIntervalSince1970])
        guard sharing, generation == version else { return }
        apply(response)
      } catch { if sharing, generation == version { self.error = error.localizedDescription; stopSharingIfRevoked(error) } }
    }
  }
  private func stopSharingIfRevoked(_ error: Error) {
    if let code = (error as? SocialServiceError)?.code, ["blocked", "forbidden", "unauthorized"].contains(code) {
      consentLobby = nil
      location.stop()
    }
  }
  private func apply(_ response: TagSnapshot) {
    if response.lobby?.id != snapshot?.lobby?.id || response.me?.consented == false { consentLobby = nil }
    snapshot = response
    clockOffset = response.serverTime - Date.now.timeIntervalSince1970
    if sharing { location.start() } else { location.stop() }
    updatePolling()
  }
  private func request(_ action: String, payload: [String: Any] = [:]) async throws -> TagSnapshot {
    let previous = tail
    let lobbyID = lobby?.id
    let task = Task { @MainActor [self] in
      await previous?.value
      var body = payload
      if let lobbyID { body["lobby"] = lobbyID }
      // Location jobs are checked again after waiting behind network requests.
      if action == "location", !sharing { throw CancellationError() }
      let data = try await requestTransport(action, body)
      let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
      let response = try decoder.decode(TagSnapshot.self, from: data)
      if let id = response.lobby?.id {
        lastLobby = id
        // Rotate only after the server acknowledges creation. A lost response
        // keeps the same nonce for retry; leaving/backgrounding can then create anew.
        if action == "create" { createNonce = UUID().uuidString }
      }
      return response
    }
    tail = Task { _ = try? await task.value }
    return try await task.value
  }
}
