import XCTest
@testable import MaroonSocial

final class StartupPresentationTests: XCTestCase {
  func testFastLoadKeepsEveryLetterFillThenSettlesBeforeHandoff() throws {
    var presentation = StartupPresentation(); presentation.begin(at: 10)
    let remaining = try XCTUnwrap(presentation.advanceAfterLoad(at: 10.02, reduceMotion: false))
    XCTAssertEqual(remaining, LoadingWordmarkTiming.minimumFill - 0.02, accuracy: 0.0001)
    XCTAssertTrue(presentation.isPresented); XCTAssertTrue(presentation.animating)
    let filledAt = 10 + LoadingWordmarkTiming.minimumFill
    XCTAssertEqual(try XCTUnwrap(presentation.advanceAfterLoad(at: filledAt, reduceMotion: false)), LoadingWordmarkTiming.settle, accuracy: 0.0001)
    XCTAssertTrue(presentation.isPresented); XCTAssertFalse(presentation.animating)
    XCTAssertNil(presentation.advanceAfterLoad(at: filledAt + LoadingWordmarkTiming.settle + 0.001, reduceMotion: false))
    XCTAssertFalse(presentation.isPresented)
  }
  func testSlowRealLoadWaitsOnlyForSettleAfterItFinishes() throws {
    var presentation = StartupPresentation(); presentation.begin(at: 0)
    XCTAssertTrue(presentation.animating, "The full mark remains maroon while network work continues")
    XCTAssertEqual(try XCTUnwrap(presentation.advanceAfterLoad(at: 20, reduceMotion: false)), LoadingWordmarkTiming.settle, accuracy: 0.0001)
    XCTAssertFalse(presentation.animating)
    XCTAssertNil(presentation.advanceAfterLoad(at: 20 + LoadingWordmarkTiming.settle + 0.001, reduceMotion: false))
  }
  func testErrorRecoveryAndCancellationCanReleaseHoldImmediately() {
    var presentation = StartupPresentation(); presentation.begin(at: 0)
    presentation.cancel()
    XCTAssertFalse(presentation.isPresented); XCTAssertFalse(presentation.animating)
    XCTAssertNil(presentation.advanceAfterLoad(at: 0.01, reduceMotion: false))
    presentation.restart(at: 30)
    XCTAssertEqual(presentation.advanceAfterLoad(at: 30, reduceMotion: false) ?? -1, LoadingWordmarkTiming.minimumFill, accuracy: 0.0001)
  }
  func testReduceMotionSkipsBothVisualWaits() {
    var presentation = StartupPresentation(); presentation.begin(at: 10)
    XCTAssertNil(presentation.advanceAfterLoad(at: 10, reduceMotion: true))
    XCTAssertFalse(presentation.isPresented)
  }
  func testRepeatedAppearanceDoesNotRestartTheFirstFill() throws {
    var presentation = StartupPresentation(); presentation.begin(at: 0); presentation.begin(at: 0.3)
    XCTAssertEqual(try XCTUnwrap(presentation.advanceAfterLoad(at: 0.3, reduceMotion: false)), LoadingWordmarkTiming.minimumFill - 0.3, accuracy: 0.0001)
  }
}
