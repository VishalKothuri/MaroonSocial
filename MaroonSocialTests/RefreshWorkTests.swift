import XCTest
@testable import MaroonSocial

@MainActor final class RefreshWorkTests: XCTestCase {
  func testMutationWaitsForOldSnapshotThenFetchesFreshContentBeforePresenting() async {
    let work = RefreshWork()
    var pending: CheckedContinuation<Void, Never>?
    var events: [String] = []
    let oldSnapshot = Task {
      await work.run(joinExisting: false) {
        events.append("old request")
        await withCheckedContinuation { pending = $0 }
        events.append("old snapshot")
      }
    }
    while pending == nil { await Task.yield() }
    let mutation = Task {
      await work.runAfterCurrent { events.append("fresh snapshot") }
      events.append("present joined group")
    }
    while work.waitingCount == 0 { await Task.yield() }
    XCTAssertEqual(events, ["old request"])
    pending?.resume(); pending = nil
    await oldSnapshot.value; await mutation.value
    XCTAssertEqual(events, ["old request", "old snapshot", "fresh snapshot", "present joined group"])
  }

  func testCancelledMutationWaiterNeverStartsAnotherRequest() async {
    let work = RefreshWork()
    var pending: CheckedContinuation<Void, Never>?
    let background = Task { await work.run(joinExisting: false) { await withCheckedContinuation { pending = $0 } } }
    while pending == nil { await Task.yield() }
    let mutation = Task { await work.runAfterCurrent { XCTFail("Cancelled presentation must not start another refresh") } }
    while work.waitingCount == 0 { await Task.yield() }
    mutation.cancel(); await mutation.value
    pending?.resume(); pending = nil; await background.value
  }
  func testPullWaitsForExistingBackgroundWorkWithoutAnotherRequest() async {
    let work = RefreshWork()
    var requestCount = 0
    var pending: CheckedContinuation<Void, Never>?
    let background = Task {
      await work.run(joinExisting: false) {
        requestCount += 1
        await withCheckedContinuation { pending = $0 }
      }
    }
    while pending == nil { await Task.yield() }
    var pullFinished = false
    let pull = Task {
      await work.run(joinExisting: true) { requestCount += 1 }
      pullFinished = true
    }
    while work.waitingCount == 0 { await Task.yield() }
    XCTAssertFalse(pullFinished)
    await work.run(joinExisting: false) { requestCount += 1 }
    XCTAssertEqual(requestCount, 1)
    pending?.resume(); pending = nil
    await background.value; await pull.value
    XCTAssertTrue(pullFinished)
    XCTAssertEqual(requestCount, 1)
    await work.run(joinExisting: true) { requestCount += 1 }
    XCTAssertEqual(requestCount, 2, "A subsequent pull can perform new work")
  }
  func testCancelingPullWaiterDoesNotCancelBackgroundOwner() async {
    let work = RefreshWork()
    var pending: CheckedContinuation<Void, Never>?
    var backgroundCompleted = false
    let background = Task {
      await work.run(joinExisting: false) { await withCheckedContinuation { pending = $0 } }
      backgroundCompleted = true
    }
    while pending == nil { await Task.yield() }
    let pull = Task { await work.run(joinExisting: true) { XCTFail("Must join") } }
    while work.waitingCount == 0 { await Task.yield() }
    pull.cancel(); await pull.value
    XCTAssertFalse(backgroundCompleted)
    pending?.resume(); pending = nil; await background.value
    XCTAssertTrue(backgroundCompleted)
  }
  func testPartialPullSlidesTheSameLogoProportionallyWithoutStartingAnimation() {
    let quarter = RefreshPresentation(pullDistance: RefreshPresentation.logoHeight / 4, refreshing: false, dragging: true)
    let half = RefreshPresentation(pullDistance: RefreshPresentation.logoHeight / 2, refreshing: false, dragging: true)
    XCTAssertEqual(quarter.progress, 0.25, accuracy: 0.0001)
    XCTAssertEqual(half.headerTranslation, quarter.headerTranslation * 2, accuracy: 0.0001)
    XCTAssertFalse(quarter.refreshing)
    XCTAssertFalse(half.refreshing)
    let loading = RefreshPresentation(pullDistance: 0, refreshing: true, dragging: false)
    XCTAssertEqual(loading.progress, 1, "Native inset changes cannot restore the header during active loading")
    XCTAssertEqual(RefreshPresentation.idle.headerTranslation, 0)
  }
}
