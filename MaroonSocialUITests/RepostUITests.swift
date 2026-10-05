import XCTest

@MainActor final class RepostUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    if (testRun?.failureCount ?? 0) > 0 {
      let app = XCUIApplication(); print(app.debugDescription)
      let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Repost failure"; attachment.lifetime = .keepAlways; add(attachment)
    }
  }
  private func launch() -> XCUIApplication {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
    let username = app.textFields["username"]; XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText("repost_tester"); app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5)); return app
  }
  private func reveal(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 5) {
    for _ in 0..<attempts where !element.isHittable { app.scrollViews["communityFeed"].swipeUp(velocity: .slow) }
    XCTAssertTrue(element.isHittable, "Expected control to be visible: \(element)")
  }
  func testSeededQuoteCardsRepostComposerAndPublishedQuote() {
    let app = launch()
    let feed = app.scrollViews["communityFeed"]
    let unavailable = feed.descendants(matching: .any)["quoteUnavailable"].firstMatch
    XCTAssertTrue(unavailable.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["This post is unavailable"].exists)
    let seededQuote = feed.descendants(matching: .any)["postQuote-demo-coffee-post"].firstMatch
    XCTAssertTrue(seededQuote.exists)
    XCTAssertTrue(feed.buttons["Confirmed: this is how I passed CHEM"].exists, "The quoting post's body is its thread link")
    // The card is one navigation button, so its name, age and excerpt read as a single label.
    XCTAssertTrue(seededQuote.label.contains("Unofficial campus rule: getting coffee counts as being productive."), seededQuote.label)
    XCTAssertTrue(seededQuote.label.hasPrefix("@demo-espresso"), seededQuote.label)
    let repost = app.buttons["repostPost-demo-coffee-post"]
    reveal(repost, in: app)
    XCTAssertEqual(repost.label, "Repost, 1 repost")
    repost.tap()
    let options = app.scrollViews["postOptions"]
    XCTAssertTrue(options.waitForExistence(timeout: 3))
    XCTAssertTrue(app.textViews["postText"].exists)
    let composerQuote = options.descendants(matching: .any)["postQuote-demo-coffee-post"].firstMatch
    XCTAssertTrue(composerQuote.waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["publishPost"].isEnabled, "A quote alone is a complete post")
    app.buttons["removeQuote"].tap()
    XCTAssertFalse(composerQuote.exists)
    XCTAssertFalse(app.buttons["publishPost"].isEnabled)
    app.buttons["closePostComposer"].tap()
    reveal(repost, in: app)
    repost.tap()
    XCTAssertTrue(composerQuote.waitForExistence(timeout: 3))
    let editor = app.textViews["postText"]
    editor.tap(); editor.typeText("Quoting the coffee rule")
    app.buttons["publishPost"].tap()
    let published = app.buttons["Quoting the coffee rule"]
    XCTAssertTrue(published.waitForExistence(timeout: 5))
    XCTAssertFalse(options.exists)
    let quotes = feed.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", "postQuote-demo-coffee-post"))
    XCTAssertGreaterThanOrEqual(quotes.count, 2, "The new post carries its own quote card beside the seeded one")
    XCTAssertLessThan(published.frame.minY, quotes.element(boundBy: 0).frame.minY, "The published post leads the feed with its quote card beneath its text")
    let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Published repost"; shot.lifetime = .keepAlways; add(shot)
    reveal(repost, in: app)
    XCTAssertEqual(repost.label, "Repost, 2 reposts")
  }
  func testThreadRepostOpensSheetComposerWithQuote() {
    let app = launch()
    let seededQuote = app.scrollViews["communityFeed"].descendants(matching: .any)["postQuote-demo-coffee-post"].firstMatch
    XCTAssertTrue(seededQuote.waitForExistence(timeout: 5))
    seededQuote.tap()
    XCTAssertTrue(app.descendants(matching: .any)["threadOriginalPost"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Unofficial campus rule: getting coffee counts as being productive."].exists, "The quote card opens the quoted post")
    // The thread card keeps its existing `threadOriginalPost` identifier on every child, so address the action by label.
    let threadRepost = app.buttons.matching(NSPredicate(format: "identifier == 'threadOriginalPost' AND label BEGINSWITH 'Repost'")).firstMatch
    XCTAssertEqual(threadRepost.label, "Repost, 1 repost")
    threadRepost.tap()
    XCTAssertTrue(app.staticTexts["Quote post"].waitForExistence(timeout: 3))
    let composerQuote = app.scrollViews["postOptions"].descendants(matching: .any)["postQuote-demo-coffee-post"].firstMatch
    XCTAssertTrue(composerQuote.waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["publishPost"].isEnabled)
    app.buttons["closePostComposer"].tap()
    XCTAssertFalse(app.staticTexts["Quote post"].waitForExistence(timeout: 2))
  }
}
