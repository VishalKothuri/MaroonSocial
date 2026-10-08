import XCTest

/// The simplified composer: a maroon card (text, inline poll/link/hashtags/media, one tool row
/// ending in Send) over a grey panel without a scroll box of its own. The expanded composer
/// scrolls as one region only when it is taller than the space above the keyboard.
@MainActor final class ComposerLayoutUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    if (testRun?.failureCount ?? 0) > 0 {
      let app = XCUIApplication(); print(app.debugDescription)
      shot(app, "Composer failure")
    }
  }
  private func launch(accessibility3: Bool = false) -> XCUIApplication {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]
    if accessibility3 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"] }
    app.launch()
    let username = app.textFields["username"]; XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText("composer_tester"); app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    return app
  }
  private func shot(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
  }
  private func open(_ app: XCUIApplication) -> XCUIElement {
    app.buttons["Create post"].tap()
    let editor = app.textViews["postText"]; XCTAssertTrue(editor.waitForExistence(timeout: 3))
    return editor
  }
  private func waitForKeyboard(_ app: XCUIApplication) -> XCUIElement {
    let keyboard = app.keyboards.firstMatch; XCTAssertTrue(keyboard.waitForExistence(timeout: 3)); return keyboard
  }
  /// Waits for the composer's own scroll-into-view of the focused field to settle.
  private func settle() { Thread.sleep(forTimeInterval: 0.8) }

  func testPollOnlyPostFromTheCardNeedsNoInnerScroll() {
    let app = launch()
    let editor = open(app)
    app.pickPostTopic()
    let poll = app.buttons["postAddPoll"]
    XCTAssertEqual(poll.label, "Add poll")
    poll.tap()
    XCTAssertTrue(poll.isSelected); XCTAssertEqual(poll.label, "Remove poll")
    XCTAssertFalse(app.textFields["pollQuestion"].exists, "The post text is the question")
    app.buttons["pollDuration"].tap()
    let threeDays = app.buttons["3 days"]; XCTAssertTrue(threeDays.waitForExistence(timeout: 3)); threeDays.tap()
    XCTAssertEqual(app.buttons["pollDuration"].value as? String, "3 days")
    editor.tap(); editor.typeText("Where should we study tonight?")
    let counter = app.descendants(matching: .any)["postCharacterCount"]
    XCTAssertEqual(counter.label, "30 of 180 characters", "With a poll the counter counts to 180")
    let first = app.textFields["pollOption0"]; first.tap(); first.typeText("Library\n")
    // Return moved the keyboard to the next choice.
    let second = app.textFields["pollOption1"]; second.typeText("Coffee shop")
    let keyboard = waitForKeyboard(app)
    settle()
    // Nothing inside the composer scrolls on its own, and Send is in reach without scrolling.
    XCTAssertFalse(app.scrollViews["postOptions"].exists)
    XCTAssertTrue(app.otherElements["postOptions"].exists || app.descendants(matching: .any)["postOptions"].exists)
    let send = app.buttons["publishPost"]
    XCTAssertTrue(send.isEnabled); XCTAssertTrue(send.isHittable)
    XCTAssertLessThanOrEqual(send.frame.maxY, keyboard.frame.minY, "Send sits above the keyboard")
    XCTAssertTrue(second.isHittable); XCTAssertTrue(first.isHittable)
    XCTAssertGreaterThanOrEqual(editor.frame.minY, app.scrollViews["postComposer"].frame.minY - 1, "The card is not scrolled")
    XCTAssertLessThan(first.frame.minY, send.frame.minY, "Choices sit above Send")
    shot(app, "Poll from the card, keyboard up")
    send.tap()
    XCTAssertTrue(app.staticTexts["Where should we study tonight?"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Library"].exists); XCTAssertTrue(app.buttons["Coffee shop"].exists)
    XCTAssertTrue(app.buttons["Create post"].exists)
    // The post's words are its poll question, and search finds them.
    app.buttons["Search posts"].firstMatch.tap()
    let search = app.textFields["postSearch"]; XCTAssertTrue(search.waitForExistence(timeout: 3))
    search.tap(); search.typeText("study tonight")
    XCTAssertTrue(app.staticTexts["Where should we study tonight?"].waitForExistence(timeout: 3), "Search matches a poll question")
  }

  func testRemovingTheToolTurnsItOffAndQuestionLimitBlocksSend() {
    let app = launch()
    let editor = open(app)
    app.pickPostTopic()
    app.buttons["postAddPoll"].tap()
    editor.tap(); editor.typeText(String(repeating: "q", count: 181))
    for (index, text) in ["A", "B"].enumerated() { let field = app.textFields["pollOption\(index)"]; app.revealInComposer(field); field.tap(); field.typeText(text) }
    XCTAssertFalse(app.buttons["publishPost"].isEnabled, "A question over 180 characters cannot be sent")
    let error = app.staticTexts["inlinePostError"]; app.revealInComposer(error)
    XCTAssertEqual(error.label, "With a poll, your post is the question: 1–180 characters.")
    let remove = app.buttons["removePoll"]; app.revealInComposer(remove); remove.tap()
    XCTAssertFalse(app.textFields["pollOption0"].exists)
    XCTAssertFalse(app.buttons["postAddPoll"].isSelected)
    XCTAssertEqual(app.descendants(matching: .any)["postCharacterCount"].label, "181 of 1,000 characters")
    XCTAssertTrue(app.buttons["publishPost"].isEnabled, "Without the poll the same text is a post")
    let link = app.buttons["postAddLink"]; app.revealInComposer(link); link.tap()
    XCTAssertTrue(app.textFields["postLink"].waitForExistence(timeout: 3)); XCTAssertTrue(link.isSelected)
    link.tap()
    XCTAssertFalse(app.textFields["postLink"].exists, "Tapping an active tool turns it off")
  }

  func testLayoutAtDefaultTextSize() {
    let app = launch()
    shot(app, "after-1-collapsed")
    _ = open(app)
    _ = waitForKeyboard(app); settle()
    XCTAssertTrue(app.buttons["publishPost"].isHittable)
    XCTAssertFalse(app.buttons["postDiscard"].exists, "An empty draft has nothing to discard")
    shot(app, "after-2-expanded-empty")
    fourChoicePoll(app)
    shot(app, "after-3-poll-4-choices-keyboard")
    app.terminate()
    let fresh = launch()
    imageLinkAndHashtags(fresh)
    shot(fresh, "after-4-image-link-hashtags")
    fresh.buttons["hideKeyboard"].tap(); settle()
    shot(fresh, "after-4b-image-link-hashtags-no-keyboard")
  }

  func testLayoutAtAccessibility3() {
    let app = launch(accessibility3: true)
    _ = open(app)
    _ = waitForKeyboard(app); settle()
    shot(app, "after-5-ax3-expanded-empty")
    fourChoicePoll(app)
    shot(app, "after-6-ax3-poll-4-choices-keyboard")
    // Scrolling the card up keeps Send pinned and shows the question again.
    let editor = app.textViews["postText"]; app.revealInComposer(editor)
    let composer = app.scrollViews["postComposer"]
    for _ in 0..<3 where editor.frame.minY < composer.frame.minY {
      let start = composer.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 16, dy: max(20, editor.frame.maxY - composer.frame.minY)))
      start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 60)), withVelocity: .slow, thenHoldForDuration: 0.3)
    }
    XCTAssertGreaterThanOrEqual(editor.frame.minY, composer.frame.minY - 1, "The whole question is back in view")
    XCTAssertTrue(app.buttons["publishPost"].isHittable, "Send stays pinned while the card scrolls")
    shot(app, "after-6b-ax3-poll-question-with-send")
    app.terminate()
    let fresh = launch(accessibility3: true)
    imageLinkAndHashtags(fresh)
    shot(fresh, "after-7-ax3-image-link-hashtags")
    fresh.buttons["hideKeyboard"].tap(); settle()
    let top = fresh.textViews["postText"]; fresh.revealInComposer(top)
    shot(fresh, "after-7a-ax3-image-link-hashtags-no-keyboard")
    let anonymous = fresh.switches["postAnonymous"]; fresh.revealInComposer(anonymous)
    shot(fresh, "after-7b-ax3-panel")
  }

  /// A 4-choice poll typed from the card, ending with the keyboard up in the last choice.
  private func fourChoicePoll(_ app: XCUIApplication) {
    let editor = app.textViews["postText"]
    app.buttons["postAddPoll"].tap()
    app.revealInComposer(editor); editor.tap(); editor.typeText("Best study spot on campus?")
    let first = app.textFields["pollOption0"]; app.revealInComposer(first); first.tap()
    // Return moves to the next choice and, from the last filled one, adds another (up to four).
    first.typeText("Evans\n")
    app.textFields["pollOption1"].typeText("MSC\n")
    XCTAssertTrue(app.textFields["pollOption2"].waitForExistence(timeout: 3))
    app.textFields["pollOption2"].typeText("Library West\n")
    let last = app.textFields["pollOption3"]; XCTAssertTrue(last.waitForExistence(timeout: 3))
    last.typeText("Coffee shop")
    XCTAssertFalse(app.buttons["pollAddOption"].exists, "Four is the limit")
    let keyboard = waitForKeyboard(app); settle()
    XCTAssertFalse(app.scrollViews["postOptions"].exists)
    XCTAssertTrue(last.isHittable, "The focused choice stays in view")
    XCTAssertLessThanOrEqual(last.frame.maxY, keyboard.frame.minY)
    assertSendInReach(app, keyboard)
    // No topic yet and the chips are under the keyboard: the reason sits next to Send, and no
    // rule text fills the panel.
    XCTAssertTrue(app.staticTexts["postTopicReason"].isHittable || app.descendants(matching: .any)["postTopicReason"].isHittable)
    XCTAssertFalse(app.staticTexts["inlinePostError"].exists)
  }
  /// Send and the tool row are on screen above the keyboard, without scrolling.
  private func assertSendInReach(_ app: XCUIApplication, _ keyboard: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    let send = app.buttons["publishPost"]
    XCTAssertTrue(send.isHittable, "Send is in reach with the keyboard up", file: file, line: line)
    XCTAssertLessThanOrEqual(send.frame.maxY, keyboard.frame.minY + 0.5, "Send sits above the keyboard", file: file, line: line)
    XCTAssertTrue(app.buttons["postAddPoll"].isHittable, "The tool row is in reach", file: file, line: line)
  }
  /// A meme image, a link and hashtags, ending with the keyboard up in the hashtags field.
  private func imageLinkAndHashtags(_ app: XCUIApplication) {
    let editor = open(app)
    editor.tap(); editor.typeText("Finals week survival kit")
    let photo = app.buttons["Add photo or video"]; app.revealInComposer(photo); photo.tap()
    app.buttons["Make a meme"].tap()
    let caption = app.descendants(matching: .any)["memeTopCaption"].firstMatch
    XCTAssertTrue(caption.waitForExistence(timeout: 5)); caption.tap(); caption.typeText("STUDY MODE")
    app.buttons["hideKeyboard"].tap()
    let use = app.buttons["useMeme"]
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: use)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed); use.tap()
    // The first image on a device shows the photo policy once, then offers sharing.
    let understand = app.alerts.buttons["I understand"]
    if understand.waitForExistence(timeout: 3) { understand.tap() }
    let notNow = app.buttons["Not now"]
    if notNow.waitForExistence(timeout: 3) { notNow.tap() }
    XCTAssertTrue(app.staticTexts["Image attached"].waitForExistence(timeout: 10))
    let link = app.buttons["postAddLink"]; app.revealInComposer(link); link.tap()
    let linkField = app.textFields["postLink"]; XCTAssertTrue(linkField.waitForExistence(timeout: 3)); linkField.typeText("tamu.edu/academics")
    let tags = app.buttons["postAddTags"]; app.revealInComposer(tags); tags.tap()
    let tagsField = app.textFields["postTags"]; XCTAssertTrue(tagsField.waitForExistence(timeout: 3)); tagsField.typeText("finals study_group")
    _ = waitForKeyboard(app); settle()
    XCTAssertTrue(tagsField.isHittable, "The focused field stays in view")
    XCTAssertFalse(app.scrollViews["postOptions"].exists)
    assertSendInReach(app, app.keyboards.firstMatch)
  }

  func testEmptyPollShowsNoRuleTextAndFieldFillsTakeTaps() {
    let app = launch()
    let editor = open(app)
    let send = app.buttons["publishPost"]
    XCTAssertEqual(send.label, "Send", "The spoken name matches the visible text")
    app.buttons["postAddPoll"].tap()
    XCTAssertFalse(app.staticTexts["inlinePostError"].exists, "A poll just added is incomplete, not wrong")
    editor.typeText("Where should we study?")
    let first = app.textFields["pollOption0"], second = app.textFields["pollOption1"]
    first.tap(); first.typeText("Evans")
    XCTAssertFalse(app.staticTexts["inlinePostError"].exists, "A choice still to type is not an error")
    // A tap on the top edge of the second field's fill, above its line of text, focuses it.
    second.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: -8)).tap()
    XCTAssertEqual(second.value(forKey: "hasKeyboardFocus") as? Bool, true, "The whole fill focuses the field")
    second.typeText("evans")
    let error = app.staticTexts["inlinePostError"]
    XCTAssertTrue(error.waitForExistence(timeout: 3), "A duplicate choice is a broken rule")
    XCTAssertEqual(error.label, "Add 2–4 different choices with 1–80 characters each.")
    shot(app, "after-8-duplicate-choice")
  }
}
