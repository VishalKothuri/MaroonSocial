import CoreLocation
import XCTest
@testable import MaroonSocial

@MainActor final class TagServiceTests: XCTestCase {
  func testAcknowledgedCreateRotatesNonceAfterReportExit() async {
    let api = TagTestAPI()
    api.handler = { action, _ in action == "create" ? api.lobby() : api.idle() }
    let service = TagService(transport: api.send)
    await service.activate()
    await create(service)
    let first = api.requests.first { $0.0 == "create" }?.1["nonce"] as? String
    XCTAssertNotNil(service.lobby)
    await service.moderate(player: "other", reason: "Synthetic test")
    XCTAssertNil(service.lobby)
    await create(service)
    let last = api.requests.last { $0.0 == "create" }?.1["nonce"] as? String
    XCTAssertNotNil(first)
    XCTAssertNotEqual(first, last)
    XCTAssertFalse(service.location.running)
    service.deactivate()
  }

  func testUnknownCreateOutcomePreservesNonceForRetry() async {
    let api = TagTestAPI()
    var attempts = 0
    api.handler = { action, _ in
      if action == "create" {
        attempts += 1
        if attempts == 1 { throw URLError(.timedOut) }
        return api.lobby()
      }
      return api.idle()
    }
    let service = TagService(transport: api.send)
    await service.activate()
    await create(service)
    XCTAssertNotNil(service.error)
    XCTAssertNil(service.lobby)
    await create(service)
    let nonces = api.requests.filter { $0.0 == "create" }.compactMap { $0.1["nonce"] as? String }
    XCTAssertEqual(nonces.count, 2)
    XCTAssertEqual(nonces[0], nonces[1])
    XCTAssertNotNil(service.lobby)
    service.deactivate()
  }

  func testLateCreateIsLeftAfterBackgroundWithoutStartingLocation() async {
    let api = TagTestAPI()
    let sent = expectation(description: "create in flight")
    let left = expectation(description: "late lobby cleaned up")
    var release: CheckedContinuation<Data, Never>?
    api.handler = { action, payload in
      if action == "create" { return await withCheckedContinuation { release = $0; sent.fulfill() } }
      if action == "leave" {
        XCTAssertEqual(payload["lobby"] as? String, "synthetic-lobby")
        left.fulfill()
      }
      return api.idle()
    }
    let service = TagService(transport: api.send)
    await service.activate()
    let pending = Task { await create(service) }
    await fulfillment(of: [sent], timeout: 2)
    service.deactivate()
    XCTAssertFalse(service.location.running)
    release?.resume(returning: api.lobby())
    await pending.value
    await fulfillment(of: [left], timeout: 2)
    XCTAssertNil(service.lobby)
    XCTAssertNil(service.consentLobby)
    XCTAssertFalse(service.sharing)
  }

  func testLobbyConsentDoesNotCaptureAndRevocationClearsConsent() async {
    let api = TagTestAPI()
    api.handler = { _, _ in api.lobby() }
    let service = TagService(transport: api.send)
    await service.activate()
    await service.ready(consent: true)
    XCTAssertEqual(service.consentLobby, "synthetic-lobby")
    XCTAssertFalse(service.location.running)
    XCTAssertFalse(service.sharing)
    api.handler = { _, _ in throw SocialServiceError(error: "Suspended", code: "forbidden") }
    await service.choose(role: "hider")
    XCTAssertNil(service.consentLobby)
    XCTAssertFalse(service.location.running)
    service.deactivate()
  }

  private func create(_ service: TagService) async {
    await service.create(title: "Synthetic lobby", area: "Synthetic permitted area", duration: 5, hiding: 30, capacity: 2, radius: 150)
  }
}

@MainActor private final class TagTestAPI {
  var requests: [(String, [String: Any])] = []
  var handler: ((String, [String: Any]) async throws -> Data)?
  func send(_ action: String, _ payload: [String: Any]) async throws -> Data {
    requests.append((action, payload))
    return try await handler?(action, payload) ?? idle()
  }
  func idle() -> Data { Data("{\"state\":\"idle\",\"server_time\":1000}".utf8) }
  func lobby() -> Data {
    Data("""
    {"state":"lobby","server_time":1000,
     "lobby":{"id":"synthetic-lobby","code":"AABBCCDD","title":"Synthetic lobby","area":"Synthetic area","capacity":2,"duration_seconds":300,"hide_seconds":30,"radius_m":150,"host":true,"expires_at":2000},
     "me":{"id":"self","role":"seeker","ready":true,"consented":true,"caught":false,"outside":false,"location_fresh":false},"players":[],"hints":[],"catches":[],"messages":[]}
    """.utf8)
  }
}


