import XCTest

/// Community guidelines before a first post, the topic sheet, reply aliases, "+N" on New, the poll
/// restyle, verified organization posts, the game-day chat link and grouped notifications.
@MainActor final class CampusFeelUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    if (testRun?.failureCount ?? 0) > 0 {
      let app = XCUIApplication(); print(app.debugDescription)
      let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Campus feel failure"; image.lifetime = .keepAlways; add(image)
    }
  }
  private func launch(_ extra: [String] = [], name: String = "feel_tester") -> XCUIApplication {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"] + extra; app.launch()
    let username = app.textFields["username"]; XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText(name); app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    return app
  }
  private func shot(_ app: XCUIApplication, _ name: String) {
    let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
  }
  private func waitGone(_ element: XCUIElement, timeout: TimeInterval = 4, file: StaticString = #filePath, line: UInt = #line) {
    let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: timeout), .completed, "\(element) should be gone", file: file, line: line)
  }
  private func waitSelected(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND selected == true"), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 4), .completed, "\(element) selected", file: file, line: line)
  }
  private func onScreen(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
    guard element.exists else { return false }
    let frame = element.frame, screen = app.windows.firstMatch.frame
    return !frame.isEmpty && frame.midX > screen.minX + 8 && frame.midX < screen.maxX - 8
  }
  /// Selects a strip tab, swiping the strip until it is on screen.
  private func selectTopic(_ slug: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    let tab = app.buttons["topicTab-\(slug)"]
    XCTAssertTrue(tab.waitForExistence(timeout: 5), file: file, line: line)
    for _ in 0..<5 where !onScreen(tab, in: app) { app.descendants(matching: .any)["topicStrip"].swipeLeft(velocity: .slow) }
    tab.tap(); waitSelected(tab, file: file, line: line)
  }

  // MARK: Community guidelines

  func testFirstPostOpensTheGuidelinesAndAgreeingPublishesIt() {
    let app = launch([ "--guidelines-unaccepted" ], name: "rules_tester")
    app.buttons["Create post"].tap()
    let editor = app.textViews["postText"]; XCTAssertTrue(editor.waitForExistence(timeout: 3))
    editor.tap(); editor.typeText("My first post here")
    app.pickPostTopic()
    app.buttons["publishPost"].tap()
    // Not now keeps the draft and sends nothing.
    let decline = app.buttons["declineGuidelines"]
    XCTAssertTrue(decline.waitForExistence(timeout: 4), "The first post opens the guidelines sheet")
    XCTAssertTrue(app.descendants(matching: .any)["guidelinesSheet"].exists)
    XCTAssertTrue(app.links["guidelinesFullText"].exists || app.buttons["guidelinesFullText"].exists, "The sheet links the full text")
    XCTAssertTrue(app.staticTexts["In crisis? Call or text 988"].exists)
    shot(app, "Guidelines sheet")
    decline.tap()
    waitGone(decline)
    XCTAssertFalse(app.buttons["My first post here"].exists, "Nothing was posted")
    XCTAssertEqual(editor.value as? String, "My first post here", "The draft is kept")
    // Send again: the sheet again; I agree publishes the draft.
    app.buttons["publishPost"].tap()
    let agree = app.buttons["acceptGuidelines"]
    XCTAssertTrue(agree.waitForExistence(timeout: 4))
    agree.tap()
    XCTAssertTrue(app.buttons["My first post here"].waitForExistence(timeout: 6), "Agreeing sends the post")
    // Accepted once: the next post goes straight out.
    app.buttons["Create post"].tap()
    XCTAssertTrue(editor.waitForExistence(timeout: 3))
    editor.tap(); editor.typeText("And a second one")
    app.pickPostTopic()
    app.buttons["publishPost"].tap()
    XCTAssertTrue(app.buttons["And a second one"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["acceptGuidelines"].exists)
    // Settings shows the accepted version.
    app.buttons["Profile and settings"].tap()
    let row = app.buttons["settingsGuidelines"]
    XCTAssertTrue(row.waitForExistence(timeout: 3)); row.tap()
    let status = app.descendants(matching: .any)["guidelinesStatus"]
    XCTAssertTrue(status.waitForExistence(timeout: 3))
    XCTAssertTrue(status.label.contains("Accepted version 1 on"), status.label)
    shot(app, "Guidelines in Settings")
  }

  func testAcceptedFixtureNeverShowsTheSheet() {
    let app = launch()
    app.buttons["Create post"].tap()
    let editor = app.textViews["postText"]; XCTAssertTrue(editor.waitForExistence(timeout: 3))
    editor.tap(); editor.typeText("Straight to the feed")
    app.pickPostTopic()
    app.buttons["publishPost"].tap()
    XCTAssertTrue(app.buttons["Straight to the feed"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["acceptGuidelines"].exists)
  }

  // MARK: Topic sheet

  func testTopicSheetSelectsATopicAndTheSort() {
    let app = launch()
    let more = app.buttons["topicTab-more"]
    XCTAssertTrue(more.waitForExistence(timeout: 5))
    for _ in 0..<5 where !onScreen(more, in: app) { app.descendants(matching: .any)["topicStrip"].swipeLeft(velocity: .slow) }
    more.tap()
    let sheet = app.descendants(matching: .any)["topicSheet"]
    XCTAssertTrue(sheet.waitForExistence(timeout: 3))
    for slug in ["all", "academics", "aggie_life", "questions", "housing", "sports", "relationships", "confessions", "memes"] {
      XCTAssertTrue(app.buttons["topicSheetItem-\(slug)"].exists, slug)
    }
    XCTAssertEqual(app.buttons["topicSheetItem-academics"].label, "Academics, 12 posts this week", "Each topic shows its 7-day count")
    XCTAssertTrue(app.buttons["topicSheetSort-New"].isSelected)
    shot(app, "Topic sheet")
    app.buttons["topicSheetItem-confessions"].tap()
    waitGone(sheet)
    waitSelected(app.buttons["topicTab-confessions"])
    XCTAssertTrue(app.buttons["Third year and I still can't find my way around the Zach building."].waitForExistence(timeout: 3))
    // The sheet's sort list sets New/Hot.
    for _ in 0..<5 where !onScreen(more, in: app) { app.descendants(matching: .any)["topicStrip"].swipeLeft(velocity: .slow) }
    more.tap()
    XCTAssertTrue(sheet.waitForExistence(timeout: 3))
    app.buttons["topicSheetSort-Hot"].tap()
    waitGone(sheet)
    waitSelected(app.buttons["Hot"])
    waitSelected(app.buttons["topicTab-confessions"])
  }

  // MARK: Reply aliases

  func testAnonymousRepliesShowStableAliasesPerPost() {
    let app = launch()
    selectTopic("questions", in: app)
    let question = app.buttons["Is Evans open all night during finals week?"]
    XCTAssertTrue(question.waitForExistence(timeout: 3)); question.tap()
    XCTAssertTrue(app.navigationBars["Post"].waitForExistence(timeout: 3))
    let aliases = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'replyAuthor-' AND label BEGINSWITH 'Aggie '"))
    let firstReply = app.staticTexts["Yes, the first two floors stay open all night during finals."]
    XCTAssertTrue(firstReply.waitForExistence(timeout: 3))
    XCTAssertEqual(aliases.count, 3, "Three non-OP anonymous replies carry aliases")
    let names = aliases.allElementsBoundByIndex.map(\.label)
    XCTAssertEqual(names[0], names[1], "The same replier keeps one alias in a post")
    XCTAssertNotEqual(names[0], names[2])
    XCTAssertTrue(app.staticTexts["OP"].exists, "The post author's reply keeps its capsule")
    XCTAssertFalse(app.staticTexts["demo-owl"].exists || app.staticTexts["@demo-owl"].exists, "No username on an anonymous reply")
    // The reply bar names the alias too.
    let replyButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'replyTo-'"))
    replyButtons.element(boundBy: 0).tap()
    XCTAssertEqual(app.staticTexts["replyTarget"].label, "Replying to \(names[0])")
    shot(app, "Reply aliases")
    app.buttons["Reply to post instead"].tap()
    // Another post: the same replier has another alias.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    // Memes is folded into More: pick it from the topic sheet.
    let more = app.buttons["topicTab-more"]
    for _ in 0..<5 where !onScreen(more, in: app) { app.descendants(matching: .any)["topicStrip"].swipeLeft(velocity: .slow) }
    more.tap()
    let memes = app.buttons["topicSheetItem-memes"]
    XCTAssertTrue(memes.waitForExistence(timeout: 3)); memes.tap()
    waitSelected(app.buttons["topicTab-memes"])
    let meme = app.buttons["Me sprinting for the bus that was never going to wait"]
    XCTAssertTrue(meme.waitForExistence(timeout: 3)); meme.tap()
    XCTAssertTrue(app.staticTexts["Every single morning."].waitForExistence(timeout: 3))
    let other = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'replyAuthor-' AND label BEGINSWITH 'Aggie '")).firstMatch
    XCTAssertTrue(other.exists)
    XCTAssertNotEqual(other.label, names[0], "A different post gives a different alias")
  }

  // MARK: "+N" on New

  func testNewPostsWaitBehindTheBadgeUntilNewIsTapped() {
    let app = launch([ "--uitesting-feed-delta" ])
    let new = app.buttons["New"]
    XCTAssertTrue(new.waitForExistence(timeout: 3))
    XCTAssertEqual(new.value as? String ?? "", "", "No badge at the top")
    let feed = app.scrollViews["communityFeed"]
    feed.swipeUp(velocity: .slow)
    let badged = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "2 new posts"), object: new)
    XCTAssertEqual(XCTWaiter.wait(for: [badged], timeout: 10), .completed, "The simulated delta shows +2 on New")
    let arrival = app.buttons["Free pizza outside the MSC right now"]
    XCTAssertFalse(arrival.exists, "New posts wait above the list")
    shot(app, "New posts badge")
    new.tap()
    XCTAssertTrue(arrival.waitForExistence(timeout: 4), "New shows them at the top")
    XCTAssertTrue(app.buttons["Is the Bonfire Memorial lit up tonight?"].exists)
    let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == ''"), object: new)
    XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 4), .completed, "The badge clears")
  }

  /// Posts held for All show when All opens again at its top after another topic.
  func testHeldPostsShowWhenTheListReturnsAtItsTop() {
    let app = launch([ "--uitesting-feed-delta" ])
    let new = app.buttons["New"]
    XCTAssertTrue(new.waitForExistence(timeout: 3))
    app.scrollViews["communityFeed"].swipeUp(velocity: .slow)
    let badged = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "2 new posts"), object: new)
    XCTAssertEqual(XCTWaiter.wait(for: [badged], timeout: 10), .completed, "The simulated delta shows +2 on New")
    // Scrolling back a little (not to the top) brings the collapsed header and its topic strip back.
    let academics = app.buttons["topicTab-academics"]
    let feed = app.scrollViews["communityFeed"]
    for _ in 0..<3 where !academics.exists {
      let start = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 90)), withVelocity: .slow, thenHoldForDuration: 0.3)
    }
    XCTAssertEqual(new.value as? String, "2 new posts", "Still below the top, the posts still wait")
    selectTopic("academics", in: app)
    selectTopic("all", in: app)
    XCTAssertTrue(app.buttons["Free pizza outside the MSC right now"].waitForExistence(timeout: 4), "All opens at its top with the held posts")
    XCTAssertTrue(app.buttons["Is the Bonfire Memorial lit up tonight?"].exists)
    let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == ''"), object: new)
    XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 4), .completed, "No badge once All is back at its top")
    shot(app, "Held posts after switching back")
  }

  // MARK: Poll restyle

  func testPollResultsKeepTheirIdentifiersAndShowTotalsUnderTheBars() {
    let app = launch(name: "poll_style")
    app.buttons["Create post"].tap()
    app.buttons["postAddPoll"].tap()
    // The post text is the poll's question.
    let editor = app.textViews["postText"]; app.revealInComposer(editor); editor.tap(); editor.typeText("Best study spot?")
    for (id, text) in [("pollOption0", "Evans"), ("pollOption1", "MSC")] {
      let field = app.textFields[id]; app.revealInComposer(field); field.tap(); field.typeText(text)
    }
    app.pickPostTopic()
    app.buttons["publishPost"].tap()
    XCTAssertTrue(app.staticTexts["Best study spot?"].waitForExistence(timeout: 5))
    let evans = app.buttons["Evans"], msc = app.buttons["MSC"]
    XCTAssertTrue(evans.identifier.hasPrefix("pollVote-"), "Options keep their identifiers")
    XCTAssertTrue(app.descendants(matching: .any)["postPoll"].exists)
    XCTAssertTrue(app.staticTexts["pollQuestionDisplay"].exists)
    evans.tap()
    XCTAssertTrue(app.staticTexts["1 vote"].waitForExistence(timeout: 3), "Total votes under the bars")
    XCTAssertTrue(evans.isSelected); XCTAssertFalse(msc.isSelected)
    XCTAssertEqual(evans.value as? String, "1 votes, 100 percent")
    XCTAssertEqual(msc.value as? String, "0 votes, 0 percent", "Every option shows its share")
    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label ENDSWITH ' left'")).firstMatch.exists, "Time left under the bars")
    shot(app, "Poll results")
  }

  // MARK: Verified organization posts

  func testOrganizationPostsShowTheVerifiedSealInTheFeedAndThread() {
    let app = launch()
    selectTopic("aggie_life", in: app)
    let post = app.buttons["Ring Day photo booth opens at 10 by the Clayton Williams Alumni Center."]
    XCTAssertTrue(post.waitForExistence(timeout: 3))
    let seal = app.images["verifiedSeal"]
    XCTAssertTrue(seal.waitForExistence(timeout: 3)); XCTAssertEqual(seal.label, "Verified organization")
    XCTAssertTrue(app.staticTexts["Ring Day Committee"].exists, "The card names the organization")
    XCTAssertEqual(app.images.matching(identifier: "verifiedSeal").count, 1, "Member posts carry no seal")
    shot(app, "Verified organization post")
    post.tap()
    XCTAssertTrue(app.navigationBars["Post"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.images.matching(NSPredicate(format: "label == 'Verified organization'")).firstMatch.waitForExistence(timeout: 3), "The thread header shows the seal")
  }

  // MARK: Sports pill → game-day chat

  func testSportsPostLinksToTheLiveGameDayChat() {
    let app = launch([ "--uitesting-game-day" ])
    selectTopic("sports", in: app)
    XCTAssertTrue(app.buttons["Midnight Yell this Friday: who's saving seats?"].waitForExistence(timeout: 3))
    let link = app.buttons["postGameDayChat"]
    XCTAssertTrue(link.waitForExistence(timeout: 3), "A Sports post shows the game-day link while a game is live")
    XCTAssertEqual(link.label, "Game-day chat")
    shot(app, "Game-day chat link")
    link.tap()
    XCTAssertTrue(app.navigationBars["Aggie Football vs. Fixture State"].waitForExistence(timeout: 5), "The link opens that game's chat")
  }

  func testNoGameDayLinkWithoutALiveGame() {
    let app = launch()
    selectTopic("sports", in: app)
    XCTAssertTrue(app.buttons["Midnight Yell this Friday: who's saving seats?"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["postGameDayChat"].exists)
  }

  // MARK: Notification rows

  func testNotificationsGroupSameKindOnTheSamePost() {
    let app = launch([ "--uitesting-notifications" ])
    app.buttons["notificationsBell"].tap()
    let panel = app.descendants(matching: .any)["notificationsPanel"]
    XCTAssertTrue(panel.waitForExistence(timeout: 3))
    let grouped = app.buttons["notification_fixture-note-1"]
    XCTAssertTrue(grouped.waitForExistence(timeout: 3))
    XCTAssertTrue(grouped.label.contains("3 new comments on your post"), grouped.label)
    XCTAssertTrue(grouped.label.contains("Unofficial campus rule"), "A line of your post")
    XCTAssertFalse(app.buttons["notification_fixture-note-2"].exists, "Grouped into the newest row")
    XCTAssertTrue(app.buttons["notification_fixture-note-4"].exists); XCTAssertTrue(app.buttons["notification_fixture-note-5"].exists)
    XCTAssertEqual(grouped.value as? String, "Unread")
    shot(app, "Grouped notifications")
  }
}
