import XCTest

@MainActor final class SourcePostTagUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  func testPostOriginTagPersistsFromInboxToChatAndOpensThePost() {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10)); username.tap(); username.typeText("tag_tester")
    app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    let inbox = app.tabBars.buttons["Inbox"]
    XCTAssertTrue(inbox.waitForExistence(timeout: 5)); inbox.tap()
    let requests = app.buttons["inboxRequests"]
    XCTAssertTrue(requests.waitForExistence(timeout: 5)); requests.tap()
    // The row combines its children into one element; the tag text lands in the row label.
    let taggedRow = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@ OR label CONTAINS %@", "sourcePostTag", "From this post")).firstMatch
    XCTAssertTrue(taggedRow.waitForExistence(timeout: 3), "Request rows show where the request came from")
    app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Any good coffee spots near campus?")).firstMatch.tap()
    XCTAssertTrue(app.buttons["declineRequest"].waitForExistence(timeout: 3))
    let pinned = app.buttons["sourcePostTag"]
    XCTAssertTrue(pinned.waitForExistence(timeout: 3))
    XCTAssertTrue(pinned.label.contains("Unofficial campus rule"), pinned.label)
    XCTAssertTrue(app.buttons["sourcePostTagRequest"].exists, "The acceptance panel repeats the origin next to Accept and Decline")
    pinned.tap()
    XCTAssertTrue(app.descendants(matching: .any)["threadOriginalPost"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Unofficial campus rule")).firstMatch.exists)
    let opened = XCTAttachment(screenshot: app.screenshot()); opened.name = "Post opened from the conversation tag"; opened.lifetime = .keepAlways; add(opened)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.buttons["declineRequest"].waitForExistence(timeout: 3), "Returning lands on the same request, still neither accepted nor declined")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(requests.waitForExistence(timeout: 3))
    XCTAssertEqual(requests.value as? String, "1 pending requests")
    app.buttons["inboxMessages"].tap()
    let deletedRow = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@ OR label CONTAINS %@", "sourcePostTagDeleted", "From a post that was deleted")).firstMatch
    XCTAssertTrue(deletedRow.waitForExistence(timeout: 3), "A conversation whose post is gone keeps a placeholder tag")
    app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Thanks for the study room tip!")).firstMatch.tap()
    let placeholder = app.descendants(matching: .any)["sourcePostTagDeleted"].firstMatch
    XCTAssertTrue(placeholder.waitForExistence(timeout: 3))
    XCTAssertTrue(placeholder.label.contains("From a post that was deleted"), placeholder.label)
    XCTAssertFalse(app.buttons["sourcePostTagDeleted"].exists, "A deleted origin is not tappable")
    XCTAssertTrue(app.textFields["messageText"].waitForExistence(timeout: 3), "The conversation itself stays open")
    let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Deleted post origin placeholder"; shot.lifetime = .keepAlways; add(shot)
  }
}
