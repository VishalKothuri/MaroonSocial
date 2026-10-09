import XCTest

/// Topic feeds in fixture mode (topics available, seeded posts across topics, Confessions and Memes
/// folded into "More", the topic sheet), plus a server without topics (`--uitesting-no-topics`).
@MainActor final class TopicFeedsUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    if (testRun?.failureCount ?? 0) > 0 {
      let app = XCUIApplication(); print(app.debugDescription)
      let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Topic feed failure"; image.lifetime = .keepAlways; add(image)
    }
  }
  private func launch(_ extra: [String] = [], name: String = "topic_tester") -> XCUIApplication {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"] + extra; app.launch()
    let username = app.textFields["username"]; XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText(name); app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    return app
  }
  private func tab(_ slug: String, in app: XCUIApplication) -> XCUIElement { app.buttons["topicTab-\(slug)"] }
  private func waitSelected(_ element: XCUIElement, _ selected: Bool = true, file: StaticString = #filePath, line: UInt = #line) {
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND selected == %@", NSNumber(value: selected)), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 4), .completed, "\(element) selected == \(selected)", file: file, line: line)
  }
  private func waitGone(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 4), .completed, "\(element) should be gone", file: file, line: line)
  }
  /// A strip tab whose center is on screen (the strip scrolls sideways; off-screen tabs have no hit point).
  private func onScreen(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
    guard element.exists else { return false }
    let frame = element.frame, screen = app.windows.firstMatch.frame
    return !frame.isEmpty && frame.midX > screen.minX + 8 && frame.midX < screen.maxX - 8
  }
  /// Brings a strip tab on screen.
  private func revealTab(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    for _ in 0..<5 where !onScreen(element, in: app) { app.descendants(matching: .any)["topicStrip"].swipeLeft(velocity: .slow) }
    XCTAssertTrue(onScreen(element, in: app), file: file, line: line)
  }
  private let walk = "The walk to class is somehow uphill in both directions."
  private let sports = "Midnight Yell this Friday: who's saving seats?"
  private let meme = "Me sprinting for the bus that was never going to wait"

  func testSelectingATabShowsOnlyThatTopicAndMoreHoldsQuietTopics() {
    let app = launch()
    let all = tab("all", in: app)
    XCTAssertTrue(all.waitForExistence(timeout: 5)); waitSelected(all)
    XCTAssertEqual(all.label, "All topics")
    XCTAssertTrue(app.buttons[walk].waitForExistence(timeout: 3))
    let sportsTab = tab("sports", in: app)
    revealTab(sportsTab, in: app); sportsTab.tap()
    waitSelected(sportsTab); waitSelected(all, false)
    XCTAssertEqual(sportsTab.label, "Sports topic")
    XCTAssertTrue(app.buttons[sports].waitForExistence(timeout: 3), "The Sports post shows under Sports")
    waitGone(app.buttons[walk])
    XCTAssertFalse(app.buttons[meme].exists)
    // New/Hot still applies inside the topic.
    app.buttons["Hot"].tap(); XCTAssertTrue(app.buttons[sports].waitForExistence(timeout: 3)); XCTAssertFalse(app.buttons[walk].exists)
    app.buttons["New"].tap()
    // Quiet topics (fewer than 5 posts in 7 days) wait in "More" (the topic sheet); one chosen there becomes a tab.
    XCTAssertFalse(tab("memes", in: app).exists, "Memes is folded")
    let more = tab("more", in: app)
    revealTab(more, in: app); more.tap()
    XCTAssertTrue(app.descendants(matching: .any)["topicSheet"].waitForExistence(timeout: 3))
    let memesItem = app.buttons["topicSheetItem-memes"]
    XCTAssertTrue(memesItem.waitForExistence(timeout: 3)); memesItem.tap()
    waitGone(app.descendants(matching: .any)["topicSheet"])
    waitSelected(tab("memes", in: app))
    XCTAssertTrue(app.buttons[meme].waitForExistence(timeout: 3)); XCTAssertFalse(app.buttons[sports].exists)
    let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Memes chosen from More"; image.lifetime = .keepAlways; add(image)
    revealTabBack(all, in: app); all.tap()
    waitSelected(all)
    XCTAssertTrue(app.buttons[walk].waitForExistence(timeout: 3), "All restores every post")
    waitGone(tab("memes", in: app))
  }
  private func revealTabBack(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    for _ in 0..<5 where !onScreen(element, in: app) { app.descendants(matching: .any)["topicStrip"].swipeRight(velocity: .slow) }
    XCTAssertTrue(onScreen(element, in: app), file: file, line: line)
  }

  func testComposingInATopicPreselectsItAndThePostShowsItsPill() {
    let app = launch()
    // On All nothing is preselected and Send waits for a topic.
    app.buttons["Create post"].tap()
    let editor = app.textViews["postText"]; XCTAssertTrue(editor.waitForExistence(timeout: 3))
    editor.tap(); editor.typeText("Draft that needs a topic")
    XCTAssertTrue(app.staticTexts["postTopicHint"].exists); XCTAssertFalse(app.buttons["publishPost"].isEnabled)
    let confessions = app.buttons["postTopic-confessions"]
    confessions.tap(); waitSelected(confessions)
    XCTAssertTrue(app.descendants(matching: .any)["postTopicGuardrail"].exists, "Confessions shows the reminder about other students")
    XCTAssertTrue(app.buttons["publishPost"].isEnabled)
    confessions.tap(); waitSelected(confessions, false)
    XCTAssertFalse(app.buttons["publishPost"].isEnabled, "Tapping the selected chip clears it")
    let discard = app.buttons["postDiscard"]; app.revealInComposer(discard); discard.tap(); app.alerts.buttons["Discard draft"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 3))
    // Browsing Sports starts the composer in Sports.
    let sportsTab = tab("sports", in: app)
    revealTab(sportsTab, in: app); sportsTab.tap(); waitSelected(sportsTab)
    app.buttons["Create post"].tap()
    XCTAssertTrue(editor.waitForExistence(timeout: 3))
    waitSelected(app.buttons["postTopic-sports"])
    editor.tap(); editor.typeText("Who has an extra ticket for Saturday?")
    XCTAssertTrue(app.buttons["publishPost"].isEnabled)
    app.buttons["publishPost"].tap()
    let created = app.buttons["Who has an extra ticket for Saturday?"]
    XCTAssertTrue(created.waitForExistence(timeout: 5), "The post publishes at the top of Sports")
    waitSelected(sportsTab)
    XCTAssertGreaterThanOrEqual(app.buttons.matching(identifier: "topicTag-sports").count, 2, "The new post carries the Sports pill")
    let pill = app.buttons.matching(identifier: "topicTag-sports").firstMatch
    XCTAssertEqual(pill.label, "Sports topic")
    XCTAssertLessThan(abs(pill.frame.midY - created.frame.minY), 60, "The pill sits in the new post's header row")
    let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Published in Sports with its pill"; image.lifetime = .keepAlways; add(image)
  }

  func testEmptyTopicOffersToPostInIt() {
    let app = launch()
    let relationships = tab("relationships", in: app)
    revealTab(relationships, in: app); relationships.tap(); waitSelected(relationships)
    XCTAssertTrue(app.staticTexts["No 💘 Relationships posts yet"].waitForExistence(timeout: 3))
    app.buttons["postInTopic"].tap()
    XCTAssertTrue(app.textViews["postText"].waitForExistence(timeout: 3))
    waitSelected(app.buttons["postTopic-relationships"])
    XCTAssertTrue(app.descendants(matching: .any)["postTopicGuardrail"].exists)
  }

  func testTappingAPillSelectsItsTabInTheFeedAndOpensItsFeedFromAThread() {
    let app = launch()
    let chem = app.buttons["CHEM 107 people: study room, whiteboard, and a very unreasonable amount of snacks?"]
    XCTAssertTrue(chem.waitForExistence(timeout: 5))
    let pill = app.buttons.matching(identifier: "topicTag-academics").firstMatch
    XCTAssertTrue(pill.exists)
    pill.tap()
    waitSelected(tab("academics", in: app))
    XCTAssertTrue(chem.waitForExistence(timeout: 3)); waitGone(app.buttons[walk])
    // In a thread the pill pushes that topic's feed.
    chem.tap()
    XCTAssertTrue(app.navigationBars["Post"].waitForExistence(timeout: 3))
    // The thread card's `threadOriginalPost` identifier covers its children, so address the pill by label.
    let threadPill = app.buttons.matching(NSPredicate(format: "identifier == 'threadOriginalPost' AND label == 'Academics topic'")).firstMatch
    XCTAssertTrue(threadPill.waitForExistence(timeout: 3)); threadPill.tap()
    XCTAssertTrue(app.navigationBars["Academics"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.descendants(matching: .any)["topicFeedHeader"].exists)
    XCTAssertTrue(app.buttons["Confirmed: this is how I passed CHEM"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons[walk].exists)
  }

  func testReportingAPostSendsTheChosenReason() {
    let app = launch()
    XCTAssertTrue(app.buttons["CHEM 107 people: study room, whiteboard, and a very unreasonable amount of snacks?"].waitForExistence(timeout: 5))
    let academics = tab("academics", in: app)
    revealTab(academics, in: app); academics.tap(); waitSelected(academics)
    let target = app.buttons["Confirmed: this is how I passed CHEM"]
    XCTAssertTrue(target.waitForExistence(timeout: 3))
    app.buttons["Post options"].firstMatch.tap()
    app.buttons["Report post"].tap()
    XCTAssertTrue(app.staticTexts["Why are you reporting this post?"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["Harassment or bullying"].exists)
    let wrongTopic = app.buttons["Wrong topic"].firstMatch
    XCTAssertTrue(wrongTopic.exists, "A post with a topic can be reported as in the wrong topic")
    wrongTopic.tap()
    // The fixture hides a reported post on this device (the store records the chosen reason).
    waitGone(target)
  }

  func testDraggingTheStripScrollsItWithoutChangingRootTabSortOrTopic() {
    let app = launch()
    let all = tab("all", in: app); XCTAssertTrue(all.waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["New"].isSelected)
    let more = tab("more", in: app)
    XCTAssertFalse(onScreen(more, in: app), "The strip is wider than the screen")
    let strip = app.descendants(matching: .any)["topicStrip"]
    for _ in 0..<3 {
      let start = strip.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
      start.press(forDuration: 0.05, thenDragTo: strip.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)))
    }
    XCTAssertTrue(onScreen(more, in: app), "The strip scrolled to its end")
    XCTAssertTrue(app.buttons["New"].isSelected, "A strip drag is not the New/Hot swipe")
    XCTAssertTrue(app.tabBars.buttons["Community"].isSelected, "A strip drag is not the root-tab swipe")
    waitSelected(all)
    XCTAssertTrue(app.buttons[walk].exists)
    for _ in 0..<3 { strip.swipeRight(velocity: .fast) }
    XCTAssertTrue(app.buttons["New"].isSelected); XCTAssertTrue(app.tabBars.buttons["Community"].isSelected)
    // Re-tapping the selected tab keeps it selected (it scrolls the feed to the top).
    revealTabBack(all, in: app); all.tap(); waitSelected(all)
  }

  func testServerWithoutTopicsShowsTodaysFeedAndComposer() {
    let app = launch([ "--uitesting-no-topics" ], name: "old_server")
    XCTAssertTrue(app.buttons[walk].waitForExistence(timeout: 5))
    XCTAssertFalse(app.descendants(matching: .any)["topicStrip"].exists)
    XCTAssertFalse(tab("all", in: app).exists)
    XCTAssertEqual(app.buttons.matching(identifier: "topicTag-academics").count, 0, "No pills")
    app.buttons["Create post"].tap()
    let editor = app.textViews["postText"]; XCTAssertTrue(editor.waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["postTopic-sports"].exists, "No topic row")
    editor.tap(); editor.typeText("Posting without a topic")
    XCTAssertTrue(app.buttons["publishPost"].isEnabled, "No topic is required")
    app.buttons["publishPost"].tap()
    XCTAssertTrue(app.buttons["Posting without a topic"].waitForExistence(timeout: 5))
  }

  /// Fully inside the window, clear of the strip's edge fades.
  private func fullyOnScreen(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
    guard element.exists else { return false }
    let frame = element.frame, screen = app.windows.firstMatch.frame
    return !frame.isEmpty && frame.minX >= screen.minX + 16 && frame.maxX <= screen.maxX - 16
  }
  private func waitFullyOnScreen(_ element: XCUIElement, in app: XCUIApplication, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
    let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.fullyOnScreen(element, in: app) }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 3), .completed, message, file: file, line: line)
  }

  func testAPickedTopicIsScrolledIntoViewInTheStripAndTheComposer() {
    let app = launch()
    let more = tab("more", in: app)
    revealTab(more, in: app); more.tap()
    // Memes is folded into More in the fixtures (the last topic, so its new tab lands at the far end).
    let slug = "memes", memesItem = app.buttons["topicSheetItem-memes"]
    XCTAssertTrue(memesItem.waitForExistence(timeout: 3)); memesItem.tap()
    waitGone(app.descendants(matching: .any)["topicSheet"])
    let picked = tab(slug, in: app)
    waitSelected(picked)
    waitFullyOnScreen(picked, in: app, "A topic chosen from More is scrolled into view, not left clipped at the edge")
    let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Topic from More in view"; image.lifetime = .keepAlways; add(image)
    // The composer opens in that topic with its chip in view, so the member sees what Send uses.
    app.buttons["Create post"].tap()
    XCTAssertTrue(app.textViews["postText"].waitForExistence(timeout: 3))
    let chip = app.buttons["postTopic-\(slug)"]
    waitSelected(chip)
    waitFullyOnScreen(chip, in: app, "The preselected chip is scrolled into view")
    let composer = XCTAttachment(screenshot: app.screenshot()); composer.name = "Preselected chip in view"; composer.lifetime = .keepAlways; add(composer)
  }

  /// Tab sizes (labels, emoji, gaps) stop growing at AX2, and every tab sits on the same baseline.
  func testTheStripStopsGrowingPastAccessibility2() {
    func metrics(_ category: String) -> (all: CGRect, academics: CGRect) {
      let app = launch(["-UIPreferredContentSizeCategoryName", category])
      let all = tab("all", in: app), academics = tab("academics", in: app)
      XCTAssertTrue(all.waitForExistence(timeout: 5)); XCTAssertTrue(academics.waitForExistence(timeout: 3))
      let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Strip at \(category)"; image.lifetime = .keepAlways; add(image)
      let result = (all.frame, academics.frame)
      app.terminate()
      return result
    }
    let ax2 = metrics("UICTContentSizeCategoryAccessibilityL")
    let ax5 = metrics("UICTContentSizeCategoryAccessibilityXXXL")
    XCTAssertEqual(ax5.all.height, ax2.all.height, accuracy: 1, "All stops growing at AX2")
    XCTAssertEqual(ax5.academics.width, ax2.academics.width, accuracy: 1, "An emoji tab (label and emoji) stops growing at AX2")
    XCTAssertEqual(ax5.academics.height, ax2.academics.height, accuracy: 1)
    XCTAssertEqual(ax5.academics.minX - ax5.all.maxX, ax2.academics.minX - ax2.all.maxX, accuracy: 1, "The gap stops growing at AX2")
    XCTAssertEqual(ax5.all.maxY, ax5.academics.maxY, accuracy: 1, "Every tab's bottom edge (its underline) is on the hairline")
  }
}
