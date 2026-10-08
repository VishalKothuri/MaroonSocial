import XCTest

@MainActor final class KlipyPickerUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    if (testRun?.failureCount ?? 0) > 0 {
      let app = XCUIApplication(); print(app.debugDescription)
      let image = XCTAttachment(screenshot: app.screenshot()); image.name = "KLIPY picker failure"; image.lifetime = .keepAlways; add(image)
    }
  }
  private func launch(realisticMedia: Bool) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = realisticMedia ? ["--uitesting", "--uitesting-klipy"] : ["--uitesting"]
    app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10)); username.tap(); username.typeText("meme_tester")
    app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    let create = app.buttons["Create post"]; XCTAssertTrue(create.waitForExistence(timeout: 5)); create.tap()
    let editor = app.textViews["postText"]; XCTAssertTrue(editor.waitForExistence(timeout: 5))
    editor.tap(); editor.typeText("Keep this draft")
    openPicker(app)
    return app
  }
  private func openPicker(_ app: XCUIApplication) {
    app.buttons["Post attachments"].tap(); app.buttons["postKlipyPicker"].tap()
    XCTAssertTrue(app.buttons["klipyCancel"].waitForExistence(timeout: 5))
  }
  private func waitForAbsent(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    let missing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [missing], timeout: 5), .completed, file: file, line: line)
  }
  private func waitForAttach(_ app: XCUIApplication) {
    let attach = app.buttons["klipyAttach"]
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: attach)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    XCTAssertTrue(app.descendants(matching: .any)["klipyPreview"].exists)
  }
  func testPickerUnavailableFixturePreservesPostDraftAndCancelWorks() {
    let app = launch(realisticMedia: false)
    XCTAssertTrue(app.otherElements["klipyUnavailable"].waitForExistence(timeout: 5) || app.staticTexts["KLIPY library is being connected"].exists)
    XCTAssertFalse(app.buttons["klipyAttach"].exists)
    app.buttons["klipyCancel"].tap()
    let editor = app.textViews["postText"]
    XCTAssertTrue(editor.waitForExistence(timeout: 3)); XCTAssertEqual(editor.value as? String, "Keep this draft")
    app.pickPostTopic()
    XCTAssertTrue(app.buttons["publishPost"].isEnabled)
  }
  func testOfflineMasonryKeepsImageAspectsAndPreviewDoesNotAttachOrRecordRecent() {
    let app = launch(realisticMedia: true)
    let portrait = app.buttons["klipyItem-fixture-portrait"]
    let landscape = app.buttons["klipyItem-fixture-landscape"]
    XCTAssertTrue(portrait.waitForExistence(timeout: 5)); XCTAssertTrue(landscape.waitForExistence(timeout: 5))
    XCTAssertEqual(portrait.frame.width, landscape.frame.width, accuracy: 2)
    XCTAssertEqual(portrait.frame.height / portrait.frame.width, 1.5, accuracy: 0.04)
    XCTAssertEqual(landscape.frame.height / landscape.frame.width, 360.0 / 640.0, accuracy: 0.04)
    XCTAssertFalse(app.staticTexts["Campus portrait"].exists, "Grid tiles have images without repeated title rows")
    XCTAssertFalse(app.staticTexts["Study landscape"].exists)
    XCTAssertFalse(app.buttons["klipyAttach"].exists)
    portrait.tap(); waitForAttach(app)
    XCTAssertTrue(app.staticTexts["Campus portrait"].exists)
    let back = app.buttons["klipyBack"]
    XCTAssertLessThan(back.frame.midY, app.frame.minY + app.frame.height * 0.22,
      "The preview title and back control belong at the sheet top, without a large blank header.")
    app.buttons["klipyBack"].tap()
    XCTAssertTrue(portrait.waitForExistence(timeout: 3))
    app.buttons["klipyTab-recents"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["klipyEmpty"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["klipyClearRecents"].exists, "Previewing alone never records an attachment choice")
    app.buttons["klipyCancel"].tap()
    let editor = app.textViews["postText"]
    XCTAssertTrue(editor.waitForExistence(timeout: 3)); XCTAssertEqual(editor.value as? String, "Keep this draft")
    XCTAssertFalse(app.buttons["Remove attachment"].exists)
    app.pickPostTopic()
    XCTAssertTrue(app.buttons["publishPost"].isEnabled)
  }
  func testOfflineSearchGIFConfirmationRecentsAndClearPreserveUnsentDraft() {
    let app = launch(realisticMedia: true)
    XCTAssertTrue(app.buttons["klipyItem-fixture-portrait"].waitForExistence(timeout: 5))
    let search = app.textFields["klipySearch"]
    search.tap(); search.typeText("study")
    waitForAbsent(app.buttons["klipyItem-fixture-portrait"])
    XCTAssertTrue(app.buttons["klipyItem-fixture-landscape"].exists)
    app.buttons["klipyTab-gifs"].tap()
    let gif = app.buttons["klipyItem-fixture-gif"]
    XCTAssertTrue(gif.waitForExistence(timeout: 5)); waitForAbsent(app.buttons["klipyItem-fixture-landscape"])
    gif.tap(); waitForAttach(app)
    XCTAssertTrue(app.buttons["klipyAttach"].label.contains("GIF"))
    app.buttons["klipyAttach"].tap()
    let editor = app.textViews["postText"]
    XCTAssertTrue(editor.waitForExistence(timeout: 5)); XCTAssertEqual(editor.value as? String, "Keep this draft")
    XCTAssertEqual(app.staticTexts.matching(identifier: "KLIPY attachment").count, 1)
    XCTAssertTrue(app.buttons["Remove attachment"].exists)
    XCTAssertFalse(app.buttons["Keep this draft"].exists, "Attaching must not publish the draft")
    openPicker(app)
    app.buttons["klipyTab-recents"].tap()
    XCTAssertTrue(gif.waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["klipyItem-fixture-portrait"].exists)
    app.buttons["klipyClearRecents"].tap()
    let confirmation = app.alerts["Clear recent media?"]
    XCTAssertTrue(confirmation.waitForExistence(timeout: 3)); confirmation.buttons["Cancel"].tap()
    XCTAssertTrue(gif.exists)
    app.buttons["klipyClearRecents"].tap(); confirmation.buttons["Clear recents"].tap()
    waitForAbsent(gif)
    XCTAssertTrue(app.descendants(matching: .any)["klipyEmpty"].exists)
    app.buttons["klipyCancel"].tap()
    XCTAssertTrue(editor.waitForExistence(timeout: 3)); XCTAssertEqual(editor.value as? String, "Keep this draft")
    XCTAssertTrue(app.buttons["Remove attachment"].exists, "Clearing recents does not delete the draft’s selected attachment")
  }
}
