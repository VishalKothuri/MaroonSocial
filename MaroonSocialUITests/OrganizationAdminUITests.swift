import XCTest

/// Fixture journey for private administrator tools. Fixture mutations prove native
/// wiring and copy, not network delivery; tools/test-organization-admins.py covers the live service.
@MainActor final class OrganizationAdminUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<5 where !element.isHittable { app.swipeUp() }
    XCTAssertTrue(element.isHittable, "Expected control to be visible: \(element)")
  }
  func testOwnerInvitesRevokesAndAcceptsAnIncomingInvitation() {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
    let username = app.textFields["username"]; XCTAssertTrue(username.waitForExistence(timeout: 10))
    username.tap(); username.typeText("org_tester"); app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    let profile = app.buttons["Profile and settings"]; XCTAssertTrue(profile.waitForExistence(timeout: 5)); profile.tap()
    // Settings is a lazy List: rows below the fold are absent until scrolled into view.
    let organizations = app.buttons["settingsOrganizations"]
    for _ in 0..<6 where !organizations.exists { app.swipeUp() }
    XCTAssertTrue(organizations.waitForExistence(timeout: 3)); reveal(organizations, in: app); organizations.tap()
    XCTAssertTrue(app.navigationBars["Organizations"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Administrator invitations"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Accepting shows your account username, @org_tester, to this organization’s owner. Nobody else sees it."].exists)
    XCTAssertTrue(app.buttons["organizationInvitationAccept"].exists); XCTAssertTrue(app.buttons["organizationInvitationDecline"].exists)
    let managed = app.staticTexts["Aggie Robotics"].firstMatch; reveal(managed, in: app); managed.tap()
    let tools = app.buttons["organizationAdministrators"]; XCTAssertTrue(tools.waitForExistence(timeout: 3)); tools.tap()
    let role = app.staticTexts["organizationMyRole"]; XCTAssertTrue(role.waitForExistence(timeout: 3)); XCTAssertEqual(role.label, "You are the owner")
    XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "organizationAdministrator").count, 2)
    XCTAssertTrue(app.staticTexts["No pending invitations."].exists)
    XCTAssertFalse(app.buttons["organizationInviteSend"].isEnabled, "Sending needs a valid username first.")
    let field = app.textFields["organizationInviteUsername"]; reveal(field, in: app); field.tap(); field.typeText("new_admin\n")
    let pending = app.descendants(matching: .any).matching(identifier: "organizationPendingInvitation").firstMatch; XCTAssertTrue(pending.waitForExistence(timeout: 3))
    XCTAssertTrue(pending.label.contains("@new_admin")); XCTAssertTrue(pending.label.contains("Administrator"))
    XCTAssertTrue(app.staticTexts["Invitation sent to @new_admin."].exists)
    XCTAssertEqual(field.value as? String ?? "", "Account username", "A sent draft clears its username so the next draft gets a new nonce.")
    let revoke = app.buttons["organizationInvitationRevoke"]; reveal(revoke, in: app); revoke.tap()
    XCTAssertTrue(app.staticTexts["No pending invitations."].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Invitation to @new_admin revoked."].exists)
    app.navigationBars["Administrators"].buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.navigationBars["Organization"].waitForExistence(timeout: 3))
    app.navigationBars["Organization"].buttons.element(boundBy: 0).tap()
    let accept = app.buttons["organizationInvitationAccept"]; XCTAssertTrue(accept.waitForExistence(timeout: 3)); accept.tap()
    XCTAssertTrue(app.staticTexts["You now administer Maroon Makers."].waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["organizationInvitationAccept"].exists); XCTAssertFalse(app.staticTexts["Administrator invitations"].exists)
  }
}
