import XCTest

/// File-backed fixture relaunch checks. These do not deliver a live request or group.
@MainActor final class DurableDraftsUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  private func launch() -> XCUIApplication {
    let app=XCUIApplication();app.launchArguments=["--uitesting"];app.launch()
    let username=app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout:10));username.tap();username.typeText("draft_tester")
    let adult=app.switches["adultToggle"]
    (adult.switches.firstMatch.exists ? adult.switches.firstMatch:adult).tap()
    app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout:5))
    return app
  }
  private func relaunch(_ app:XCUIApplication) {
    app.terminate();app.launchArguments=["--uitesting-preserve"];app.launch()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout:10))
  }
  private func field(_ id:String,_ app:XCUIApplication)->XCUIElement {app.descendants(matching:.any).matching(identifier:id).firstMatch}
  private func openRequest(_ app:XCUIApplication) {
    app.tabBars.buttons["Inbox"].tap();app.buttons["newConversation"].tap();app.buttons["New message"].tap()
    XCTAssertTrue(app.textFields["requestUsername"].waitForExistence(timeout:3))
  }
  private func enter(_ id:String,_ value:String,_ app:XCUIApplication) {
    let input=field(id,app);XCTAssertTrue(input.waitForExistence(timeout:3));input.tap();input.typeText(value)
    let done=app.buttons["hideKeyboard"].firstMatch
    if done.waitForExistence(timeout:2){done.tap()}
  }
  func testNamedRequestRestoresSameRecipientAndDiscardSurvivesRelaunch() {
    let app=launch();openRequest(app)
    enter("requestUsername","same_recipient",app);enter("requestText","A request I have not sent",app)
    app.buttons["Cancel"].tap();app.alerts.buttons["Save and close"].tap()
    XCTAssertTrue(app.buttons["newConversation"].waitForExistence(timeout:3))
    relaunch(app);openRequest(app)
    XCTAssertEqual(app.textFields["requestUsername"].value as? String,"same_recipient")
    XCTAssertEqual(field("requestText",app).value as? String,"A request I have not sent")
    app.buttons["Cancel"].tap();app.alerts.buttons["Discard draft"].tap()
    XCTAssertTrue(app.buttons["newConversation"].waitForExistence(timeout:3))
    relaunch(app);openRequest(app)
    XCTAssertNotEqual(app.textFields["requestUsername"].value as? String,"same_recipient")
    XCTAssertNotEqual(field("requestText",app).value as? String,"A request I have not sent")
  }
  func testPollDraftKeepsItsQuestionTextAndChoicesAcrossRelaunch() {
    let app=launch();app.buttons["Create post"].tap()
    let editor=app.textViews["postText"];XCTAssertTrue(editor.waitForExistence(timeout:3))
    app.buttons["postAddPoll"].tap()
    // The post text is the poll's question; Return in a choice moves to the next one.
    editor.tap();editor.typeText("Which dining hall?")
    let first=app.textFields["pollOption0"];app.revealInComposer(first);first.tap();first.typeText("Sbisa\n")
    app.textFields["pollOption1"].typeText("Commons")
    app.buttons["closePostComposer"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout:3))
    Thread.sleep(forTimeInterval:1)
    relaunch(app);app.buttons["Create post"].tap()
    XCTAssertTrue(editor.waitForExistence(timeout:3))
    XCTAssertEqual(editor.value as? String,"Which dining hall?")
    XCTAssertTrue(app.buttons["postAddPoll"].isSelected)
    XCTAssertEqual(app.textFields["pollOption0"].value as? String,"Sbisa")
    XCTAssertEqual(app.textFields["pollOption1"].value as? String,"Commons")
    XCTAssertEqual(app.descendants(matching:.any)["postCharacterCount"].label,"18 of 180 characters")
    let discard=app.buttons["postDiscard"];app.revealInComposer(discard);discard.tap();app.alerts.buttons["Discard draft"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout:3))
  }
  func testGroupDetailsRestoreAfterExplicitSaveAndDeviceRelaunch() {
    let app=launch();app.tabBars.buttons["Inbox"].tap()
    app.buttons["newConversation"].tap();app.buttons["New group"].tap()
    enter("groupName","Durable group draft",app)
    enter("groupDescription","This unfinished group should remain on this device.",app)
    app.buttons["groupCancel"].tap();app.alerts.buttons["Save and close"].tap()
    XCTAssertTrue(app.buttons["newConversation"].waitForExistence(timeout:3))
    relaunch(app);app.tabBars.buttons["Inbox"].tap()
    app.buttons["newConversation"].tap();app.buttons["New group"].tap()
    XCTAssertTrue(field("groupName",app).waitForExistence(timeout:3))
    XCTAssertEqual(field("groupName",app).value as? String,"Durable group draft")
    XCTAssertEqual(field("groupDescription",app).value as? String,"This unfinished group should remain on this device.")
    XCTAssertEqual(app.staticTexts["groupStepTitle"].label,"Group details")
    app.buttons["groupCancel"].tap();app.alerts.buttons["Discard draft"].tap()
  }
}
