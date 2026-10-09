import XCTest

/// 8 Ball, Cup Pong and Campus Tag are hidden (FeatureAvailability), not deleted.
/// With plain `--uitesting` none of their entry points appear; Chess stays.
@MainActor final class HiddenFeaturesUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  private func launch() -> XCUIApplication {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10)); username.tap(); username.typeText("hidden_tester")
    app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    return app
  }
  private func containing(_ text: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
  }
  private func attach(_ app: XCUIApplication, _ name: String) {
    let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
  }

  func testExploreShowsChessButNoCampusTagOrHiddenGames() {
    let app = launch()
    app.tabBars.buttons["Explore"].tap()
    XCTAssertTrue(app.buttons["exploreCommunities"].waitForExistence(timeout: 5))
    XCTAssertTrue(containing("Meet people", in: app).exists, "Meet people keeps its tile")
    XCTAssertFalse(containing("Campus Tag", in: app).exists, "The Campus Tag tile is hidden")
    let chess = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Chess")).firstMatch
    for _ in 0..<5 where !chess.isHittable { app.swipeUp() }
    XCTAssertTrue(chess.isHittable, "Chess stays in the Games list")
    XCTAssertTrue(containing("Online matches", in: app).exists)
    XCTAssertFalse(containing("8 Ball", in: app).exists, "8 Ball is hidden from Explore")
    XCTAssertFalse(containing("Cup Pong", in: app).exists, "Cup Pong is hidden from Explore")
    attach(app, "Explore without hidden games")
  }

  func testChatShowsHiddenInvitationAsUnavailableAndOffersOnlyChess() {
    let app = launch()
    app.tabBars.buttons["Inbox"].tap()
    let messages = app.buttons["inboxMessages"]
    XCTAssertTrue(messages.waitForExistence(timeout: 5)); messages.tap()
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Thanks for the study room tip!")).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
    XCTAssertTrue(app.textFields["messageText"].waitForExistence(timeout: 5))

    // The seeded 8 Ball invitation renders as a non-tappable, secondary row.
    let unavailable = app.descendants(matching: .any)["hiddenGameInvitation"].firstMatch
    XCTAssertTrue(unavailable.waitForExistence(timeout: 5), "A hidden-kind invitation shows its unavailable row")
    XCTAssertTrue(unavailable.label.contains("8 Ball isn’t available right now"), unavailable.label)
    XCTAssertFalse(app.buttons["hiddenGameInvitation"].exists, "The unavailable row is not a button")
    XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Open 8 Ball")).firstMatch.exists)
    XCTAssertFalse(containing("Pool invitation", in: app).exists, "The server-written invitation text is not shown, even in a reply quote")
    let quote = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND identifier != %@", "8 Ball isn’t available right now", "hiddenGameInvitation")).firstMatch
    XCTAssertTrue(quote.exists, "A reply that quotes the hidden invitation shows the unavailable copy")
    XCTAssertTrue(containing("Are you free after class?", in: app).exists)
    attach(app, "Hidden 8 Ball invitation in chat")

    // Long-press: no Copy for the hidden invitation; Reply quotes the unavailable copy, not the server body.
    unavailable.press(forDuration: 1.2)
    let reply = app.buttons["Reply"]
    XCTAssertTrue(reply.waitForExistence(timeout: 5), "The invitation keeps its context menu")
    XCTAssertFalse(app.buttons["Copy"].exists, "A hidden invitation offers no Copy")
    reply.tap()
    let banner = containing("Replying to:", in: app)
    XCTAssertTrue(banner.waitForExistence(timeout: 5))
    XCTAssertTrue(banner.label.contains("8 Ball isn’t available right now"), banner.label)
    XCTAssertFalse(containing("Pool invitation", in: app).exists, "The reply banner never shows the server body")
    attach(app, "Replying to a hidden invitation")
    app.buttons["Cancel reply"].tap()
    XCTAssertFalse(containing("Replying to:", in: app).exists)

    // The game-invite sheet offers Chess only.
    app.buttons["Send game"].tap()
    let invite = app.buttons["Invite to a game"]
    XCTAssertTrue(invite.waitForExistence(timeout: 5)); invite.tap()
    XCTAssertTrue(app.buttons["gameInviteOption-chess"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["gameInviteOption-pool"].exists)
    XCTAssertFalse(app.buttons["gameInviteOption-pong"].exists)
    XCTAssertTrue(app.buttons["sendGameInvitation"].exists)
    attach(app, "Invite sheet with Chess only")
  }

  func testEnableHiddenFeaturesArgumentRestoresEntryPoints() {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--enable-hidden-features"]; app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10)); username.tap(); username.typeText("hidden_tester")
    app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    app.tabBars.buttons["Explore"].tap()
    XCTAssertTrue(containing("Campus Tag", in: app).waitForExistence(timeout: 5))
    let pong = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Cup Pong")).firstMatch
    for _ in 0..<5 where !pong.isHittable { app.swipeUp() }
    XCTAssertTrue(pong.isHittable)
    XCTAssertTrue(containing("8 Ball", in: app).exists)
  }
}
