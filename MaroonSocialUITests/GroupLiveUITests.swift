import XCTest

/// Opt-in integration against the two explicitly selected development accounts.
/// Normal suite runs skip this; the coordinating .xctestrun supplies only a
/// stage, a unique test-group title and the intended peer's account username.
@MainActor final class GroupLiveUITests: XCTestCase {
  private var ranLiveFlow = false
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    guard ranLiveFlow else { return }
    let image = XCTAttachment(screenshot: XCUIApplication().screenshot())
    image.name = "Live group flow"; image.lifetime = .keepAlways; add(image)
    if (testRun?.failureCount ?? 0) > 0 { print(XCUIApplication().debugDescription) }
  }

  func testTwoPhoneInvitationAndScopedIdentity() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let stage = environment["MAROON_GROUP_LIVE_STAGE"],
      let title = environment["MAROON_GROUP_LIVE_TITLE"], title.hasPrefix("Simulator group ") else {
      throw XCTSkip("Live two-phone group testing requires an explicit test-run configuration")
    }
    ranLiveFlow = true
    let app = XCUIApplication(); app.launchArguments = []; app.launch()
    XCTAssertTrue(app.tabBars.buttons["Inbox"].waitForExistence(timeout: 20))
    app.tabBars.buttons["Inbox"].tap()
    switch stage {
    case "create":
      let peer = try XCTUnwrap(environment["MAROON_GROUP_LIVE_PEER"])
      app.buttons["newConversation"].tap(); app.buttons["New group"].tap()
      XCTAssertTrue(app.textFields["groupName"].waitForExistence(timeout: 5))
      fill("groupName", title, in: app)
      fill("groupDescription", "Private two-phone check of invitations and group identities.", in: app)
      let purpose = app.buttons["groupPurpose-Friends"]; reveal(purpose, in: app); purpose.tap()
      let visibility = app.buttons["groupInviteOnly"]; reveal(visibility, in: app); visibility.tap()
      app.buttons["groupContinue"].tap()
      fill("groupAlias", "CopperOwl", in: app)
      app.buttons["groupContinue"].tap()
      fill("groupInviteUsernames", peer, in: app)
      app.buttons["groupCreateSubmit"].tap()
      XCTAssertTrue(field("messageText", in: app).waitForExistence(timeout: 20), app.debugDescription)
      send("Owner alias test", in: app)
      XCTAssertTrue(app.staticTexts["CopperOwl · You"].waitForExistence(timeout: 5))
    case "accept":
      app.buttons["inboxRequests"].tap()
      let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 20)); row.tap()
      XCTAssertFalse(app.staticTexts["Owner alias test"].exists, "Pending invitees cannot read group history")
      XCTAssertFalse(field("messageText", in: app).exists)
      app.buttons["Accept request"].tap()
      fill("groupAlias", "CopperOwl", in: app)
      let accept = app.buttons["groupIdentitySubmit"]; reveal(accept, in: app); accept.tap()
      let error = app.staticTexts["groupIdentityError"]
      XCTAssertTrue(error.waitForExistence(timeout: 10))
      XCTAssertTrue(error.label.localizedCaseInsensitiveContains("already"), error.label)
      replace("groupAlias", "SilverOtter", in: app)
      let avatar = app.buttons["groupMemberAvatar-sky"]; reveal(avatar, in: app); avatar.tap()
      reveal(accept, in: app); accept.tap()
      XCTAssertTrue(field("messageText", in: app).waitForExistence(timeout: 15))
      XCTAssertTrue(app.staticTexts["Owner alias test"].waitForExistence(timeout: 5))
      XCTAssertTrue(app.staticTexts["CopperOwl"].exists)
      send("Recipient alias test", in: app)
      XCTAssertTrue(app.staticTexts["SilverOtter · You"].waitForExistence(timeout: 5))
      XCTAssertFalse(app.buttons["Accept request"].exists)
    case "verify":
      app.buttons["inboxGroups"].tap()
      let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 20)); row.tap()
      XCTAssertTrue(app.staticTexts["Recipient alias test"].waitForExistence(timeout: 10))
      XCTAssertTrue(app.staticTexts["SilverOtter"].exists)
      app.buttons["Conversation options"].tap(); app.buttons["groupSettings"].tap()
      XCTAssertTrue(app.staticTexts["SilverOtter"].waitForExistence(timeout: 10))
      XCTAssertTrue(app.staticTexts["CopperOwl"].exists)
      XCTAssertFalse(app.staticTexts["@ads"].exists, "Accepted roster exposes the chosen room identity")
      XCTAssertFalse(app.staticTexts["@testaggie"].exists)
    default: XCTFail("Unknown live group stage")
    }
  }

  private func field(_ id: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: id).firstMatch
  }
  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    let form = app.scrollViews["groupSetupForm"]
    let surface = form.exists ? form : app
    func visibleCenter() -> Bool {
      guard element.isHittable else { return false }
      guard form.exists else { return true }
      let navigation = app.navigationBars["New group"]
      let top = max(form.frame.minY, navigation.exists ? navigation.frame.maxY : form.frame.minY)
      return element.frame.midY >= top + 8 && element.frame.midY <= form.frame.maxY - 8
    }
    for _ in 0..<7 where !visibleCenter() {
      if element.exists && element.frame.midY < surface.frame.midY { surface.swipeDown(velocity: .slow) }
      else { surface.swipeUp(velocity: .slow) }
    }
    XCTAssertTrue(visibleCenter(), "The target's center must be inside the visible form before tapping")
  }
  private func fill(_ id: String, _ text: String, in app: XCUIApplication) {
    let input = field(id, in: app); XCTAssertTrue(input.waitForExistence(timeout: 5))
    reveal(input, in: app); input.tap(); input.typeText(text)
    if app.buttons["hideKeyboard"].firstMatch.exists { app.buttons["hideKeyboard"].firstMatch.tap() }
  }
  private func replace(_ id: String, _ text: String, in app: XCUIApplication) {
    let input = field(id, in: app)
    for _ in 0..<4 where !input.isHittable { app.swipeDown(velocity: .slow) }
    input.tap()
    let old = input.value as? String ?? ""
    input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + text)
    if app.buttons["hideKeyboard"].firstMatch.exists { app.buttons["hideKeyboard"].firstMatch.tap() }
  }
  private func send(_ text: String, in app: XCUIApplication) {
    let input = field("messageText", in: app); input.tap(); input.typeText(text)
    app.buttons["Send message"].tap()
    XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 10))
    if app.buttons["hideKeyboard"].firstMatch.exists { app.buttons["hideKeyboard"].firstMatch.tap() }
  }
}
