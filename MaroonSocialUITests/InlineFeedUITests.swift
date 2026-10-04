import XCTest

@MainActor final class InlineFeedUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    if (testRun?.failureCount ?? 0) > 0 {
      let app = XCUIApplication(); print(app.debugDescription)
      let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Feed collapse failure"; attachment.lifetime = .keepAlways; add(attachment)
    }
  }
  private func launch() -> XCUIApplication {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
    let username = app.textFields["username"]; XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText("inline_tester"); app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5)); return app
  }
  private func waitForHittable(_ element: XCUIElement, _ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == %@", NSNumber(value: value)), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 4), .completed, file: file, line: line)
  }
  private func assertComposerVisible(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    let composer = app.buttons["Create post"]
    XCTAssertTrue(composer.isHittable, file: file, line: line)
    XCTAssertGreaterThan(composer.frame.height, 40, file: file, line: line)
    XCTAssertGreaterThanOrEqual(composer.frame.minY, app.frame.minY, file: file, line: line)
    XCTAssertLessThanOrEqual(composer.frame.maxY, app.frame.maxY, file: file, line: line)
    XCTAssertFalse(app.descendants(matching: .any)["startupWordmark"].exists, file: file, line: line)
  }
  func testComposerExpandsInlinePrivacyOptionsAndDraftSurviveAttachmentCancel() {
    let app = launch(); app.buttons["Create post"].tap()
    let editor = app.textViews["postText"]; XCTAssertTrue(editor.waitForExistence(timeout: 3))
    XCTAssertFalse(app.navigationBars["New post"].exists)
    XCTAssertTrue(app.switches["postAnonymous"].exists); XCTAssertTrue(app.switches["postAcceptDMs"].exists)
    editor.tap(); editor.typeText("Inline post draft stays here")
    app.buttons["Post attachments"].tap(); app.buttons["postKlipyPicker"].tap()
    XCTAssertTrue(app.staticTexts["KLIPY library is being connected"].waitForExistence(timeout: 3))
    app.buttons["klipyCancel"].tap()
    XCTAssertEqual(editor.value as? String, "Inline post draft stays here")
    app.buttons["Cancel"].tap()
    XCTAssertTrue(app.alerts["Discard this post draft?"].waitForExistence(timeout: 3))
    app.alerts.buttons["Keep editing"].tap()
    XCTAssertEqual(editor.value as? String, "Inline post draft stays here")
    app.buttons["publishPost"].tap()
    XCTAssertTrue(app.buttons["Inline post draft stays here"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Create post"].exists)
  }
  func testScrollingCollapsesBarsKeepsComposerAndRestoresNavigation() {
    let app = launch()
    let picker = app.buttons["communityPicker"]
    waitForHittable(picker, true)
    XCTAssertTrue(app.buttons["Search posts"].isHittable)
    XCTAssertTrue(app.buttons["Profile and settings"].isHittable)
    assertComposerVisible(app)
    // Three short seed cards can fit the viewport and only rubber-band. Create
    // enough real fixture content to test an actual downward/upward scroll.
    app.buttons["Create post"].tap()
    let editor = app.textViews["postText"]; XCTAssertTrue(editor.waitForExistence(timeout: 3))
    editor.tap(); editor.typeText(String(repeating: "A longer campus conversation makes this feed scrollable. ", count: 12))
    app.buttons["publishPost"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 3))
    let feed = app.scrollViews["communityFeed"]
    XCTAssertTrue(feed.waitForExistence(timeout: 3))
    feed.swipeUp(velocity: .slow)
    // The header remains mounted during its slide. Test user-visible endpoints,
    // not removal from the view hierarchy or a particular animation duration.
    waitForHittable(picker, false)
    waitForHittable(app.buttons["Search posts"], false)
    waitForHittable(app.buttons["Profile and settings"], false)
    waitForHittable(app.tabBars.buttons["Classes"], false)
    assertComposerVisible(app)
    feed.swipeDown(velocity: .slow)
    waitForHittable(picker, true)
    waitForHittable(app.buttons["Search posts"], true)
    waitForHittable(app.buttons["Profile and settings"], true)
    waitForHittable(app.tabBars.buttons["Classes"], true)
    assertComposerVisible(app)
    feed.swipeUp(velocity: .slow)
    waitForHittable(picker, false)
    waitForHittable(app.tabBars.buttons["Classes"], false)
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
    start.press(forDuration: 0.05, thenDragTo: end)
    waitForHittable(app.tabBars.buttons["Classes"], true)
    XCTAssertTrue(app.tabBars.buttons["Community"].isSelected, "A homepage swipe must stay on Community")
    XCTAssertTrue(app.buttons["Hot"].isSelected)
    app.tabBars.buttons["Classes"].tap()
    XCTAssertTrue(app.textFields["courseSearch"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.navigationBars.staticTexts["Classes"].exists)
    app.tabBars.buttons["Community"].tap()
    waitForHittable(picker, true)
    assertComposerVisible(app)
    // Header actions must remain usable after UIKit restores the native bar.
    app.buttons["Search posts"].tap()
    let search = app.textFields["postSearch"]
    XCTAssertTrue(search.waitForExistence(timeout: 3))
    search.tap(); search.typeText("ZZZRESTOREDHEADER")
    XCTAssertTrue(app.staticTexts["No matching posts"].waitForExistence(timeout: 3))
    XCTAssertEqual(search.value as? String, "ZZZRESTOREDHEADER")
    // Changing a query after scrolling restored results must also release the
    // old lazy row positions, without requiring the search row to reopen.
    app.buttons["Clear search"].tap()
    feed.swipeUp(velocity: .slow)
    search.tap(); search.typeText("ZZZSCROLLEDRESULTS")
    XCTAssertTrue(app.staticTexts["No matching posts"].waitForExistence(timeout: 3))
    XCTAssertEqual(search.value as? String, "ZZZSCROLLEDRESULTS")
  }
  func testPullRefreshRetainsFeedComposerAndRootNavigation() {
    let app = launch()
    let feed = app.scrollViews["communityFeed"]
    let existingPost = app.buttons["The walk to class is somehow uphill in both directions."]
    XCTAssertTrue(feed.waitForExistence(timeout: 3))
    XCTAssertTrue(existingPost.exists)
    let start = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
    // A small pull should settle without hiding the header; immediately pulling
    // again must remain responsive while the network request is throttled.
    let shortEnd = start.withOffset(CGVector(dx: 0, dy: 80))
    start.press(forDuration: 0.1, thenDragTo: shortEnd)
    waitForHittable(app.buttons["communityPicker"], true)
    let end = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
    start.press(forDuration: 0.1, thenDragTo: end)
    start.press(forDuration: 0.1, thenDragTo: end)
    // Fixture refresh completes immediately. The native refresh-control tests
    // hold their async action to verify the loading state; this checks that a
    // real pull gesture preserves the user-facing feed and navigation endpoint.
    waitForHittable(app.buttons["communityPicker"], true)
    waitForHittable(app.tabBars.buttons["Community"], true)
    XCTAssertTrue(app.tabBars.buttons["Community"].isSelected)
    XCTAssertTrue(existingPost.exists)
    XCTAssertFalse(app.descendants(matching: .any)["startupWordmark"].exists)
    XCTAssertFalse(app.staticTexts["startupStatus"].exists)
    assertComposerVisible(app)
    let refresh = app.descendants(matching: .any)["maroonRefreshControl"]
    let finished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false OR label != %@", "Refreshing"), object: refresh)
    XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 4), .completed)
    app.buttons["Create post"].tap()
    XCTAssertTrue(app.textViews["postText"].waitForExistence(timeout: 3))
  }
}
