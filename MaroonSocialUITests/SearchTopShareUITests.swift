import XCTest

/// Server search in the Community search field, the Top sort with its window menu, the Share action
/// and post links, in fixture mode (which answers `posts.search` and `feed.top` like a current
/// server), plus an old server (`--uitesting-no-search-top`).
@MainActor final class SearchTopShareUITests: XCTestCase {
  private static let linkedPostID = "6b1d3f0e-8c2a-4e57-9a41-2f6c7d8e9a10"
  private static let adultPostID = "c4e2a9b7-1f3d-4c68-8e5a-7b9d0f1a2c3e"
  private static let chem = "CHEM 107 people: study room, whiteboard, and a very unreasonable amount of snacks?"
  private static let walk = "The walk to class is somehow uphill in both directions."
  private static let coffee = "Unofficial campus rule: getting coffee counts as being productive."
  private static let yell = "Midnight Yell this Friday: who's saving seats?"
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    if (testRun?.failureCount ?? 0) > 0 {
      let app = XCUIApplication(); print(app.debugDescription)
      let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Search, Top or share failure"; image.lifetime = .keepAlways; add(image)
    }
  }
  private func launch(_ extra: [String] = [], name: String = "reach_tester", signIn: Bool = true) -> XCUIApplication {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"] + extra; app.launch()
    if signIn { self.signIn(app, name: name) }
    return app
  }
  private func signIn(_ app: XCUIApplication, name: String) {
    let username = app.textFields["username"]; XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText(name); app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
  }
  private func any(_ app: XCUIApplication, _ identifier: String) -> XCUIElement { app.descendants(matching: .any)[identifier] }
  private func shot(_ app: XCUIApplication, _ name: String) {
    let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
  }

  // MARK: Search

  func testSearchAsksTheServerWithinTheTopicAndShowsNoMatches() {
    let app = launch()
    app.buttons["Search posts"].tap()
    let field = app.textFields["postSearch"]; XCTAssertTrue(field.waitForExistence(timeout: 3))
    field.tap(); field.typeText("evans")
    let question = app.buttons["Is Evans open all night during finals week?"]
    XCTAssertTrue(question.waitForExistence(timeout: 5), "The server's match shows (a day-old post)")
    XCTAssertFalse(app.buttons[Self.coffee].exists, "Only matches are listed")
    shot(app, "Search results")
    // Within a topic, the same words match nothing there (the question is in Questions).
    app.buttons["topicTab-academics"].tap()
    XCTAssertTrue(any(app, "searchNoMatches").waitForExistence(timeout: 5), "No posts match in Academics")
    XCTAssertTrue(any(app, "searchNoMatches").label.contains("No posts match"))
    app.buttons["topicTab-all"].tap()
    XCTAssertTrue(question.waitForExistence(timeout: 5))
    // New input replaces the results.
    field.tap(); field.typeText("zzz")
    XCTAssertTrue(any(app, "searchNoMatches").waitForExistence(timeout: 5))
    XCTAssertFalse(question.exists)
    app.buttons["Clear search"].tap()
    XCTAssertTrue(app.buttons[Self.coffee].waitForExistence(timeout: 5), "An empty field shows the feed again")
  }

  func testOldServerFiltersLoadedPostsAndKeepsNewAndHot() {
    let app = launch(["--uitesting-no-search-top"], name: "old_reach")
    XCTAssertTrue(app.buttons["feedSort-new"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["feedSort-hot"].exists)
    XCTAssertFalse(app.buttons["feedSort-top"].exists, "No Top without feed.top")
    app.buttons["Search posts"].tap()
    let field = app.textFields["postSearch"]; XCTAssertTrue(field.waitForExistence(timeout: 3))
    field.tap(); field.typeText("ZZZUNMATCHED")
    XCTAssertTrue(app.staticTexts["No matching posts"].waitForExistence(timeout: 3), "Today's local filter")
    XCTAssertFalse(any(app, "searchNoMatches").exists)
    XCTAssertFalse(any(app, "searchLoading").exists)
  }

  // MARK: Top

  func testTopRanksByScoreAndItsWindowMenuNarrowsTheList() {
    let app = launch()
    let top = app.buttons["feedSort-top"]; XCTAssertTrue(top.waitForExistence(timeout: 5))
    top.tap()
    XCTAssertTrue(top.isSelected)
    let menu = app.buttons["topWindowMenu"]; XCTAssertTrue(menu.waitForExistence(timeout: 5))
    XCTAssertEqual(menu.value as? String, "This week", "This week by default")
    let walk = app.buttons[Self.walk], coffee = app.buttons[Self.coffee]
    XCTAssertTrue(walk.waitForExistence(timeout: 5)); XCTAssertTrue(coffee.exists)
    XCTAssertLessThan(walk.frame.minY, coffee.frame.minY, "Score 124 ranks above 86")
    // Share fits on the action row's one line, also beside a three-digit score.
    let firstShare = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'sharePost-'")).firstMatch
    let firstUpvote = app.buttons.matching(NSPredicate(format: "label == 'Upvote'")).firstMatch
    XCTAssertEqual(firstShare.frame.midY, firstUpvote.frame.midY, accuracy: 4, "One line: share and the vote stepper")
    XCTAssertTrue(app.buttons[Self.yell].exists || {
      app.scrollViews["communityFeed"].swipeUp(); return app.buttons[Self.yell].waitForExistence(timeout: 3)
    }(), "A day-old post is in This week")
    shot(app, "Top this week")
    app.scrollViews["communityFeed"].swipeDown(); app.scrollViews["communityFeed"].swipeDown()
    menu.tap()
    let today = app.buttons["topWindow-day"]; XCTAssertTrue(today.waitForExistence(timeout: 3)); today.tap()
    XCTAssertEqual(menu.value as? String, "Today")
    XCTAssertTrue(walk.waitForExistence(timeout: 5))
    let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons[Self.yell])
    XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed, "A day-old post is outside Today")
    menu.tap()
    let allTime = app.buttons["topWindow-all"]; XCTAssertTrue(allTime.waitForExistence(timeout: 3)); allTime.tap()
    XCTAssertEqual(menu.value as? String, "All time")
    // Back to New: the menu goes away and the feed is newest first.
    app.buttons["feedSort-new"].tap()
    XCTAssertFalse(menu.waitForExistence(timeout: 1))
  }

  // MARK: Share

  func testShareOpensTheShareSheetWithTheLinkOnly() {
    let app = launch()
    let share = app.buttons["sharePost-demo-coffee-post"]
    XCTAssertTrue(share.waitForExistence(timeout: 5))
    XCTAssertEqual(share.label, "Share")
    share.tap()
    // The system share sheet: its header previews the line, never the post's words.
    // (It runs in another process; the app sees its container, `ActivityListView`.)
    XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 8), "The share sheet opens")
    shot(app, "Share sheet")
    // Dismiss by tapping above the sheet.
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
  }

  // MARK: Post links

  func testALinkOpenedSignedOutWaitsAndOpensTheThreadAfterSignIn() {
    let app = launch([ "--uitesting-deep-link", "https://maroonsocial.chat/p/\(Self.linkedPostID)" ], signIn: false)
    signIn(app, name: "link_tester")
    let thread = any(app, "threadOriginalPost")
    XCTAssertTrue(thread.waitForExistence(timeout: 8), "The queued link opens the thread once signed in")
    XCTAssertTrue(app.staticTexts[Self.chem].exists || app.buttons[Self.chem].exists || app.textViews[Self.chem].exists || thread.label.contains("CHEM 107"))
    shot(app, "Thread opened from a link")
    app.buttons["Done"].tap()
    XCTAssertFalse(thread.waitForExistence(timeout: 1))
  }

  func testALinkToAPostTheMemberCantSeeSaysSo() {
    let app = launch([ "--uitesting-deep-link", "maroonsocial://post/\(Self.adultPostID)" ])
    let unavailable = any(app, "postUnavailable")
    XCTAssertTrue(unavailable.waitForExistence(timeout: 8), "An NSFW post outside the member's communities")
    XCTAssertTrue(unavailable.label.contains("This post isn’t available"))
    shot(app, "Unavailable post from a link")
    app.buttons["Done"].tap()
  }

  func testTheCustomSchemeOpensAThreadWhileRunning() {
    let app = launch()
    app.open(URL(string: "maroonsocial://post/\(Self.linkedPostID.uppercased())")!)
    // Opening a URL may relaunch the fixture app (a fresh, signed-out preview): the link then waits
    // for sign-in.
    if app.textFields["username"].waitForExistence(timeout: 3) { signIn(app, name: "scheme_tester") }
    XCTAssertTrue(any(app, "threadOriginalPost").waitForExistence(timeout: 8))
    app.buttons["Done"].tap()
    // A post that does not exist (deleted) is a clear state too.
    app.open(URL(string: "maroonsocial://post/\(UUID().uuidString)")!)
    if app.textFields["username"].waitForExistence(timeout: 3) { signIn(app, name: "scheme_tester") }
    XCTAssertTrue(any(app, "postUnavailable").waitForExistence(timeout: 8))
  }
}
