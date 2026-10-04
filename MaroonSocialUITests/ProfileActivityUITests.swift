import XCTest

@MainActor final class ProfileActivityUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  func testProfileEditingCollectionsAndNotificationPopover() {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
    let username = app.textFields["username"]; XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText("profile_tester"); app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    let bell = app.buttons["notificationsBell"]; XCTAssertTrue(bell.waitForExistence(timeout: 5)); bell.tap()
    XCTAssertTrue(app.staticTexts["You’re all caught up"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Comments, upvote milestones, and announcements will appear here."].exists)
    app.buttons["Close notifications"].tap()
    app.buttons["Profile and settings"].tap()
    XCTAssertTrue(app.buttons["editAccountProfile"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.textFields["profileUsername"].exists, "Username editing belongs behind the profile row.")
    app.buttons["editAccountProfile"].tap()
    let field = app.textFields["profileUsername"]; XCTAssertTrue(field.waitForExistence(timeout: 3))
    field.tap(); field.typeText("2")
    let save = app.buttons["saveProfileUsername"]; XCTAssertTrue(save.isEnabled); save.tap()
    XCTAssertTrue(app.navigationBars["Your account"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["@profile_tester2"].exists)
    let collections = [("settingsMyPosts", "My posts"), ("settingsMyComments", "My comments"), ("settingsSavedPosts", "Saved posts")]
    for (identifier, title) in collections {
      // The homepage bookmark filter remains in the accessibility tree behind
      // the sheet, so address the account link by its own stable identifier.
      let matches = app.buttons.matching(identifier: identifier)
      let link = matches.element
      XCTAssertTrue(link.waitForExistence(timeout: 3)); XCTAssertEqual(matches.count, 1)
      link.tap()
      let destination = app.navigationBars[title]
      XCTAssertTrue(destination.waitForExistence(timeout: 3))
      destination.buttons.element(boundBy: 0).tap()
      XCTAssertTrue(app.navigationBars["Your account"].waitForExistence(timeout: 3))
    }
    app.buttons["Close settings"].tap()
    XCTAssertTrue(bell.waitForExistence(timeout: 3)); XCTAssertTrue(bell.isHittable)
  }
}
