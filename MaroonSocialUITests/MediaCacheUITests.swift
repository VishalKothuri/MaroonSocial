import XCTest

/// Settings → People & privacy → "Clear media cache" (caching phase 2).
@MainActor final class MediaCacheUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testClearMediaCacheRowWipesAndConfirms() {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText("media_cache_tester")
    app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    let profile = app.buttons["Profile and settings"]
    XCTAssertTrue(profile.waitForExistence(timeout: 5)); profile.tap()
    let row = app.buttons["clearMediaCache"]
    let screen = app.frame
    for _ in 0..<8 {
      if row.exists && row.isHittable && row.frame.maxY < screen.minY + screen.height * 0.8 { break }
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
    }
    XCTAssertTrue(row.waitForExistence(timeout: 3)); XCTAssertTrue(row.isHittable)
    XCTAssertFalse(row.label.contains("Cleared"))
    row.tap()
    let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "Cleared"), object: row)
    XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 3), .completed)
    // The neighbouring privacy row is untouched and still navigable.
    XCTAssertTrue(app.buttons["Blocked accounts and data export"].exists)
  }
}
