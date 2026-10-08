import XCTest

@MainActor final class TabNavigationUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    if (testRun?.failureCount ?? 0) > 0 {
      let app = XCUIApplication(); print(app.debugDescription)
      let image = XCTAttachment(screenshot: app.screenshot()); image.lifetime = .keepAlways; add(image)
    }
  }
  private func launch() -> XCUIApplication {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
    let name = app.textFields["username"]; XCTAssertTrue(name.waitForExistence(timeout: 10))
    name.tap(); name.typeText("swipeaggie")
    app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    return app
  }
  private func assertTab(_ name: String, in app: XCUIApplication) {
    let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND selected == true"), object: app.tabBars.buttons[name])
    XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 4), .completed, "Expected selected tab \(name)")
    XCTAssertFalse(app.navigationBars.staticTexts[name].exists, "The selected tab already identifies this root screen")
    XCTAssertFalse(app.descendants(matching: .any)["startupWordmark"].exists, "Changing tabs must not replay startup loading")
    XCTAssertFalse(app.staticTexts["startupStatus"].exists)
  }
  private func swipe(_ app: XCUIApplication, left: Bool, y: CGFloat = 0.57) {
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.78 : 0.22, dy: y))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.22 : 0.78, dy: y))
    start.press(forDuration: 0.05, thenDragTo: end)
  }
  func testCommunitySortSwipesStayBoundedAndOtherRootsStillSlide() {
    let app = launch()
    assertTab("Community", in: app)
    XCTAssertTrue(app.buttons["New"].isSelected)
    swipe(app, left: false)
    assertTab("Community", in: app); XCTAssertTrue(app.buttons["New"].isSelected)
    swipe(app, left: true)
    assertTab("Community", in: app); XCTAssertTrue(app.buttons["Hot"].isSelected)
    swipe(app, left: true)
    assertTab("Community", in: app); XCTAssertTrue(app.buttons["Hot"].isSelected)
    swipe(app, left: false)
    assertTab("Community", in: app); XCTAssertTrue(app.buttons["New"].isSelected)
    // Feed order can also change through its existing selector.
    app.buttons["Hot"].tap(); XCTAssertTrue(app.buttons["Hot"].isSelected)
    app.buttons["New"].tap(); XCTAssertTrue(app.buttons["New"].isSelected)
    // Root tab taps stay available, and the remaining roots keep their slides.
    app.tabBars.buttons["Classes"].tap(); assertTab("Classes", in: app)
    for tab in ["Explore", "Campus", "Inbox"] {
      swipe(app, left: true); assertTab(tab, in: app)
    }
    swipe(app, left: true); assertTab("Inbox", in: app)
    for tab in ["Campus", "Explore", "Classes", "Community"] {
      swipe(app, left: false); assertTab(tab, in: app)
    }
    XCTAssertTrue(app.buttons["New"].isSelected)
    XCTAssertEqual(app.tabBars.buttons.count, 5)
    app.tabBars.buttons["Explore"].tap(); assertTab("Explore", in: app)
    let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Native selected tab after bounded feed and root navigation"; image.lifetime = .keepAlways; add(image)
  }
  func testRootTabsKeepTheirControlsWithoutDuplicateNavigationHeadings() {
    let app = launch()
    assertTab("Community", in: app)
    XCTAssertTrue(app.buttons["communityPicker"].isHittable)
    XCTAssertTrue(app.buttons["Profile and settings"].isHittable)
    app.tabBars.buttons["Classes"].tap(); assertTab("Classes", in: app)
    XCTAssertTrue(app.textFields["courseSearch"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["Add by code"].isHittable)
    app.tabBars.buttons["Explore"].tap(); assertTab("Explore", in: app)
    XCTAssertTrue(app.buttons["exploreCommunities"].isHittable)
    app.tabBars.buttons["Campus"].tap(); assertTab("Campus", in: app)
    XCTAssertTrue(app.buttons["campusUpcoming"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["savedEventsFilter"].isHittable)
    app.tabBars.buttons["Inbox"].tap(); assertTab("Inbox", in: app)
    XCTAssertTrue(app.buttons["inboxMessages"].isHittable)
    XCTAssertTrue(app.buttons["New conversation"].isHittable)
    app.buttons["New conversation"].tap(); app.buttons["New message"].tap()
    XCTAssertTrue(app.navigationBars["New message"].waitForExistence(timeout: 3), "Presented destinations retain their own title and controls")
    XCTAssertTrue(app.textFields["requestUsername"].isHittable)
  }
  func testVerticalFeedScrollingAndFocusedSearchNeverSwitchTabs() {
    let app = launch()
    app.buttons["savedPostsFilter"].tap()
    XCTAssertTrue(app.staticTexts["No saved posts"].waitForExistence(timeout: 3))
    // An empty filtered feed only rubber-bands. It must not interpret overscroll
    // as travel through posts and hide either navigation bar.
    let feed = app.scrollViews["communityFeed"]
    feed.swipeUp(velocity: .slow); assertTab("Community", in: app)
    XCTAssertTrue(app.buttons["communityPicker"].isHittable)
    XCTAssertTrue(app.tabBars.buttons["Classes"].isHittable)
    feed.swipeDown(velocity: .slow); assertTab("Community", in: app)
    XCTAssertTrue(app.buttons["communityPicker"].isHittable)
    XCTAssertTrue(app.buttons["Create post"].isHittable)
    app.buttons["savedPostsFilter"].tap()
    // The full feed is long enough to collapse the bars on the way up; bringing
    // them back must land on the same tab, never on a neighbour.
    app.swipeUp(); app.swipeDown(); assertTab("Community", in: app)
    app.swipeDown(); assertTab("Community", in: app)
    app.buttons["Search posts"].tap()
    let search = app.textFields["postSearch"]; XCTAssertTrue(search.waitForExistence(timeout: 3))
    search.tap(); search.typeText("ZZZUNMATCHED")
    swipe(app, left: true, y: 0.42)
    assertTab("Community", in: app)
    XCTAssertEqual(search.value as? String, "ZZZUNMATCHED")
    XCTAssertTrue(app.keyboards.firstMatch.exists)
    XCTAssertTrue(app.buttons["New"].isSelected, "Focused search must not switch feed order")
  }
  func testHorizontalDateStripAndPushedScreenKeepTheirOwnNavigation() {
    let app = launch()
    app.tabBars.buttons["Campus"].tap(); assertTab("Campus", in: app)
    let day = app.buttons["campusDay-1"]; XCTAssertTrue(day.waitForExistence(timeout: 5))
    let y = day.frame.midY / app.frame.height
    swipe(app, left: true, y: y); assertTab("Campus", in: app)
    let bus = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bus routes")).firstMatch
    XCTAssertTrue(bus.isHittable); bus.tap()
    XCTAssertTrue(app.navigationBars["AggieSpirit"].waitForExistence(timeout: 5))
    swipe(app, left: true)
    XCTAssertTrue(app.navigationBars["AggieSpirit"].exists)
    app.navigationBars.buttons.element(boundBy: 0).tap(); assertTab("Campus", in: app)
    app.tabBars.buttons["Community"].tap()
    app.buttons["Create post"].tap()
    XCTAssertTrue(app.textViews["postText"].waitForExistence(timeout: 3))
    swipe(app, left: true, y: 0.35)
    XCTAssertTrue(app.textViews["postText"].exists)
    XCTAssertTrue(app.buttons["New"].isSelected, "Composition keeps its own gestures and feed order")
    app.buttons["closePostComposer"].tap(); assertTab("Community", in: app)
  }
}
