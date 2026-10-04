import XCTest

@MainActor final class PostFeaturesUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  private func launch() -> XCUIApplication {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
    let username = app.textFields["username"]; XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText("poll_tester"); app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5)); app.buttons["Create post"].tap()
    return app
  }
  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    let panel = app.scrollViews["postOptions"]
    for _ in 0..<5 { if element.isHittable { return }; panel.swipeUp(velocity: .slow) }
    XCTAssertTrue(element.isHittable)
  }
  private func fill(_ id: String, _ text: String, in app: XCUIApplication) {
    let field = app.textFields[id]; reveal(field, in: app); field.tap(); field.typeText(text)
  }
  func testPollOnlyPostAllowsAuthorVoteAndChangeWithoutAddingVotes() {
    let app = launch(); app.buttons["postAddPoll"].tap()
    XCTAssertFalse(app.buttons["publishPost"].isEnabled)
    fill("pollQuestion", "Where should we study?", in: app)
    fill("pollOption0", "Library", in: app); fill("pollOption1", "Coffee", in: app)
    XCTAssertTrue(app.buttons["publishPost"].isEnabled)
    app.buttons["publishPost"].tap()
    XCTAssertTrue(app.staticTexts["Where should we study?"].waitForExistence(timeout: 5))
    let library = app.buttons["Library"]; let coffee = app.buttons["Coffee"]
    XCTAssertTrue(library.isEnabled); library.tap()
    XCTAssertTrue(app.staticTexts["1 vote"].waitForExistence(timeout: 3))
    XCTAssertEqual(library.value as? String, "1 votes, 100 percent")
    coffee.tap()
    let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1 votes, 100 percent"), object: coffee)
    XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed)
    XCTAssertEqual(library.value as? String, "0 votes, 0 percent")
    XCTAssertTrue(app.staticTexts["1 vote"].exists)
  }
  func testLinkAndTagsWithoutBodyCreateScopedTagNavigation() {
    let app = launch(); app.buttons["postAddLink"].tap(); fill("postLink", "tamu.edu/academics", in: app)
    // Return to the compact feature toolbar, preserving the URL draft.
    app.scrollViews["postOptions"].swipeDown(velocity: .slow)
    app.buttons["postAddTags"].tap(); fill("postTags", "#Campus, study_group", in: app)
    app.buttons["publishPost"].tap()
    XCTAssertTrue(app.buttons["postLinkCard"].waitForExistence(timeout: 5))
    let tag = app.buttons["postTag-campus"]; XCTAssertTrue(tag.waitForExistence(timeout: 3)); tag.tap()
    XCTAssertTrue(app.navigationBars["#campus"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["postLinkCard"].exists)
    XCTAssertEqual(app.staticTexts["tagCommunity"].label, "Texas A&M")
  }
  func testFeatureDraftSurvivesMediaCancelAndRequiresExplicitDiscard() {
    let app = launch(); app.buttons["postAddPoll"].tap()
    fill("pollQuestion", "Keep this question", in: app)
    app.buttons["Post attachments"].tap(); app.buttons["postKlipyPicker"].tap()
    XCTAssertTrue(app.staticTexts["KLIPY library is being connected"].waitForExistence(timeout: 3))
    app.buttons["klipyCancel"].tap()
    let question = app.textFields["pollQuestion"]; reveal(question, in: app)
    XCTAssertEqual(question.value as? String, "Keep this question")
    let cancel = app.buttons["Cancel"]; reveal(cancel, in: app); cancel.tap()
    XCTAssertTrue(app.alerts["Discard this post draft?"].waitForExistence(timeout: 3))
    app.alerts.buttons["Keep editing"].tap()
    app.buttons["hideKeyboard"].tap()
    reveal(cancel, in: app); cancel.tap(); app.alerts.buttons["Discard draft"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 3))
    app.buttons["Create post"].tap()
    XCTAssertFalse(app.textFields["pollQuestion"].exists)
    XCTAssertFalse(app.buttons["publishPost"].isEnabled)
  }
}
