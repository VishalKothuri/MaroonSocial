import XCTest

/// Native fixture inputs exercise validation and draft retention, never pretend
/// to deliver live groups. Backend tests cover invitation delivery and privacy.
@MainActor final class CommunitiesUITests: XCTestCase {
  private let unavailable = "Community changes are unavailable in this test session."
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    guard (testRun?.failureCount ?? 0) > 0 else { return }
    let app = XCUIApplication(); print(app.debugDescription)
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = "Group input failure"; image.lifetime = .keepAlways; add(image)
  }
  private func launch(accessibilityText: Bool = false) -> XCUIApplication {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]
    if accessibilityText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
    app.launch()
    let name = app.textFields["username"]
    XCTAssertTrue(name.waitForExistence(timeout: 10)); name.tap(); name.typeText("group_tester")
    let adult = app.switches["adultToggle"]
    (adult.switches.firstMatch.exists ? adult.switches.firstMatch : adult).tap()
    app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5)); return app
  }
  private func openDirectory(_ app: XCUIApplication) {
    app.tabBars.buttons["Explore"].tap()
    let entry = app.buttons["exploreCommunities"]; reveal(entry, in: app); entry.tap()
    XCTAssertTrue(app.textFields["communitySearch"].waitForExistence(timeout: 5))
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
  private func field(_ id: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: id).firstMatch
  }
  private func fill(_ id: String, _ text: String, in app: XCUIApplication) {
    let input = field(id, in: app); reveal(input, in: app); input.tap(); input.typeText(text)
    let done = app.buttons["hideKeyboard"].firstMatch
    XCTAssertTrue(done.waitForExistence(timeout: 3)); done.tap()
  }
  private func replace(_ id: String, with text: String, in app: XCUIApplication) {
    let input = field(id, in: app); reveal(input, in: app)
    let previous = input.value as? String ?? ""
    input.tap()
    input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
    let cleared = input.value as? String ?? ""
    XCTAssertTrue(cleared.isEmpty || cleared == input.placeholderValue, "Clear the old value before replacement")
    input.typeText(text)
    let done = app.buttons["hideKeyboard"].firstMatch
    XCTAssertTrue(done.waitForExistence(timeout: 3)); done.tap()
    XCTAssertEqual(input.value as? String, text, "Verify the intended draft before testing navigation retention")
  }
  private func assertStep(_ title: String, in app: XCUIApplication) {
    let step = app.staticTexts["groupStepTitle"]
    XCTAssertTrue(step.waitForExistence(timeout: 3))
    let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", title), object: step)
    XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed)
  }
  private func next(_ app: XCUIApplication) { app.buttons["groupContinue"].tap() }
  private func back(_ app: XCUIApplication) { app.buttons["groupBack"].tap() }
  private func discard(_ app: XCUIApplication) {
    app.buttons["groupCancel"].tap()
    XCTAssertTrue(app.alerts["Keep this group draft?"].waitForExistence(timeout: 3))
    app.alerts.buttons["Discard draft"].tap()
  }
  private func enterDetails(_ app: XCUIApplication, name: String, about: String) {
    assertStep("Group details", in: app)
    fill("groupName", name, in: app); fill("groupDescription", about, in: app)
  }
  func testInvitationKeyboardKeepsInputAndFooterSeparateWithoutDoneAccessory() {
    let app = launch(); app.tabBars.buttons["Inbox"].tap()
    app.buttons["newConversation"].tap(); app.buttons["New group"].tap()
    enterDetails(app, name: "Keyboard layout check", about: "A small group for checking the invitation form.")
    let purpose = app.buttons["groupPurpose-Friends"]; reveal(purpose, in: app); purpose.tap(); next(app)
    fill("groupAlias", "maroon_owl", in: app); next(app)
    let input = field("groupInviteUsernames", in: app)
    input.tap(); input.typeText("friend_one, friend_two, friend_three")
    let keyboard = app.keyboards.firstMatch
    XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["Done"].exists)
    let create = app.buttons["groupCreateSubmit"]
    XCTAssertTrue(input.isHittable); XCTAssertTrue(create.isHittable)
    XCTAssertLessThanOrEqual(input.frame.maxY, create.frame.minY, "The footer must never cover the invitation editor")
    XCTAssertLessThanOrEqual(create.frame.maxY, keyboard.frame.minY + 1, "The create action must stay above the keyboard")
    app.buttons["hideKeyboard"].tap()
    let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: keyboard)
    XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 3), .completed)
    XCTAssertEqual(input.value as? String, "friend_one, friend_two, friend_three")
    input.tap()
    XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
    create.tap()
    XCTAssertTrue(app.staticTexts["groupSetupError"].waitForExistence(timeout: 5))
    XCTAssertEqual(input.value as? String, "friend_one, friend_two, friend_three", "Unavailable creation must preserve the keyboard-entered draft")
    discard(app)
  }
  func testPublicGroupWizardValidatesAndRetainsDraftAcrossBackAndUnavailableCreation() {
    let app = launch(); openDirectory(app); app.buttons["communityCreate"].tap()
    assertStep("Group details", in: app)
    XCTAssertFalse(app.buttons["groupContinue"].isEnabled)
    enterDetails(app, name: "Ag", about: "Meet other Aggies for weekend study sessions.")
    let purpose = app.buttons["groupPurpose-Study Group"]; reveal(purpose, in: app); purpose.tap()
    XCTAssertFalse(app.buttons["groupContinue"].isEnabled)
    fill("groupName", "gie study circle", in: app)
    XCTAssertEqual(app.staticTexts["groupPreviewName"].label, "Aggie study circle")
    let editAvatar = app.buttons["groupEditAvatar"]; reveal(editAvatar, in: app); editAvatar.tap()
    let groupAvatar = app.buttons["groupAvatar-sage"]; reveal(groupAvatar, in: app); groupAvatar.tap()
    XCTAssertTrue(groupAvatar.isSelected)
    let publicGroup = app.buttons["groupPublic"]; reveal(publicGroup, in: app)
    publicGroup.tap(); XCTAssertTrue(publicGroup.isSelected); next(app)
    assertStep("Your identity", in: app)
    XCTAssertFalse(app.buttons["groupContinue"].isEnabled)
    XCTAssertNotEqual(field("groupAlias", in: app).value as? String, "group_tester")
    fill("groupAlias", "ag", in: app); XCTAssertFalse(app.buttons["groupContinue"].isEnabled)
    replace("groupAlias", with: "aggie_reader", in: app)
    let personalAvatar = app.buttons["groupMemberAvatar-rose"]; reveal(personalAvatar, in: app); personalAvatar.tap()
    XCTAssertTrue(personalAvatar.isSelected)
    XCTAssertEqual(app.staticTexts["groupIdentityPreview"].label, "aggie_reader")
    back(app); assertStep("Group details", in: app)
    XCTAssertTrue(app.buttons["groupPublic"].isSelected)
    XCTAssertEqual(field("groupName", in: app).value as? String, "Aggie study circle")
    XCTAssertEqual(field("groupDescription", in: app).value as? String, "Meet other Aggies for weekend study sessions.")
    XCTAssertTrue(app.buttons["groupAvatar-sage"].isSelected)
    next(app); assertStep("Your identity", in: app)
    XCTAssertEqual(field("groupAlias", in: app).value as? String, "aggie_reader")
    XCTAssertTrue(app.buttons["groupMemberAvatar-rose"].isSelected); next(app)
    assertStep("Invitations", in: app)
    fill("groupInviteUsernames", "friend_one, @friend_two", in: app)
    let create = app.buttons["groupCreateSubmit"]; XCTAssertTrue(create.isEnabled); create.tap()
    let error = app.staticTexts["groupSetupError"]; XCTAssertTrue(error.waitForExistence(timeout: 5))
    XCTAssertEqual(error.label, unavailable); assertStep("Invitations", in: app)
    XCTAssertEqual(field("groupInviteUsernames", in: app).value as? String, "friend_one, @friend_two")
    app.buttons["groupCancel"].tap()
    XCTAssertTrue(app.alerts["Keep this group draft?"].waitForExistence(timeout: 3))
    app.alerts.buttons["Keep editing"].tap()
    XCTAssertEqual(field("groupInviteUsernames", in: app).value as? String, "friend_one, @friend_two")
    discard(app)
    XCTAssertTrue(app.textFields["communitySearch"].waitForExistence(timeout: 3))
  }
  func testAccessibilityTextKeepsGroupCreationReachableWithKeyboard() {
    let app = launch(accessibilityText: true); app.tabBars.buttons["Inbox"].tap()
    app.buttons["newConversation"].tap(); app.buttons["New group"].tap()
    enterDetails(app, name: "Accessible group", about: "A place to plan our next campus meetup.")
    let purpose = app.buttons["groupPurpose-Friends"]; reveal(purpose, in: app); purpose.tap()
    let nextStep = app.buttons["groupContinue"]
    XCTAssertTrue(nextStep.isHittable)
    XCTAssertGreaterThanOrEqual(nextStep.frame.height, 50)
    next(app); assertStep("Your identity", in: app)
    fill("groupAlias", "campus_owl", in: app); next(app)
    assertStep("Invitations", in: app)
    let input = field("groupInviteUsernames", in: app); reveal(input, in: app)
    input.tap(); input.typeText("friend_one")
    let keyboard = app.keyboards.firstMatch
    XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
    let create = app.buttons["groupCreateSubmit"]
    XCTAssertTrue(input.isHittable); XCTAssertTrue(create.isHittable)
    XCTAssertLessThanOrEqual(input.frame.maxY, create.frame.minY)
    XCTAssertLessThanOrEqual(create.frame.maxY, keyboard.frame.minY + 1)
    XCTAssertGreaterThanOrEqual(create.frame.height, 50)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Group invitations at Accessibility XXXL with keyboard"
    screenshot.lifetime = .keepAlways; add(screenshot)
    app.buttons["hideKeyboard"].tap()
    XCTAssertEqual(input.value as? String, "friend_one")
    discard(app)
  }
  func testInboxGroupUsesSameWizardAndExplicitlySkipsInvitationsWithoutFakeSuccess() {
    let app = launch(); app.tabBars.buttons["Inbox"].tap()
    app.buttons["newConversation"].tap(); app.buttons["New group"].tap()
    assertStep("Group details", in: app)
    enterDetails(app, name: "Our weekend chat", about: "A private chat for planning weekends together.")
    let purpose = app.buttons["groupPurpose-Friends"]; reveal(purpose, in: app); purpose.tap()
    let inviteOnly = app.buttons["groupInviteOnly"]; reveal(inviteOnly, in: app)
    XCTAssertTrue(app.buttons["groupInviteOnly"].isSelected)
    XCTAssertFalse(app.buttons["groupPublic"].isSelected)
    next(app); assertStep("Your identity", in: app)
    fill("groupAlias", "weekend_owl", in: app); next(app)
    assertStep("Invitations", in: app)
    XCTAssertTrue(app.buttons["groupSkipInvites"].isEnabled)
    app.buttons["groupSkipInvites"].tap()
    let error = app.staticTexts["groupSetupError"]; XCTAssertTrue(error.waitForExistence(timeout: 5))
    XCTAssertEqual(error.label, unavailable)
    XCTAssertTrue(app.navigationBars["New group"].exists)
    back(app); assertStep("Your identity", in: app)
    XCTAssertEqual(field("groupAlias", in: app).value as? String, "weekend_owl")
    discard(app)
    XCTAssertTrue(app.buttons["newConversation"].waitForExistence(timeout: 3))
  }
  func testInviteCodeRequiresCompleteCodeAndChosenRoomIdentityWithoutExposingAccountName() {
    let app = launch(); openDirectory(app); app.buttons["communityInviteEntry"].tap()
    XCTAssertTrue(app.navigationBars["Join with a code"].waitForExistence(timeout: 3))
    let code = app.textFields["communityInviteCode"]
    let join = app.buttons["communityCodeJoin"]
    reveal(join, in: app); XCTAssertFalse(join.isEnabled)
    // Move back to the beginning of the form after inspecting its submit row.
    app.swipeDown(velocity: .slow)
    fill("communityInviteCode", "ab-12g", in: app)
    XCTAssertEqual(code.value as? String, "AB12")
    fill("groupAlias", "night_owl", in: app)
    reveal(join, in: app); XCTAssertFalse(join.isEnabled, "An alias cannot make a partial code valid")
    app.swipeDown(velocity: .slow)
    fill("communityInviteCode", "CDEF34", in: app)
    XCTAssertEqual(code.value as? String, "AB12CDEF34")
    let avatar = app.buttons["groupMemberAvatar-sky"]; reveal(avatar, in: app); avatar.tap()
    XCTAssertTrue(avatar.isSelected)
    reveal(join, in: app); XCTAssertTrue(join.isEnabled); join.tap()
    let error = app.staticTexts["groupIdentityError"]
    XCTAssertTrue(error.waitForExistence(timeout: 5)); XCTAssertEqual(error.label, unavailable)
    XCTAssertTrue(app.navigationBars["Join with a code"].exists)
    app.swipeDown(velocity: .slow)
    XCTAssertEqual(code.value as? String, "AB12CDEF34")
    XCTAssertEqual(field("groupAlias", in: app).value as? String, "night_owl")
    XCTAssertFalse(app.staticTexts["group_tester"].exists)
    app.buttons["groupIdentityCancel"].tap()
    XCTAssertTrue(app.alerts["Discard your group identity changes?"].waitForExistence(timeout: 3))
    app.alerts.buttons["Keep editing"].tap()
    XCTAssertEqual(field("groupAlias", in: app).value as? String, "night_owl")
    app.buttons["groupIdentityCancel"].tap(); app.alerts.buttons["Discard changes"].tap()
    XCTAssertTrue(app.textFields["communitySearch"].waitForExistence(timeout: 3))
  }
}
