import XCTest
@testable import MaroonSocial

final class FeedChromeStateTests: XCTestCase {
  func testDownwardScrollCollapsesAndSmallReverseRequiresIntent() {
    var state = FeedChromeState()
    state.observe(offset: 20, viewport: 500, interacting: true, locked: false, now: 1.0)
    state.observe(offset: 80, viewport: 500, interacting: true, locked: false, now: 2.0)
    XCTAssertTrue(state.collapsed)
    state.observe(offset: 76, viewport: 500, interacting: true, locked: false, now: 3.0)
    XCTAssertTrue(state.collapsed)
    state.observe(offset: 54, viewport: 500, interacting: true, locked: false, now: 4.0)
    XCTAssertFalse(state.collapsed)
  }
  func testCoalescedFastUserScrollStillChangesChrome() {
    var state = FeedChromeState()
    state.observe(offset: 0, viewport: 500, interacting: false, locked: false, now: 1.0)
    state.observe(offset: 300, viewport: 500, interacting: true, locked: false, now: 2.0)
    XCTAssertTrue(state.collapsed)
    state.observe(offset: 100, viewport: 500, interacting: true, locked: false, now: 3.0)
    XCTAssertFalse(state.collapsed)
  }
  func testKeyboardAndToolbarLayoutChangesNeverCountAsUserDirection() {
    var state = FeedChromeState()
    state.observe(offset: 20, viewport: 500, interacting: true, locked: false, now: 1.0)
    state.observe(offset: 100, viewport: 350, interacting: true, locked: false, now: 2.0)
    XCTAssertFalse(state.collapsed)
    state.observe(offset: 200, viewport: 350, interacting: false, locked: false, now: 3.0)
    XCTAssertFalse(state.collapsed)
    state.observe(offset: 250, viewport: 350, interacting: true, locked: false, now: 4.0)
    XCTAssertTrue(state.collapsed)
    state.observe(offset: 150, viewport: 500, interacting: true, locked: false, now: 5.0)
    XCTAssertTrue(state.collapsed, "Removing header height must not immediately undo the collapse")
  }
  func testToolbarRelayoutCannotUndoCollapseButNextUpwardDragRestores() {
    var state = FeedChromeState()
    state.observe(offset: 51, viewport: 548.7, interacting: true, locked: false, now: 1.00)
    state.observe(offset: 65, viewport: 548.7, interacting: true, locked: false, now: 1.02)
    state.observe(offset: 93, viewport: 548.7, interacting: true, locked: false, now: 1.04)
    XCTAssertTrue(state.collapsed)
    // Recorded iOS 26 lazy-stack correction after the bars start to hide.
    state.observe(offset: 93, viewport: 651.7, interacting: true, locked: false, now: 1.05)
    state.observe(offset: 121.7, viewport: 651.7, interacting: true, locked: false, now: 1.07)
    state.observe(offset: 93, viewport: 651.7, interacting: true, locked: false, now: 1.07)
    XCTAssertTrue(state.collapsed)
    state.observe(offset: 130, viewport: 714, interacting: false, locked: false, now: 1.4)
    state.observe(offset: 102, viewport: 714, interacting: true, locked: false, now: 1.5)
    XCTAssertFalse(state.collapsed, "A genuine upward gesture after layout settles restores the bars")
    state.observe(offset: 120, viewport: 548.7, interacting: false, locked: false, now: 1.9)
    state.observe(offset: 180, viewport: 548.7, interacting: true, locked: false, now: 2.0)
    XCTAssertTrue(state.collapsed)
    state.observe(offset: 0, viewport: 714, interacting: true, locked: false, now: 2.1)
    XCTAssertFalse(state.collapsed, "Returning to the top restores navigation even during the transition")
  }
  func testEditingTopAndNavigationResetRestoreControls() {
    var state = FeedChromeState()
    state.observe(offset: 20, viewport: 500, interacting: true, locked: false, now: 1.0)
    state.observe(offset: 100, viewport: 500, interacting: true, locked: false, now: 2.0)
    XCTAssertTrue(state.collapsed)
    state.observe(offset: 200, viewport: 500, interacting: true, locked: true, now: 3.0)
    XCTAssertFalse(state.collapsed)
    state.observe(offset: 250, viewport: 500, interacting: true, locked: false, now: 4.0)
    XCTAssertTrue(state.collapsed)
    state.observe(offset: 0, viewport: 500, interacting: true, locked: false, now: 5.0)
    XCTAssertFalse(state.collapsed)
    state.reset(); XCTAssertFalse(state.collapsed)
  }
}
