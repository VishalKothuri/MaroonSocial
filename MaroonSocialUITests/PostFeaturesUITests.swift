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
  private func fill(_ id: String, _ text: String, in app: XCUIApplication) {
    let field = app.textFields[id]; app.revealInComposer(field); field.tap(); field.typeText(text)
  }
  /// With a poll on, the post text is the question.
  private func ask(_ question: String, in app: XCUIApplication) {
    let editor = app.textViews["postText"]; app.revealInComposer(editor); editor.tap(); editor.typeText(question)
  }
  func testPollOnlyPostAllowsAuthorVoteAndChangeWithoutAddingVotes() {
    let app = launch(); app.buttons["postAddPoll"].tap()
    XCTAssertFalse(app.buttons["publishPost"].isEnabled)
    XCTAssertTrue(app.buttons["postAddPoll"].isSelected)
    ask("Where should we study?", in: app)
    fill("pollOption0", "Library", in: app); fill("pollOption1", "Coffee", in: app)
    app.pickPostTopic()
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
    // The tool row stays in the card, under the link field.
    let tags = app.buttons["postAddTags"]; app.revealInComposer(tags); tags.tap(); fill("postTags", "#Campus, study_group", in: app)
    XCTAssertEqual(app.textFields["postLink"].value as? String, "tamu.edu/academics")
    app.pickPostTopic()
    app.buttons["publishPost"].tap()
    XCTAssertTrue(app.buttons["postLinkCard"].waitForExistence(timeout: 5))
    let tag = app.buttons["postTag-campus"]; XCTAssertTrue(tag.waitForExistence(timeout: 3)); tag.tap()
    XCTAssertTrue(app.navigationBars["#campus"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["postLinkCard"].exists)
    XCTAssertEqual(app.staticTexts["tagCommunity"].label, "Texas A&M")
  }
  func testFeatureDraftSurvivesMediaCancelAndRequiresExplicitDiscard() {
    let app = launch(); app.buttons["postAddPoll"].tap()
    ask("Keep this question", in: app)
    fill("pollOption0", "Library", in: app)
    let gif = app.buttons["postKlipyPicker"]; app.revealInComposer(gif); gif.tap()
    XCTAssertTrue(app.staticTexts["KLIPY library is being connected"].waitForExistence(timeout: 3))
    app.buttons["klipyCancel"].tap()
    let editor = app.textViews["postText"]; XCTAssertTrue(editor.waitForExistence(timeout: 3))
    XCTAssertEqual(editor.value as? String, "Keep this question")
    XCTAssertEqual(app.textFields["pollOption0"].value as? String, "Library")
    let discard = app.buttons["postDiscard"]; app.revealInComposer(discard); discard.tap()
    XCTAssertTrue(app.alerts["Discard this post draft?"].waitForExistence(timeout: 3))
    app.alerts.buttons["Keep editing"].tap()
    app.buttons["hideKeyboard"].tap()
    app.revealInComposer(discard); discard.tap(); app.alerts.buttons["Discard draft"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 3))
    app.buttons["Create post"].tap()
    XCTAssertTrue(app.textViews["postText"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.textViews["postText"].value as? String ?? "", "")
    XCTAssertFalse(app.textFields["pollOption0"].exists)
    XCTAssertFalse(app.buttons["postAddPoll"].isSelected)
    XCTAssertFalse(app.buttons["postDiscard"].exists, "Discard shows only when the draft has content")
    XCTAssertFalse(app.buttons["publishPost"].isEnabled)
  }
}
