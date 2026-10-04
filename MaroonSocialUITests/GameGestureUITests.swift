import XCTest

/// UIKit-delivered gestures in the real iOS WKWebView, separate from DOM tests.
/// Uses the isolated fixture account and local games only.
@MainActor final class GameGestureUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  func testPoolAndPongPullBackGesturesStartAndCompleteActualShots() {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText("gestureaggie")
    app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    app.tabBars.buttons["Explore"].tap()
    for (name, action) in [("8 Ball", "Take shot"), ("Cup Pong", "Throw ball")] {
      let game = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
      for _ in 0..<5 where !game.isHittable { app.swipeUp() }
      XCTAssertTrue(game.isHittable); game.tap()
      let practice = app.buttons["practiceGame"]
      XCTAssertTrue(practice.waitForExistence(timeout: 5)); practice.tap()
      let shoot = app.webViews.buttons[action]
      XCTAssertTrue(shoot.waitForExistence(timeout: 15))
      let replay = app.webViews.buttons["Replay last shot"]
      XCTAssertFalse(replay.isEnabled)
      let web = app.webViews.firstMatch
      XCTAssertTrue(web.exists)
      // Start on the lower central felt/table and pull down through the canvas.
      // WK pointer capture keeps the release even when the finger crosses its edge.
      let start = web.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40))
      let end = web.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.66))
      start.press(forDuration: 0.12, thenDragTo: end)
      let completed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: replay)
      XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 18), .completed, "\(name) must turn a real touch drag into a completed physics shot")
      XCTAssertTrue(shoot.isEnabled)
      let result = XCTAttachment(screenshot: app.screenshot()); result.name = "\(name) after native pull-back gesture"; result.lifetime = .keepAlways; add(result)
      app.navigationBars.buttons.element(boundBy: 0).tap()
      app.navigationBars.buttons.element(boundBy: 0).tap()
    }
  }
}
