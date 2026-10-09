import XCTest

/// Scroll end loads the next keyset page (`--uitesting-feed-pages`: 40 extra fixture posts, 30 per page).
@MainActor final class FeedPagingUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    if (testRun?.failureCount ?? 0) > 0 {
      let app = XCUIApplication(); print(app.debugDescription)
      let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Feed paging failure"; attachment.lifetime = .keepAlways; add(attachment)
    }
  }
  func testScrollingToTheEndLoadsTheNextFeedPage() {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--uitesting-feed-pages"]; app.launch()
    let username = app.textFields["username"]; XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText("paging_tester"); app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    let feed = app.scrollViews["communityFeed"]
    let sentinel = app.descendants(matching: .any)["feedLoadMore"]
    // Only the first page (30 posts) is in the feed: the 26th archived thread is on page two.
    for _ in 0..<30 where !sentinel.exists { feed.swipeUp(velocity: .fast) }
    XCTAssertTrue(sentinel.exists, "The loading row appears at the end of the first page")
    XCTAssertTrue(app.buttons["Archived campus thread 25"].exists || app.buttons["Archived campus thread 24"].exists)
    let secondPage = app.buttons["Archived campus thread 26"]
    XCTAssertTrue(secondPage.waitForExistence(timeout: 5), "The next page is appended below the first")
    let last = app.buttons["Archived campus thread 40"]
    for _ in 0..<15 where !last.exists { feed.swipeUp(velocity: .fast) }
    XCTAssertTrue(last.exists)
    XCTAssertFalse(sentinel.exists, "No loading row once the feed has ended")
    let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Feed end after the second page"; shot.lifetime = .keepAlways; add(shot)
  }
  /// A server without `posts.search`: search filters the loaded pages; "Search older posts"
  /// (`feedLoadOlder`) reaches the next page on request.
  func testSearchReachesOlderPagesOnRequest() {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--uitesting-feed-pages", "--uitesting-no-search-top"]; app.launch()
    let username = app.textFields["username"]; XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText("paging_search"); app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    app.buttons["Search posts"].tap()
    let field = app.textFields["postSearch"]; XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap(); field.typeText("thread 3")
    XCTAssertTrue(app.buttons["Archived campus thread 3"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Archived campus thread 30"].exists, "Thread 30 is on the second page")
    let older = app.descendants(matching: .any)["feedLoadOlder"]
    XCTAssertTrue(older.waitForExistence(timeout: 5), "A filtered feed offers its older pages")
    XCTAssertFalse(app.descendants(matching: .any)["feedLoadMore"].exists, "No automatic paging while filtering")
    older.tap()
    XCTAssertTrue(app.buttons["Archived campus thread 30"].waitForExistence(timeout: 8), "The older page's matches join the results")
    XCTAssertFalse(older.waitForExistence(timeout: 1), "The feed has ended")
  }
}
