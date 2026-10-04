import XCTest

@MainActor final class InboxUnreadUITests: XCTestCase {
  func testIncomingRequestBadgesAreSeparateFromMessagesAndGroups() {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText("badge_tester")
    app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    let inbox = app.tabBars.buttons["Inbox"]
    XCTAssertTrue(inbox.waitForExistence(timeout: 5)); inbox.tap()
    let messages = app.buttons["inboxMessages"], requests = app.buttons["inboxRequests"], groups = app.buttons["inboxGroups"]
    XCTAssertTrue(requests.waitForExistence(timeout: 5))
    XCTAssertEqual(messages.value as? String, "0 unread messages")
    XCTAssertEqual(requests.value as? String, "1 pending requests")
    XCTAssertEqual(groups.value as? String, "0 unread messages")
    XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Any good coffee spots near campus?")).firstMatch.exists)
    requests.tap()
    XCTAssertFalse(app.staticTexts["Anonymous • coffee post"].exists)
    let request = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Any good coffee spots near campus?")).firstMatch
    XCTAssertTrue(request.waitForExistence(timeout: 3)); request.tap()
    XCTAssertTrue(app.buttons["declineRequest"].waitForExistence(timeout: 3))
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertEqual(requests.value as? String, "1 pending requests", "Reading an invitation does not accept or decline it")
    groups.tap()
    XCTAssertFalse(request.exists)
  }
}
