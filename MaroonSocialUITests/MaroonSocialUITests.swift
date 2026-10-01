import XCTest

final class MaroonSocialUITests: XCTestCase {
  @MainActor func testPreviewJourney() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap()
    username.typeText("testaggie")
    app.switches["adultToggle"].tap()
    app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    app.buttons["Create post"].tap()
    let post = app.textViews["postText"]
    XCTAssertTrue(post.waitForExistence(timeout: 3))
    post.tap()
    post.typeText("Testing our campus conversation")
    app.buttons["Post"].tap()
    XCTAssertTrue(app.buttons["Testing our campus conversation"].waitForExistence(timeout: 5))
    app.tabBars.buttons["Classes"].tap()
    app.swipeUp()
    let join = app.buttons["join-CHEM 107"]
    XCTAssertTrue(join.waitForExistence(timeout: 3))
    join.tap()
    app.tabBars.buttons["Inbox"].tap()
    app.staticTexts["CHEM 107"].tap()
    let message = app.textFields["messageText"]
    XCTAssertTrue(message.waitForExistence(timeout: 3))
    message.tap()
    message.typeText("Study group at Evans")
    app.buttons["Send message"].tap()
    XCTAssertTrue(app.staticTexts["Study group at Evans"].exists)
    app.buttons["Done"].tap()
    app.tabBars.buttons["Campus"].tap()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bus routes")).firstMatch
        .waitForExistence(timeout: 3))
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Campus calendar"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
  @MainActor func testGamesAndHangout() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap()
    username.typeText("gameaggie")
    app.switches["adultToggle"].tap()
    app.buttons["enterPreview"].tap()
    app.tabBars.buttons["Explore"].tap()
    app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Hangouts")).firstMatch.tap()
    app.navigationBars.buttons["Create"].tap()
    app.textFields["Give it a name"].tap()
    app.textFields["Give it a name"].typeText("Coffee at MSC")
    app.textFields["Public meeting place"].tap()
    app.textFields["Public meeting place"].typeText("Memorial Student Center")
    app.buttons["publishActivity"].tap()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Coffee at MSC")).firstMatch
        .waitForExistence(timeout: 4))
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.swipeUp()
    app.swipeUp()
    let chess = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Chess")).firstMatch
    XCTAssertTrue(chess.waitForExistence(timeout: 4))
    chess.tap()
    XCTAssertTrue(app.staticTexts["chessStatus"].waitForExistence(timeout: 4))
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "Native 3D chess"
    shot.lifetime = .keepAlways
    add(shot)
    app.switches["Show labeled board"].tap()
    app.swipeUp()
    app.buttons["square-e2"].tap()
    app.buttons["square-e4"].tap()
    XCTAssertEqual(app.staticTexts["chessStatus"].label, "Black to move")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let pool = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "8 Ball")).firstMatch
    if !pool.isHittable { app.swipeDown() }
    pool.tap()
    XCTAssertTrue(app.buttons["takeShot"].waitForExistence(timeout: 4))
    app.buttons["takeShot"].tap()
    XCTAssertTrue(app.staticTexts["1 shots"].exists)
    let table = XCTAttachment(screenshot: app.screenshot())
    table.name = "Native 3D pool"
    table.lifetime = .keepAlways
    add(table)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let pong = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Cup Pong")).firstMatch
    if !pong.isHittable { app.swipeUp() }
    pong.tap()
    app.buttons["takeShot"].tap()
    XCTAssertTrue(app.staticTexts["1 cups"].waitForExistence(timeout: 5))
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.swipeDown()
    app.swipeDown()
    app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Open the lobby")).firstMatch
      .tap()
    XCTAssertTrue(app.buttons["Start practice"].waitForExistence(timeout: 3))
    app.buttons["Start practice"].tap()
    let allow = app.alerts.buttons["Allow Once"]
    if allow.waitForExistence(timeout: 2) { allow.tap() }
    XCTAssertTrue(app.buttons["End practice"].waitForExistence(timeout: 3))
    app.buttons["End practice"].tap()
    XCTAssertTrue(app.buttons["Start practice"].exists)

  }
}