@MainActor final class TagLocationTests: XCTestCase {
  func testStationaryFixRequestsFreshLocationWithBoundedRetries() {
    let primary = TagLocationTestManager()
    let refresh = TagLocationTestManager()
    let location = TagLocation(manager: primary, stationaryManager: refresh)
    location.start()
    let now = Date.now
    let original = syntheticFix(at: now.addingTimeInterval(-11))
    location.locationManager(primary, didUpdateLocations: [original])
    location.refreshIfNeeded(now: now)
    XCTAssertEqual(refresh.requests, 1)
    XCTAssertEqual(location.latest?.timestamp, original.timestamp)
    location.refreshIfNeeded(now: now.addingTimeInterval(3))
    XCTAssertEqual(refresh.requests, 1)
    location.refreshIfNeeded(now: now.addingTimeInterval(12))
    XCTAssertEqual(refresh.requests, 2)
    location.stop()
    location.refreshIfNeeded(now: now.addingTimeInterval(30))
    XCTAssertEqual(refresh.requests, 2)
    XCTAssertGreaterThan(primary.stops, 0)
    XCTAssertGreaterThan(refresh.stops, 0)
    XCTAssertFalse(location.running)
  }
  func testStationaryFreshResultKeepsTimestampAndStaleCallbacksCannotReplaceIt() {
    let primary = TagLocationTestManager()
    let refresh = TagLocationTestManager()
    let location = TagLocation(manager: primary, stationaryManager: refresh)
    var deliveries: [CLLocation] = []
    location.onLocation = { deliveries.append($0) }
    location.start()
    let fresh = syntheticFix(at: .now)
    location.locationManager(refresh, didUpdateLocations: [fresh])
    location.refreshIfNeeded(now: fresh.timestamp.addingTimeInterval(2))
    XCTAssertEqual(refresh.requests, 0)
    location.locationManager(primary, didUpdateLocations: [syntheticFix(at: fresh.timestamp.addingTimeInterval(-30))])
    XCTAssertEqual(deliveries.count, 1)
    XCTAssertEqual(location.latest?.timestamp, fresh.timestamp)
    location.stop()
    location.locationManager(refresh, didUpdateLocations: [syntheticFix(at: .now)])
    XCTAssertEqual(deliveries.count, 1)
    XCTAssertNil(location.latest)
  }
  func testRevokedPermissionStopsBothSourcesAndDisablesRefresh() {
    let primary = TagLocationTestManager()
    let refresh = TagLocationTestManager()
    let location = TagLocation(manager: primary, stationaryManager: refresh)
    location.start()
    primary.permission = .denied
    refresh.permission = .denied
    location.locationManagerDidChangeAuthorization(refresh)
    XCTAssertTrue(location.denied)
    XCTAssertGreaterThan(primary.stops, 0)
    XCTAssertGreaterThan(refresh.stops, 0)
    location.refreshIfNeeded()
    XCTAssertEqual(refresh.requests, 0)
    location.locationManager(primary, didUpdateLocations: [syntheticFix(at: .now)])
    XCTAssertNil(location.latest)
    location.stop()
  }
  private func syntheticFix(at timestamp: Date) -> CLLocation {
    CLLocation(coordinate: CLLocationCoordinate2D(latitude: 30.6123, longitude: -96.3412), altitude: 0, horizontalAccuracy: 8, verticalAccuracy: 8, timestamp: timestamp)
  }
}
private final class TagLocationTestManager: CLLocationManager {
  var permission: CLAuthorizationStatus = .authorizedWhenInUse
  var requests = 0
  var starts = 0
  var stops = 0
  override var authorizationStatus: CLAuthorizationStatus { permission }
  override func startUpdatingLocation() { starts += 1 }
  override func stopUpdatingLocation() { stops += 1 }
  override func requestLocation() { requests += 1 }
  override func startUpdatingHeading() {}
  override func stopUpdatingHeading() {}
  override func requestWhenInUseAuthorization() {}
}
