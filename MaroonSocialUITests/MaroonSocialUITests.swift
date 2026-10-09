import XCTest

/// Native rendering/input tests use an isolated local fixture account.
/// They do not assert that fixture mutations prove network delivery. Live protocols
/// are covered separately by tools/test-social.py, test-tag.py and game tests.
@MainActor
final class MaroonSocialUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    if (testRun?.failureCount ?? 0) > 0 {
      let app = XCUIApplication()
      print(app.debugDescription)
      shot(app, "Failure state")
    }
  }

  private func launch(onboard: Bool = true, accessibilityText: Bool = false, hiddenFeatures: Bool = false) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    // 8 Ball, Cup Pong and Campus Tag are hidden in the app; their journeys turn them back on.
    if hiddenFeatures { app.launchArguments += ["--enable-hidden-features"] }
    if accessibilityText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
    app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10))
    if onboard {
      username.tap()
      username.typeText("testaggie")
      app.switches["adultToggle"].tap()
      app.buttons["enterPreview"].tap()
      XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    }
    return app
  }
  private func reveal(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 5) {
    for _ in 0..<attempts where !element.isHittable { app.swipeUp() }
    XCTAssertTrue(element.isHittable, "Expected control to be visible: \(element)")
  }
  private func shot(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  private func back(_ app: XCUIApplication) { app.navigationBars.buttons.element(boundBy: 0).tap() }
  private func button(_ app: XCUIApplication, containing title: String) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
  }
  private func waitEnabled(_ element: XCUIElement, timeout: TimeInterval = 15) {
    let check = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [check], timeout: timeout), .completed)
  }
  private func openGame(_ title: String, app: XCUIApplication) {
    app.tabBars.buttons["Explore"].tap()
    let game = button(app, containing: title)
    reveal(game, in: app)
    game.tap()
    let practice = app.buttons["practiceGame"]
    XCTAssertTrue(practice.waitForExistence(timeout: 5)); practice.tap()
  }

  func testOnboardingInputValidationAndIsolatedRelaunch() {
    let app = launch(onboard: false)
    let field = app.textFields["username"]
    field.tap(); field.typeText("a!")
    XCTAssertFalse(app.buttons["enterPreview"].isEnabled)
    app.switches["adultToggle"].tap()
    XCTAssertFalse(app.buttons["enterPreview"].isEnabled)
    field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "new_aggie")
    XCTAssertTrue(app.buttons["enterPreview"].isEnabled)
    app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    app.terminate()
    app.launchArguments = ["--uitesting-preserve"]
    app.launch()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    app.buttons["Profile and settings"].tap()
    XCTAssertTrue(app.staticTexts["@new_aggie"].waitForExistence(timeout: 3))
    shot(app, "Isolated fixture account settings")
  }

  func testPostEditorAndReplyInput() {
    let app = launch()
    app.buttons["Create post"].tap()
    let post = app.textViews["postText"]
    XCTAssertTrue(post.waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["publishPost"].isEnabled)
    post.tap(); post.typeText("Testing our campus conversation")
    XCTAssertEqual(post.value as? String, "Testing our campus conversation")
    XCTAssertFalse(app.buttons["publishPost"].isEnabled, "On All, a topic is required")
    app.pickPostTopic()
    XCTAssertTrue(app.buttons["publishPost"].isEnabled)
    shot(app, "Post editor typed text")
    app.buttons["publishPost"].tap()
    let created = app.buttons["Testing our campus conversation"]
    XCTAssertTrue(created.waitForExistence(timeout: 5))
    created.tap()
    let reply = app.textFields["replyText"]
    XCTAssertTrue(reply.waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["sendReply"].isEnabled)
    reply.tap(); reply.typeText("See you at Evans library")
    XCTAssertEqual(reply.value as? String, "See you at Evans library")
    XCTAssertTrue(app.buttons["sendReply"].isEnabled)
    shot(app, "Reply composer typed text")
    app.buttons["hideKeyboard"].tap()
    back(app)
    XCTAssertTrue(created.waitForExistence(timeout: 3))
  }

  func testMemeComposerReturnsAttachmentAndProtectsDraft() {
    let app = launch()
    // Media can be chosen directly from the collapsed composer. Opening the
    // text keyboard first needlessly moves the attachment target mid-tap.
    app.buttons["Post attachments"].tap()
    app.buttons["Make a meme"].tap()
    let caption = app.descendants(matching: .any)["memeTopCaption"].firstMatch
    XCTAssertTrue(caption.waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["useMeme"].isEnabled)
    caption.tap(); caption.typeText("WHEN THE GROUP CHAT MAKES A PLAN")
    app.buttons["hideKeyboard"].tap()
    waitEnabled(app.buttons["useMeme"])
    XCTAssertTrue(app.images["memePreview"].exists)
    shot(app, "Dark meme composer live preview")
    app.buttons["useMeme"].tap()
    let attachment = app.buttons["Remove attachment"]
    XCTAssertTrue(attachment.waitForExistence(timeout: 5))
    // A device's first image shows the photo policy once, then offers sharing.
    let understand = app.alerts.buttons["I understand"]
    if understand.waitForExistence(timeout: 3) { understand.tap() }
    if app.buttons["Not now"].waitForExistence(timeout: 3) { app.buttons["Not now"].tap() }
    let discard = app.buttons["postDiscard"]
    app.revealInComposer(discard); discard.tap()
    XCTAssertTrue(app.buttons["Discard draft"].waitForExistence(timeout: 3))
    app.buttons["Keep editing"].tap()
    XCTAssertTrue(attachment.exists)
    app.revealInComposer(discard); discard.tap(); app.buttons["Discard draft"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 3))
  }

  func testCommunitySearchAndSavedEmptyState() {
    let app = launch()
    app.buttons["Search posts"].tap()
    let search = app.textFields["postSearch"]
    XCTAssertTrue(search.waitForExistence(timeout: 3))
    search.tap(); search.typeText("ZZZUNMATCHED")
    XCTAssertTrue(app.descendants(matching: .any)["searchNoMatches"].waitForExistence(timeout: 5))
    app.buttons["Search posts"].tap()
    XCTAssertFalse(search.exists)
    app.buttons["savedPostsFilter"].tap()
    XCTAssertTrue(app.staticTexts["No saved posts"].waitForExistence(timeout: 3))
    app.buttons["savedPostsFilter"].tap()
    XCTAssertTrue(button(app, containing: "Unofficial campus rule").exists)
    shot(app, "Compact community feed")
  }

  func testFeedMessageOpensAnonymousRequestAndProtectsDraft() {
    let app = launch()
    app.buttons["Search posts"].tap()
    let search = app.textFields["postSearch"]
    search.tap(); search.typeText("CHEM 107")
    let messageAuthor = app.buttons["Message the author"].firstMatch
    reveal(messageAuthor, in: app)
    messageAuthor.tap()
    XCTAssertTrue(app.navigationBars["New message"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.textFields["Username"].exists)
    XCTAssertTrue(app.staticTexts["Your username stays hidden. You’ll see each other as You and Them. This identity cannot be changed in this conversation."].exists)
    XCTAssertFalse(app.textFields["requestUsername"].exists)
    let send = app.navigationBars.buttons["Send"]
    XCTAssertFalse(send.isEnabled)
    let request = app.descendants(matching: .any)["requestText"].firstMatch
    request.tap(); request.typeText("Which coffee spot would you recommend?")
    XCTAssertTrue(send.isEnabled)
    shot(app, "Feed action opens anonymous message request")
    app.buttons["Cancel"].tap()
    XCTAssertTrue(app.buttons["Keep editing"].waitForExistence(timeout: 3))
    app.buttons["Discard draft"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 3))
  }

  func testEmailRecoveryShowsUnavailableStateWithoutSending() {
    let app = launch()
    app.buttons["Profile and settings"].tap()
    app.buttons["Link personal email for recovery"].tap()
    XCTAssertTrue(app.staticTexts["Email login is not available yet"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.textFields["loginEmail"].exists)
    XCTAssertFalse(app.buttons["Send login code"].exists)
    XCTAssertTrue(app.buttons["Check again"].exists)
    shot(app, "Custom Maroon Social email recovery availability")
  }

  func testCourseSearchAndAddCourseDraft() {
    let app = launch()
    app.tabBars.buttons["Classes"].tap()
    let search = app.textFields["courseSearch"]
    XCTAssertTrue(search.waitForExistence(timeout: 3))
    search.tap(); search.typeText("ZZZUNMATCHED")
    XCTAssertTrue(app.staticTexts["No courses found"].waitForExistence(timeout: 3))
    app.buttons["Clear search"].tap()
    search.tap(); search.typeText("CHEM107")
    XCTAssertTrue(app.buttons["join-CHEM 107"].exists)
    app.buttons["Add by code"].tap()
    XCTAssertTrue(app.navigationBars["Add class"].waitForExistence(timeout: 3))
    let join = app.navigationBars.buttons["Join"]
    XCTAssertFalse(join.isEnabled)
    let code = app.textFields["Course code (e.g. HIST 105)"]
    code.tap(); code.typeText("HIST 105")
    let title = app.staticTexts["officialCourseTitle"]
    XCTAssertTrue(title.waitForExistence(timeout: 3))
    XCTAssertTrue(join.isEnabled)
    XCTAssertTrue(title.label.localizedCaseInsensitiveContains("history"))
    shot(app, "Add course form accepts input")
    app.buttons["Cancel"].tap()
    XCTAssertTrue(search.waitForExistence(timeout: 3))
  }

  func testActivityFormValidationAndDismissal() {
    let app = launch()
    app.tabBars.buttons["Explore"].tap()
    button(app, containing: "Hangouts").tap()
    app.navigationBars.buttons["Create"].tap()
    let publish = app.buttons["publishActivity"]
    XCTAssertTrue(publish.waitForExistence(timeout: 3))
    XCTAssertFalse(publish.isEnabled)
    let title = app.textFields["activityTitle"]
    title.tap(); title.typeText("Coffee at MSC")
    XCTAssertFalse(publish.isEnabled)
    let place = app.textFields["activityPlace"]
    place.tap(); place.typeText("Memorial Student Center")
    app.buttons["hideKeyboard"].tap()
    let details = app.textViews["activityDetails"]
    reveal(details, in: app); details.tap(); details.typeText("Bring a friend and a favorite mug.")
    XCTAssertEqual(details.value as? String, "Bring a friend and a favorite mug.")
    XCTAssertTrue(publish.isEnabled)
    app.buttons["hideKeyboard"].tap()
    shot(app, "Activity form with working details editor")
    app.buttons["Cancel"].tap()
    XCTAssertTrue(app.buttons["Discard draft"].waitForExistence(timeout: 3))
    app.buttons["Discard draft"].tap()
    XCTAssertTrue(app.navigationBars["Hangouts"].waitForExistence(timeout: 3))
  }

  func testInboxRequestAndNewMessageDraft() {
    let app = launch()
    app.tabBars.buttons["Inbox"].tap()
    app.buttons["inboxRequests"].tap()
    button(app, containing: "Any good coffee spots near campus?").tap()
    XCTAssertTrue(app.staticTexts["Any good coffee spots near campus?"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.textFields["messageText"].exists)
    XCTAssertTrue(app.buttons["declineRequest"].exists)
    back(app)
    app.buttons["New conversation"].tap()
    app.buttons["New message"].tap()
    XCTAssertTrue(app.navigationBars["New message"].waitForExistence(timeout: 3))
    let send = app.navigationBars.buttons["Send"]
    XCTAssertFalse(send.isEnabled)
    let username = app.textFields["Username"]
    username.tap(); username.typeText("studyfriend")
    let message = app.descendants(matching: .any)["requestText"].firstMatch
    message.tap(); message.typeText("Want to study at Evans?")
    XCTAssertEqual(message.value as? String, "Want to study at Evans?")
    XCTAssertTrue(send.isEnabled)
    XCTAssertFalse(app.buttons["Done"].exists)
    XCTAssertTrue(app.buttons["hideKeyboard"].isHittable)
    XCTAssertLessThanOrEqual(message.frame.maxY, app.keyboards.firstMatch.frame.minY)
    shot(app, "Private message request draft")
    app.buttons["Cancel"].tap()
    XCTAssertTrue(app.buttons["Discard draft"].waitForExistence(timeout: 3))
    app.buttons["Discard draft"].tap()
    XCTAssertTrue(app.buttons["newConversation"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.navigationBars["Inbox"].exists)
  }

  func testChatComposerKeepsKeyboardAndDraftThroughSendAndDismissal() {
    let app = launch(); app.tabBars.buttons["Explore"].tap()
    button(app, containing: "Hangouts").tap()
    let plan = button(app, containing: "Coffee"); reveal(plan, in: app); plan.tap()
    let join = app.buttons["joinActivity"]; reveal(join, in: app); join.tap()
    let open = app.buttons["Open group chat"]; reveal(open, in: app); open.tap()
    let input = app.descendants(matching: .any)["messageText"].firstMatch
    XCTAssertTrue(input.waitForExistence(timeout: 3)); input.tap(); input.typeText("First keyboard check")
    let keyboard = app.keyboards.firstMatch
    XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["Done"].exists)
    XCTAssertLessThanOrEqual(input.frame.maxY, keyboard.frame.minY)
    app.buttons["sendMessage"].tap()
    XCTAssertTrue(app.staticTexts["First keyboard check"].waitForExistence(timeout: 5))
    XCTAssertTrue(keyboard.exists, "Sending should not disable the editor and collapse its keyboard")
    input.typeText("Next message draft")
    app.buttons["hideKeyboard"].tap()
    let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: keyboard)
    XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 3), .completed)
    XCTAssertEqual(input.value as? String, "Next message draft")
    input.tap()
    XCTAssertEqual(input.value as? String, "Next message draft")
    XCTAssertLessThanOrEqual(input.frame.maxY, keyboard.frame.minY)
    app.buttons["sendMessage"].tap()
    XCTAssertTrue(app.staticTexts["Next message draft"].waitForExistence(timeout: 5))
    shot(app, "Conversation composer stays above keyboard without Done accessory")
  }

  func testAccessibilityTextKeepsKeyboardDismissalAndMessageInputReachable() {
    let app = launch(accessibilityText: true)
    app.buttons["Create post"].tap()
    let editor = app.textViews["postText"]; XCTAssertTrue(editor.waitForExistence(timeout: 3))
    editor.tap(); editor.typeText("Large text draft")
    let hide = app.buttons["hideKeyboard"]
    XCTAssertTrue(hide.isHittable)
    XCTAssertGreaterThanOrEqual(hide.frame.minX, app.frame.minX)
    XCTAssertLessThanOrEqual(hide.frame.maxX, app.frame.maxX)
    XCTAssertLessThanOrEqual(hide.frame.maxY, app.keyboards.firstMatch.frame.minY)
    hide.tap()
    XCTAssertFalse(app.scrollViews["postOptions"].exists, "The options panel has no scroll box of its own")
    let discard = app.buttons["postDiscard"]
    app.revealInComposer(discard); discard.tap(); app.alerts.buttons["Discard draft"].tap()
    app.tabBars.buttons["Inbox"].tap()
    app.buttons["newConversation"].tap(); app.buttons["New message"].tap()
    let username = app.textFields["requestUsername"]
    username.tap(); username.typeText("studyfriend")
    let request = app.descendants(matching: .any)["requestText"].firstMatch
    reveal(request, in: app); request.tap(); request.typeText("Hello")
    XCTAssertTrue(app.buttons["sendMessageRequest"].isHittable)
    XCTAssertTrue(hide.isHittable)
    XCTAssertLessThanOrEqual(request.frame.maxY, app.keyboards.firstMatch.frame.minY)
    hide.tap()
    XCTAssertEqual(request.value as? String, "Hello")
    shot(app, "Accessible message input without keyboard accessory")
    app.buttons["Cancel"].tap(); app.alerts.buttons["Discard draft"].tap()
  }

  func testCampusUpcomingAndTransitSearch() {
    let app = launch()
    app.tabBars.buttons["Campus"].tap()
    XCTAssertTrue(app.buttons["campusUpcoming"].waitForExistence(timeout: 5))
    app.buttons["campusDay-1"].tap()
    app.buttons["campusUpcoming"].tap()
    app.buttons["savedEventsFilter"].tap()
    XCTAssertTrue(app.staticTexts["No saved events yet"].waitForExistence(timeout: 3))
    app.buttons["savedEventsFilter"].tap()
    shot(app, "Upcoming campus agenda")
    button(app, containing: "Bus routes").tap()
    let search = app.textFields["transitSearch"]
    XCTAssertTrue(search.waitForExistence(timeout: 3))
    search.tap(); search.typeText("ZZZUNMATCHED")
    XCTAssertEqual(search.value as? String, "ZZZUNMATCHED")
    XCTAssertTrue(app.staticTexts["No matching routes"].waitForExistence(timeout: 3))
    app.buttons["hideKeyboard"].tap()
    shot(app, "Transit search empty state")
    back(app)
    XCTAssertTrue(app.buttons["campusUpcoming"].waitForExistence(timeout: 3))
  }

  func testLocalChessLegalMoveAndUndo() {
    let app = launch()
    openGame("Chess", app: app)
    let status = app.staticTexts["chessStatus"]
    XCTAssertTrue(status.waitForExistence(timeout: 4))
    let labeled = app.switches["Show labeled board"]
    reveal(labeled, in: app); labeled.tap()
    reveal(app.buttons["square-e2"], in: app)
    app.buttons["square-e2"].tap(); app.buttons["square-e4"].tap()
    XCTAssertEqual(status.label, "Black to move")
    shot(app, "Local chess legal move")
    let undo = app.buttons["Undo"]
    reveal(undo, in: app); undo.tap()
    XCTAssertEqual(status.label, "White to move")
  }

  func testLocalPhysicsGameControlsAndReplay() {
    let app = launch(hiddenFeatures: true)
    openGame("8 Ball", app: app)
    let shotButton = app.webViews.buttons["Take shot"]
    XCTAssertTrue(shotButton.waitForExistence(timeout: 15))
    XCTAssertTrue(shotButton.isHittable)
    XCTAssertTrue(app.webViews.sliders["Shot power"].isHittable)
    shot(app, "Local pool complete viewport")
    shotButton.tap()
    let replay = app.webViews.buttons["Replay last shot"]
    waitEnabled(replay)
    XCTAssertTrue(shotButton.isEnabled)
    replay.tap()
    waitEnabled(replay)
    back(app)
    back(app)
    let pong = button(app, containing: "Cup Pong")
    reveal(pong, in: app); pong.tap()
    let practice = app.buttons["practiceGame"]
    XCTAssertTrue(practice.waitForExistence(timeout: 5)); practice.tap()
    let throwButton = app.webViews.buttons["Throw ball"]
    XCTAssertTrue(throwButton.waitForExistence(timeout: 15))
    XCTAssertTrue(throwButton.isHittable)
    XCTAssertTrue(app.webViews.sliders["Shot power"].isHittable)
    throwButton.tap()
    waitEnabled(app.webViews.buttons["Replay last shot"])
    XCTAssertTrue(throwButton.isEnabled)
    shot(app, "Local pong after throw")
  }
}
