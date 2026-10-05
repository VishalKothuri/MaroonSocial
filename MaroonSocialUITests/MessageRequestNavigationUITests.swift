import XCTest

/// Offline journey for the Community → envelope → send → chat → back path.
/// The chat is pushed by the feed's own navigation destination while the
/// request sheet is still dismissing, so its bar hand-off is checked separately
/// from the ordinary tap-a-row pushes.
@MainActor final class MessageRequestNavigationUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testMessagingAPostAuthorPushesTheChatAndBackReturnsToTheFeedWithItsBar() {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10)); username.tap(); username.typeText("bar_tester")
    app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.tabBars.buttons["Community"].exists)

    let envelope = app.buttons.matching(NSPredicate(format: "label == 'Message the author' AND enabled == true")).firstMatch
    XCTAssertTrue(envelope.waitForExistence(timeout: 5)); envelope.tap()
    let request = app.descendants(matching: .any)["requestText"].firstMatch
    XCTAssertTrue(request.waitForExistence(timeout: 5)); request.tap(); request.typeText("Checking the bar on the way back")
    app.buttons["sendMessageRequest"].tap()
    XCTAssertTrue(app.navigationBars["Anonymous chat"].waitForExistence(timeout: 10), "Sending pushes the new conversation")
    XCTAssertFalse(app.tabBars.buttons["Community"].isHittable, "The pushed chat hides the bar")
    // Hold so the push settles, then go back exactly like a tap on the top-left control.
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.5))
    app.navigationBars.buttons.element(boundBy: 0).tap()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.5))
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5), "Back lands on the Community feed")
    let bar = app.tabBars.buttons["Community"]
    XCTAssertTrue(bar.waitForExistence(timeout: 5))
    // The bar must now be stable: no late hide/show after the pop finished.
    var seen: [Bool] = []
    for _ in 0..<12 { seen.append(bar.exists && bar.isHittable); RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1)) }
    XCTAssertTrue(seen.allSatisfy { $0 }, "The bar flickered after returning: \(seen)")
  }
}
