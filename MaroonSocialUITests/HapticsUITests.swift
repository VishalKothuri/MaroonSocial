import XCTest

@MainActor final class HapticsUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  private func onboard(_ app: XCUIApplication) {
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText("haptic_tester")
    app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Profile and settings"].waitForExistence(timeout: 5))
  }
  private func preference(_ app: XCUIApplication) -> XCUIElement {
    let profile = app.buttons["Profile and settings"]
    XCTAssertTrue(profile.waitForExistence(timeout: 5)); profile.tap()
    let toggle = app.switches["hapticsEnabled"]
    let screen = app.frame
    for _ in 0..<4 {
      // A partially clipped Form row can report hittable while its switch is
      // below the sheet edge. Bring the complete control into the viewport.
      if toggle.exists && toggle.isHittable,
         toggle.frame.minY > screen.minY + screen.height * 0.15,
         toggle.frame.maxY < screen.minY + screen.height * 0.75 { break }
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
    }
    XCTAssertTrue(toggle.waitForExistence(timeout: 3)); XCTAssertTrue(toggle.isHittable)
    return toggle
  }
  func testHapticPreferencePersistsWithinIsolatedFixturesAndFreshLaunchResetsIt() {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch(); onboard(app)
    let initial = preference(app); XCTAssertEqual(initial.value as? String, "1")
    initial.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    let switchedOff = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0"), object: initial)
    XCTAssertEqual(XCTWaiter.wait(for: [switchedOff], timeout: 3), .completed)
    XCTAssertEqual(initial.value as? String, "0")
    app.terminate(); app.launchArguments = ["--uitesting-preserve"]; app.launch()
    let preserved = preference(app); XCTAssertEqual(preserved.value as? String, "0")
    app.terminate(); app.launchArguments = ["--uitesting"]; app.launch(); onboard(app)
    let reset = preference(app); XCTAssertEqual(reset.value as? String, "1")
  }
}
