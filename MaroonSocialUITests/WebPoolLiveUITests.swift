import XCTest

/// Real hosted multiplayer through visible iOS controls only. Run the same test
/// concurrently on the two prepared simulators, with runner environment:
/// MAROON_POOL_LIVE=1 and MAROON_POOL_ACCOUNT=qa_meet_oct4 / qa_pool_oct4.
/// First run stage=find; after the coordinator verifies the two QA accounts
/// share the exact game, run stage=play. Anonymous queue UI hides peer names.
/// No fixture launch flags, account reset/creation, network calls or JavaScript.
@MainActor final class WebPoolLiveUITests: XCTestCase {
  private var ranLiveFlow = false
  private var account = ""

  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    guard ranLiveFlow else { return }
    capture(XCUIApplication(), "Final pool state · \(account)")
    if (testRun?.failureCount ?? 0) > 0 { print(XCUIApplication().debugDescription) }
  }

  func testFindOpponentWithoutTakingAShot() throws { try run(stage: "find") }
  func testVerifiedTwoPhoneOwnShotOpponentLockAndReturnTurn() throws { try run(stage: "play") }

  private func run(stage: String) throws {
    let environment = ProcessInfo.processInfo.environment
    guard environment["MAROON_POOL_LIVE"] == "1", environment["MAROON_POOL_LIVE_STAGE"] == stage,
      let configuredAccount = environment["MAROON_POOL_ACCOUNT"],
      ["qa_meet_oct4", "qa_pool_oct4"].contains(configuredAccount) else {
      throw XCTSkip("Requires the two explicitly prepared QA accounts and concurrent simulator runners")
    }
    account = configuredAccount; ranLiveFlow = true
    let app = XCUIApplication(); app.launchArguments = []; app.launch()
    XCTAssertTrue(app.tabBars.buttons["Community"].waitForExistence(timeout: 30), "An existing signed-in account is required")
    app.tabBars.buttons["Community"].tap()
    let profile = app.buttons["Profile and settings"]
    for _ in 0..<3 where !profile.isHittable { app.swipeDown(velocity: .slow) }
    XCTAssertTrue(profile.waitForExistence(timeout: 5)); profile.tap()
    // Check the actual visible identity before entering a live queue. A missing
    // credential stops here; the test must never create or switch an account.
    XCTAssertTrue(app.staticTexts["@\(account)"].waitForExistence(timeout: 5), "This simulator must already use \(account)")
    app.buttons["Close settings"].tap()
    app.tabBars.buttons["Explore"].tap()
    let pool = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "8 Ball")).firstMatch
    for _ in 0..<5 where !pool.isHittable { app.swipeUp(velocity: .slow) }
    XCTAssertTrue(pool.isHittable); pool.tap()
    let web = app.webViews.firstMatch
    XCTAssertTrue(web.waitForExistence(timeout: 30))
    XCTAssertTrue(web.staticTexts["Pool · online"].waitForExistence(timeout: 45), "The native pool-only bridge must initialize the hosted table")

    let find = web.buttons["Find opponent"]
    let resign = web.buttons["Resign"]
    try wait("The table must offer search or restore an existing active match", timeout: 30) {
      find.exists || resign.exists
    }
    if stage == "play" {
      // A coordinator must verify the anonymous pairing before setting play.
      // Never search again here: that could select a different public peer.
      XCTAssertTrue(resign.exists && !find.exists, "The verified QA match must restore before any shot")
    } else if find.exists {
      XCTAssertTrue(find.isEnabled); find.tap()
      capture(app, "Searching · \(account)")
    }
    // Restoring an active match is intentional: reruns preserve both QA
    // accounts and their game instead of resigning or fabricating a fresh rack.
    try wait("Both simulators must reach the same live queue or saved match", timeout: 90) {
      resign.exists && self.settledStatus(in: web)
    }
    let openingPlayer = myTurn(in: web)
    capture(app, openingPlayer ? "Matched · local turn · \(account)" : "Matched · opponent turn · \(account)")
    if !openingPlayer { assertOpponentLocked(in: web) }
    if stage == "find" { return }

    try wait("The peer must finish its real shot before this account can play", timeout: 90) {
      self.myTurn(in: web) && self.cueButton(in: web).isEnabled
    }
    let cue = cueButton(in: web)
    XCTAssertTrue(cue.isHittable)
    if cue.label.localizedCaseInsensitiveContains("place") {
      cue.tap()
      try wait("Placing the cue ball must reveal the shot control", timeout: 10) {
        let current = self.cueButton(in: web)
        return current.exists && current.isEnabled && current.label == "Hit"
      }
    }
    let power = web.sliders["power slider"]
    XCTAssertTrue(power.exists && power.isEnabled)
    // WKWebView range inputs expose no scrubber geometry, so XCUITest cannot
    // synthesize adjust(toNormalizedSliderPosition:). Drag the visible thumb
    // the way a finger does; the read-back value proves the page accepted it.
    let before = try normalizedPower(power)
    let thumb = power.coordinate(withNormalizedOffset: CGVector(dx: min(max(before, 0.06), 0.94), dy: 0.5))
    thumb.press(forDuration: 0.1, thenDragTo: power.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)))
    if (try normalizedPower(power)) > 0.10 { power.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)).tap() }
    XCTAssertLessThanOrEqual(try normalizedPower(power), 0.10, "The visible slider must actually select a gentle shot")
    capture(app, "Ready to shoot · \(account)")
    // A short stable-turn assertion gives the other runner time to observe its
    // disabled controls. It is not a hidden synchronization or backend hook.
    let unexpectedlyLostTurn = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      !self.cueButton(in: web).isEnabled
    }, object: nil)
    unexpectedlyLostTurn.isInverted = true
    XCTAssertEqual(XCTWaiter.wait(for: [unexpectedlyLostTurn], timeout: 2.5), .completed)
    cueButton(in: web).tap()
    try wait("Submitting a shot must immediately lock local controls", timeout: 10) {
      self.cueLocked(in: web)
    }
    capture(app, "Shot submitted or replaying · \(account)")
    try wait("The server must settle the shot and transfer control to the peer", timeout: 90) {
      self.opponentTurn(in: web) && self.cueLocked(in: web)
    }
    assertOpponentLocked(in: web)
    capture(app, "Shot settled · opponent controls only · \(account)")

    if openingPlayer {
      // The responder has one shot; its test ends with controls locked. The
      // opener stays to prove that the peer's committed shot returns control.
      try wait("The peer's committed shot must return local control", timeout: 90) {
        self.myTurn(in: web) && self.cueButton(in: web).isEnabled
      }
      XCTAssertTrue(web.sliders["power slider"].isEnabled)
      capture(app, "Opponent shot received · local turn restored · \(account)")
    }
    // Preserve the unfinished QA match. No resignation, deletion or account
    // cleanup belongs in this UI test; normal view dismissal revokes its scope.
  }

  private func cueButton(in web: XCUIElement) -> XCUIElement {
    web.buttons.matching(NSPredicate(format:
      "label == 'Hit' OR label == 'Take shot' OR (label CONTAINS[c] 'place' AND label CONTAINS[c] 'ball')"
    )).firstMatch
  }
  private func myTurn(in web: XCUIElement) -> Bool {
    web.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Your turn")).firstMatch.exists
  }
  private func opponentTurn(in web: XCUIElement) -> Bool {
    web.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "’s turn.")).firstMatch.exists && !myTurn(in: web)
  }
  private func settledStatus(in web: XCUIElement) -> Bool { myTurn(in: web) || opponentTurn(in: web) }
  private func assertOpponentLocked(in web: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(opponentTurn(in: web), file: file, line: line)
    let cue = cueButton(in: web)
    XCTAssertTrue(!cue.exists || !cue.isEnabled, "The opponent must not be controllable from this account", file: file, line: line)
    XCTAssertTrue(web.sliders["power slider"].exists, file: file, line: line)
    XCTAssertFalse(web.sliders["power slider"].isEnabled, file: file, line: line)
  }
  private func cueLocked(in web: XCUIElement) -> Bool {
    let cue = cueButton(in: web)
    let power = web.sliders["power slider"]
    return (!cue.exists || !cue.isEnabled) && power.exists && !power.isEnabled
  }
  private func normalizedPower(_ slider: XCUIElement) throws -> Double {
    let raw = try XCTUnwrap(slider.value as? String)
    let numeric = try XCTUnwrap(Double(raw.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespacesAndNewlines)))
    return raw.contains("%") ? numeric / 100 : numeric
  }
  private func wait(_ message: String, timeout: TimeInterval, until condition: @escaping () -> Bool) throws {
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
    let result = XCTWaiter.wait(for: [expectation], timeout: min(timeout, 90))
    XCTAssertEqual(result, .completed, message)
    guard result == .completed else { throw LivePoolFailure.timedOut }
  }
  private func capture(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
  }
  private enum LivePoolFailure: Error { case timedOut }
}
