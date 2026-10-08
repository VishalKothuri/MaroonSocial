import XCTest

/// Offline journey: a composed meme becomes an editable image attachment, the
/// one-time policy notice and share offer follow, the editor adds text and a
/// searched sticker, and the shared result appears under the Community tab.
@MainActor final class ImageEditorUITests: XCTestCase {
  private var app: XCUIApplication!
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    if let app, !app.debugDescription.isEmpty {
      let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.lifetime = .keepAlways; add(attachment)
    }
  }
  private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "--uitesting-images"]
    app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10)); username.tap(); username.typeText("editor_tester")
    app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    self.app = app
    return app
  }
  private func waitHittable(_ element: XCUIElement, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed, file: file, line: line)
  }
  private func attachMeme(in app: XCUIApplication) {
    app.buttons["Post attachments"].tap()
    app.buttons["Make a meme"].tap()
    let caption = app.descendants(matching: .any)["memeTopCaption"].firstMatch
    XCTAssertTrue(caption.waitForExistence(timeout: 5))
    caption.tap(); caption.typeText("EDIT ME LATER")
    app.buttons["hideKeyboard"].tap()
    waitHittable(app.buttons["useMeme"])
    app.buttons["useMeme"].tap()
    XCTAssertTrue(app.buttons["Remove attachment"].waitForExistence(timeout: 5))
  }

  func testFirstImageShowsPolicyOnceThenEditorAndSharingReachTheCommunityTab() {
    let app = launch()
    attachMeme(in: app)
    // The policy notice appears exactly once per device, before any sharing offer.
    XCTAssertTrue(app.alerts.staticTexts["No PII or human faces can be in the image. Posting them will cause a ban."].waitForExistence(timeout: 5))
    app.alerts.buttons["I understand"].tap()
    XCTAssertTrue(app.buttons["Not now"].waitForExistence(timeout: 5), "After the notice, the same image is offered for sharing")
    app.buttons["Not now"].tap()
    // Edit the composed meme: a text layer, then a searched sticker.
    waitHittable(app.buttons["postEditImage"])
    app.buttons["postEditImage"].tap()
    waitHittable(app.buttons["imageEditorAddText"])
    app.buttons["imageEditorAddText"].tap()
    let field = app.alerts.textFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("HOWDY")
    app.alerts.buttons["Add"].tap()
    XCTAssertTrue(app.buttons["imageEditorRemoveItem"].waitForExistence(timeout: 5), "A new text layer is selected")
    XCTAssertTrue(app.staticTexts["1 layer"].exists)
    app.buttons["imageEditorSearch"].tap()
    let search = app.textFields["imageSearchField"]
    XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("campus")
    let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'imageSearchItem-'")).firstMatch
    waitHittable(result, timeout: 8)
    result.tap()
    XCTAssertTrue(app.staticTexts["2 layers"].waitForExistence(timeout: 8), "The searched picture becomes a sticker layer")
    XCTAssertTrue(app.buttons["imageEditorCutout"].exists, "A selected sticker offers a background cut-out")
    app.buttons["imageEditorUse"].tap()
    XCTAssertTrue(app.staticTexts["Image attached"].waitForExistence(timeout: 10))
    // The edited image is offered for sharing again; no second policy notice.
    XCTAssertTrue(app.buttons["Share as a meme"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.alerts.buttons["I understand"].exists)
    app.buttons["Share as a meme"].tap()
    XCTAssertTrue(app.staticTexts["Shared to the meme library. Thanks!"].waitForExistence(timeout: 8))
    // It is now in everyone's library under the picker's Community tab.
    // The composer is open with the image, so GIF search is a button in its tool row.
    let gif = app.buttons["postKlipyPicker"]; app.revealInComposer(gif); gif.tap()
    waitHittable(app.buttons["klipyTab-community"])
    app.buttons["klipyTab-community"].tap()
    let shared = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'communityItem-published-'")).firstMatch
    waitHittable(shared, timeout: 8)
    shared.tap()
    waitHittable(app.buttons["communityAttach"], timeout: 8)
    app.buttons["communityAttach"].tap()
    XCTAssertTrue(app.staticTexts["Image attached"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Remove attachment"].exists)
  }

  func testPolicyNoticeIsNotRepeatedAfterRelaunchWithPreservedState() {
    let app = launch()
    attachMeme(in: app)
    XCTAssertTrue(app.alerts.buttons["I understand"].waitForExistence(timeout: 5))
    app.alerts.buttons["I understand"].tap()
    XCTAssertTrue(app.buttons["Not now"].waitForExistence(timeout: 5)); app.buttons["Not now"].tap()
    app.terminate()
    app.launchArguments = ["--uitesting-preserve", "--uitesting-images"]
    app.launch()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    attachMeme(in: app)
    XCTAssertTrue(app.buttons["Not now"].waitForExistence(timeout: 5), "The share offer still appears")
    XCTAssertFalse(app.alerts.buttons["I understand"].exists, "The policy notice was acknowledged on this device")
    app.buttons["Not now"].tap()
  }
}
