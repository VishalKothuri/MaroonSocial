import XCTest

@MainActor final class PostRepliesUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  private func launchThread() -> XCUIApplication {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
    let name = app.textFields["username"]
    XCTAssertTrue(name.waitForExistence(timeout: 10)); name.tap(); name.typeText("thread_tester")
    app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Search posts"].waitForExistence(timeout: 5)); app.buttons["Search posts"].tap()
    let search = app.textFields["postSearch"]; search.tap(); search.typeText("uphill")
    let post = app.buttons["The walk to class is somehow uphill in both directions."]
    XCTAssertTrue(post.waitForExistence(timeout: 3)); post.tap()
    XCTAssertTrue(app.staticTexts["Especially when you're already late."].waitForExistence(timeout: 3))
    return app
  }
  func testNestedReplyAppearsUnderItsParentAndVotingSwitchesWithoutDuplicates() {
    let app = launchThread()
    let reply = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "replyTo-")).firstMatch
    let id = String(reply.identifier.dropFirst("replyTo-".count))
    let score = app.staticTexts["commentScore-\(id)"]
    XCTAssertEqual(score.label, "Reply score 0")
    app.buttons["upvoteComment-\(id)"].tap()
    XCTAssertEqual(score.label, "Reply score 1")
    app.buttons["downvoteComment-\(id)"].tap()
    XCTAssertEqual(score.label, "Reply score -1")
    app.buttons["downvoteComment-\(id)"].tap()
    XCTAssertEqual(score.label, "Reply score 0")
    reply.tap()
    XCTAssertTrue(app.staticTexts["replyTarget"].waitForExistence(timeout: 3))
    let input = app.textFields["replyText"]
    input.typeText("Nested reply stays with this comment")
    app.buttons["sendReply"].tap()
    let nested = app.staticTexts["Nested reply stays with this comment"]
    XCTAssertTrue(nested.waitForExistence(timeout: 5))
    let parent = app.staticTexts["commentText-\(id)"]
    XCTAssertGreaterThan(nested.frame.minX, parent.frame.minX, "Nested replies must be visibly indented")
    XCTAssertGreaterThan(nested.frame.minY, parent.frame.minY, "A child follows its own parent")
    XCTAssertFalse(app.staticTexts["replyTarget"].exists)
    let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Post and nested reply hierarchy"; shot.lifetime = .keepAlways; add(shot)
  }
  func testReplyMessageRequestIsLockedAnonymousAndProfileShowsKarma() {
    let app = launchThread()
    app.buttons["Message reply author anonymously"].firstMatch.tap()
    XCTAssertTrue(app.descendants(matching: .any)["fixedAnonymousIdentity"].firstMatch.waitForExistence(timeout: 3))
    XCTAssertFalse(app.textFields["requestUsername"].exists)
    // The request sheet offers no identity switch; the reply composer's own toggle sits behind it.
    let replyToggle = app.switches["replyAnonymous"]
    // The system switch inside the toggle row overhangs its labelled frame by a couple of points.
    let toggleRow = replyToggle.frame.insetBy(dx: -8, dy: -4)
    XCTAssertTrue(app.switches.allElementsBoundByIndex.allSatisfy { toggleRow.contains($0.frame) }, app.switches.debugDescription)
    let request = app.descendants(matching: .any)["requestText"].firstMatch
    request.tap(); request.typeText("A private anonymous reply request")
    XCTAssertTrue(app.buttons["sendMessageRequest"].isEnabled)
    app.buttons["Cancel"].tap(); app.buttons["Discard draft"].tap()
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.buttons["Profile and settings"].tap()
    // The Karma tile (a combined element) keeps the identifier and its spoken value.
    let karma = app.descendants(matching: .any)["profileKarma"]
    XCTAssertTrue(karma.waitForExistence(timeout: 3))
    XCTAssertEqual(karma.label, "0 karma")
    XCTAssertTrue(app.descendants(matching: .any)["profilePosts"].exists)
    XCTAssertTrue(app.staticTexts["@thread_tester"].exists)
  }
}
