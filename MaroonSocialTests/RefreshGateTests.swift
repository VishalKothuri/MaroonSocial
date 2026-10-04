import XCTest
@testable import MaroonSocial

@MainActor final class RefreshGateTests: XCTestCase {
  func testSharedScopeBlocksConcurrentScreensAndCooldownStartsAtAdmission() {
    var now = 100.0
    let gate = RefreshGate(clock: { now })
    guard case .admitted(let ticket) = gate.begin(scope: "social") else { return XCTFail("First pull should start") }
    XCTAssertEqual(gate.begin(scope: "social"), .inFlight)
    now = 102; gate.finish(scope: "social", ticket: ticket)
    XCTAssertEqual(gate.begin(scope: "social"), .cooldown(8))
    now = 109.5
    XCTAssertEqual(gate.begin(scope: "social"), .cooldown(1))
    now = 110
    guard case .admitted = gate.begin(scope: "social") else { return XCTFail("Ten seconds permits another refresh") }
  }
  func testLongRunningWorkStillBlocksAfterCooldownAndOtherScopesRemainIndependent() {
    var now = 100.0
    let gate = RefreshGate(clock: { now })
    guard case .admitted(let ticket) = gate.begin(scope: "social") else { return XCTFail() }
    now = 120
    XCTAssertEqual(gate.begin(scope: "social"), .inFlight)
    guard case .admitted = gate.begin(scope: "campus") else { return XCTFail("Different data can refresh") }
    gate.finish(scope: "social", ticket: ticket)
    guard case .admitted = gate.begin(scope: "social") else { return XCTFail() }
  }
  func testLateCompletionCannotReleaseNewerRequest() {
    var now = 1.0
    let gate = RefreshGate(clock: { now })
    guard case .admitted(let old) = gate.begin(scope: "social") else { return XCTFail() }
    gate.finish(scope: "social", ticket: old); now = 11
    guard case .admitted = gate.begin(scope: "social") else { return XCTFail() }
    gate.finish(scope: "social", ticket: old)
    XCTAssertEqual(gate.begin(scope: "social"), .inFlight)
  }
  func testMinimumIntervalCannotBeConfiguredBelowTenSeconds() {
    var now = 1.0
    let gate = RefreshGate(interval: 0, clock: { now })
    guard case .admitted(let ticket) = gate.begin(scope: "social") else { return XCTFail() }
    gate.finish(scope: "social", ticket: ticket); now = 2
    XCTAssertEqual(gate.begin(scope: "social"), .cooldown(9))
  }
  func testAvailabilityReenablesAfterDeadlineAndNeverDuringWork() {
    var now = 100.0
    let gate = RefreshGate(clock: { now })
    XCTAssertFalse(gate.isBlocked(scope: "social"))
    guard case .admitted(let ticket) = gate.begin(scope: "social") else { return XCTFail() }
    XCTAssertTrue(gate.isBlocked(scope: "social"))
    now = 110; gate.expire(scope: "social")
    XCTAssertTrue(gate.isBlocked(scope: "social"), "A timeout cannot unlock unfinished work")
    gate.finish(scope: "social", ticket: ticket)
    XCTAssertFalse(gate.isBlocked(scope: "social")); XCTAssertNil(gate.deadline(scope: "social"))
    guard case .admitted(let next) = gate.begin(scope: "social") else { return XCTFail() }
    now = 112; gate.finish(scope: "social", ticket: next)
    XCTAssertEqual(gate.remaining(scope: "social"), 8)
    now = 120; gate.expire(scope: "social")
    XCTAssertFalse(gate.isBlocked(scope: "social")); XCTAssertNil(gate.deadline(scope: "social"))
  }
}
