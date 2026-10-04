import XCTest

/// Opt-in real-service test using only the primary QA simulator and a named
/// synthetic peer held in the foreground by the integration harness.
@MainActor final class DiscoveryLiveUITests: XCTestCase {
  func testNamedProfileSixInterestsAndExplicitRequest() throws {
    guard ProcessInfo.processInfo.environment["MAROON_DISCOVERY_LIVE"] == "1" else {
      throw XCTSkip("Requires the explicitly prepared synthetic discovery peer")
    }
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments = []; app.launch()
    if app.textFields["username"].waitForExistence(timeout: 4) {
      app.textFields["username"].tap(); app.textFields["username"].typeText("qa_meet_oct4")
      app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    }
    XCTAssertTrue(app.tabBars.buttons["Explore"].waitForExistence(timeout: 25), app.debugDescription)
    app.tabBars.buttons["Explore"].tap()
    app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Meet people")).firstMatch.tap()
    let username = app.textFields["discoveryUsername"]
    XCTAssertTrue(username.waitForExistence(timeout: 12))
    username.tap()
    let old = username.value as? String ?? ""
    if old != "Discovery username" { username.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }
    username.typeText("NativeCopperOct4\n")
    for tag in ["music", "gaming", "coffee", "engineering", "sports", "art"] {
      let button = app.buttons["discoveryTag_" + tag]; reveal(button, in: app); button.tap()
    }
    XCTAssertEqual(app.staticTexts["discoveryInterestCount"].label, "6 / 6")
    XCTAssertFalse(app.buttons["discoveryTag_movies"].isEnabled)
    shot(app, "Native six-interest selection")
    let consent = app.switches["discoveryConsent"]; reveal(consent, in: app); consent.tap()
    let enter = app.buttons["discoveryEnter"]; reveal(enter, in: app); XCTAssertTrue(enter.isEnabled); enter.tap()
    XCTAssertTrue(app.buttons["discoveryLeave"].waitForExistence(timeout: 15), app.debugDescription)
    let person = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "discoveryPerson", "SilverFinch8c4")).firstMatch
    XCTAssertTrue(person.waitForExistence(timeout: 15), app.debugDescription); person.tap()
    XCTAssertTrue(app.buttons["Send connection request"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.textFields["Say something…"].exists, "No chat before consent")
    shot(app, "Native interests profile")
    app.buttons["Send connection request"].tap()
    XCTAssertTrue(app.staticTexts["Request sent to SilverFinch8c4"].waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertFalse(app.buttons["discoveryEnd"].exists, "Request does not automatically connect")
    shot(app, "Native pending request")
    app.buttons["Cancel"].tap(); app.buttons["discoveryLeave"].tap()
    XCTAssertTrue(app.buttons["discoveryEnter"].waitForExistence(timeout: 10))
  }
  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<8 where !element.isHittable { app.swipeUp(velocity: .slow) }
    XCTAssertTrue(element.isHittable)
  }
  private func shot(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
    attachment.lifetime = .keepAlways; add(attachment)
  }
}
