import XCTest

/// Opt-in system Photos picker coverage using only the two host-generated assets.
/// Publishing uses the isolated fixture account; authenticated media transport is
/// covered separately by tools/test-private-media.py, not by this UI test.
@MainActor final class SyntheticMediaUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    let environment = ProcessInfo.processInfo.environment
    guard environment["MAROON_SYNTHETIC_MEDIA_UI"] == "1",
          environment["MAROON_SYNTHETIC_MEDIA_ONLY"] == "1" else {
      throw XCTSkip("Import only synthetic-upload.mp4 and synthetic-photo.jpg into a dedicated test simulator, then explicitly enable the synthetic-media UI test.")
    }
  }
  override func tearDownWithError() throws {
    guard (testRun?.failureCount ?? 0) > 0 else { return }
    let app = XCUIApplication()
    print(app.debugDescription)
    capture(app, name: "Synthetic media failure")
  }
  private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10)); username.tap(); username.typeText("media_tester")
    let adult = app.switches["adultToggle"]
    (adult.switches.firstMatch.exists ? adult.switches.firstMatch : adult).tap()
    app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    return app
  }
  private func capture(_ app: XCUIApplication, name: String) {
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = name; image.lifetime = .keepAlways; add(image)
  }
  private func selectSynthetic(_ kind: String, in app: XCUIApplication) throws {
    // Optional exact English accessibility labels allow repeated imports without
    // ever falling back to an arbitrary photo-library item.
    let key = kind == "Video" ? "MAROON_SYNTHETIC_VIDEO_LABEL" : "MAROON_SYNTHETIC_PHOTO_LABEL"
    let exact = ProcessInfo.processInfo.environment[key]
    let predicate = exact.map { NSPredicate(format: "label == %@", $0) }
      ?? NSPredicate(format: "label BEGINSWITH[c] %@", kind + ",")
    let imageMatches = app.images.matching(predicate)
    let cellMatches = app.cells.matching(predicate)
    let buttonMatches = app.buttons.matching(predicate)
    let available = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      imageMatches.count > 0 || cellMatches.count > 0 || buttonMatches.count > 0
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [available], timeout: 10), .completed, "The real Photos picker must expose the imported synthetic \(kind.lowercased()).")
    let matches = imageMatches.count > 0 ? imageMatches : cellMatches.count > 0 ? cellMatches : buttonMatches
    XCTAssertEqual(matches.count, 1, "Refuse ambiguous media selection. Use a synthetic-only simulator or set \(key) to the exact imported asset label.")
    guard matches.count == 1 else { throw SelectionError.ambiguous }
    let asset = matches.element(boundBy: 0)
    if asset.isHittable { asset.tap() }
    else {
      // PHPicker sometimes exposes a visible image without its hit-test trait.
      // Keep the exact, unique synthetic asset and require its visible frame.
      let frame = asset.frame
      XCTAssertGreaterThan(frame.width, 0); XCTAssertGreaterThan(frame.height, 0)
      XCTAssertTrue(app.frame.contains(frame))
      asset.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    // Single-selection PHPicker normally dismisses immediately. Some OS versions
    // present an explicit Add action after selection.
    let add = app.buttons["Add"]
    if add.waitForExistence(timeout: 1), add.isHittable { add.tap() }
  }
  private enum SelectionError: Error { case ambiguous }
  private func waitEnabled(_ element: XCUIElement, timeout: TimeInterval = 20) {
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed)
  }
  func testRealVideoPickerCompressesPreviewsPublishesAndOpensPlayback() throws {
    let app = launch()
    app.buttons["Create post"].tap()
    let caption = "Synthetic video picker and playback check"
    let text = app.textViews["postText"]
    XCTAssertTrue(text.waitForExistence(timeout: 3)); text.tap(); text.typeText(caption)
    let hideKeyboard = app.buttons["hideKeyboard"].firstMatch
    if hideKeyboard.exists { hideKeyboard.tap() }
    app.buttons["Add photo or video"].tap(); app.buttons["Photo or video"].tap()
    try selectSynthetic("Video", in: app)
    XCTAssertTrue(app.staticTexts["Video attached"].waitForExistence(timeout: 30), "This state appears only after the native import and transcode complete.")
    XCTAssertTrue(app.buttons["Remove attachment"].exists)
    waitEnabled(app.buttons["Play video"].firstMatch)
    capture(app, name: "Synthetic video prepared in composer")
    app.pickPostTopic()
    waitEnabled(app.buttons["publishPost"])
    app.buttons["publishPost"].tap()
    let published = app.buttons[caption]
    XCTAssertTrue(published.waitForExistence(timeout: 5)); published.tap()
    XCTAssertTrue(app.navigationBars["Post"].waitForExistence(timeout: 3))
    let play = app.buttons["Play video"].firstMatch
    waitEnabled(play); play.tap()
    let presented = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: play)
    XCTAssertEqual(XCTWaiter.wait(for: [presented], timeout: 3), .completed, "Playback replaces the thumbnail/play overlay with the native player.")
    XCTAssertFalse(app.staticTexts["Video unavailable"].exists)
    capture(app, name: "Published synthetic clip in native player")
    // Backgrounding must pause playback and restore explicit consent to play.
    XCUIDevice.shared.press(.home)
    app.activate()
    waitEnabled(app.buttons["Play video"].firstMatch)
    XCTAssertFalse(app.staticTexts["Video unavailable"].exists)
  }
  func testRealGroupPhotoPickerCompressesAndKeepsPhotoInSavedDraft() throws {
    let app = launch()
    app.tabBars.buttons["Inbox"].tap(); app.buttons["newConversation"].tap(); app.buttons["New group"].tap()
    let choose = app.buttons["Choose group photo"]
    XCTAssertTrue(choose.waitForExistence(timeout: 3)); choose.tap()
    try selectSynthetic("Photo", in: app)
    let remove = app.buttons["Remove"]
    waitEnabled(remove)
    XCTAssertFalse(app.staticTexts["Preparing photo…"].exists)
    capture(app, name: "Synthetic photo prepared as group cover")
    app.buttons["groupCancel"].tap(); app.alerts.buttons["Save and close"].tap()
    XCTAssertTrue(app.buttons["newConversation"].waitForExistence(timeout: 3))
    app.terminate(); app.launchArguments = ["--uitesting-preserve", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]; app.launch()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 10))
    app.tabBars.buttons["Inbox"].tap(); app.buttons["newConversation"].tap(); app.buttons["New group"].tap()
    waitEnabled(app.buttons["Remove"])
    capture(app, name: "Synthetic group cover restored after relaunch")
    app.buttons["Remove"].tap()
    XCTAssertFalse(app.buttons["Remove"].exists)
    app.buttons["groupCancel"].tap()
    XCTAssertTrue(app.buttons["newConversation"].waitForExistence(timeout: 3))
  }
}
