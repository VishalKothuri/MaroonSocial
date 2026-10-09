import XCTest

/// Interactive back swipes from the left edge over every kind of pushed screen that hides the tab
/// bar. UIKit runs these pops through a percent-driven interactive transition, so the screens'
/// appearance callbacks and the navigation delegate fire while the incoming screen is only partly
/// in the window, and a cancelled swipe re-appears the pushed screen. Each journey mixes completed
/// and cancelled swipes at different speeds and checks the app is still running and the bar ends in
/// the right place every time: hidden on the pushed screen, visible on the screen underneath.
@MainActor final class SwipeBackStabilityUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws {
    if (testRun?.failureCount ?? 0) > 0 {
      let app = XCUIApplication(); print(app.debugDescription)
      let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Failure state"; image.lifetime = .keepAlways; add(image)
    }
  }

  /// One back swipe: how far the finger travels (a fraction of the width), its speed in points per
  /// second, how long it rests before lifting, and the outcome it aims for. A rest lets the finger
  /// slow down before it lifts, so UIKit decides mostly by distance: well short of the middle
  /// cancels, well past it completes.
  private struct BackSwipe {
    var to: CGFloat
    var speed: CGFloat
    var hold: TimeInterval
    var completes: Bool
  }
  private static let swipes: [BackSwipe] = [
    BackSwipe(to: 0.85, speed: 1_500, hold: 0, completes: true),
    BackSwipe(to: 0.30, speed: 400, hold: 0.4, completes: false),
    BackSwipe(to: 0.80, speed: 300, hold: 0.3, completes: true),
    BackSwipe(to: 0.33, speed: 2_500, hold: 0.6, completes: false),
    BackSwipe(to: 0.90, speed: 4_000, hold: 0, completes: true),
    BackSwipe(to: 0.25, speed: 800, hold: 0.3, completes: false),
    BackSwipe(to: 0.33, speed: 250, hold: 0.6, completes: false),
    BackSwipe(to: 0.75, speed: 800, hold: 0.2, completes: true),
    BackSwipe(to: 0.80, speed: 2_000, hold: 0, completes: true),
    BackSwipe(to: 0.30, speed: 1_200, hold: 0.5, completes: false),
    BackSwipe(to: 0.70, speed: 500, hold: 0.25, completes: true),
    BackSwipe(to: 0.85, speed: 3_000, hold: 0, completes: true),
    BackSwipe(to: 0.20, speed: 3_000, hold: 0.5, completes: false),
    BackSwipe(to: 0.90, speed: 600, hold: 0.1, completes: true),
    BackSwipe(to: 0.33, speed: 600, hold: 0.4, completes: false),
    BackSwipe(to: 0.80, speed: 1_000, hold: 0, completes: true),
    BackSwipe(to: 0.78, speed: 350, hold: 0.3, completes: true),
    BackSwipe(to: 0.28, speed: 1_800, hold: 0.5, completes: false),
    BackSwipe(to: 0.88, speed: 2_500, hold: 0, completes: true),
    BackSwipe(to: 0.82, speed: 700, hold: 0.15, completes: true),
  ]

  /// A pushed screen that hides the bar, the screen it returns to, and how to open it again.
  private struct Journey {
    var tab: String
    var pushed: (XCUIApplication) -> XCUIElement
    var underneath: (XCUIApplication) -> XCUIElement
    var open: (XCUIApplication) -> Void
    /// Whether the screen underneath shows the bar (a root, or a pushed screen that keeps it).
    var barUnderneath = true
  }

  private func launch(_ name: String) -> XCUIApplication {
    let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
    let username = app.textFields["username"]
    XCTAssertTrue(username.waitForExistence(timeout: 10)); username.tap(); username.typeText(name)
    app.switches["adultToggle"].tap(); app.buttons["enterPreview"].tap()
    XCTAssertTrue(app.buttons["Create post"].waitForExistence(timeout: 5))
    return app
  }

  private func wait(_ element: XCUIElement, _ format: String, timeout: TimeInterval = 5) -> Bool {
    let check = XCTNSPredicateExpectation(predicate: NSPredicate(format: format), object: element)
    return XCTWaiter.wait(for: [check], timeout: timeout) == .completed
  }

  private func assertRunning(_ app: XCUIApplication, _ context: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(app.state, .runningForeground, "The app stopped running: \(context)", file: file, line: line)
  }

  /// Hidden on a pushed screen: the bar's buttons are gone or cannot be hit.
  private func assertBarHidden(_ app: XCUIApplication, tab: String, _ context: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(wait(app.tabBars.buttons[tab], "exists == false OR hittable == false"), "The tab bar is still visible: \(context)", file: file, line: line)
  }

  /// Visible underneath, and it stays visible: no late hide once the transition has finished.
  private func assertBarVisible(_ app: XCUIApplication, tab: String, _ context: String, file: StaticString = #filePath, line: UInt = #line) {
    let button = app.tabBars.buttons[tab]
    XCTAssertTrue(wait(button, "exists == true AND hittable == true"), "The tab bar did not come back: \(context)", file: file, line: line)
    var seen: [Bool] = []
    for _ in 0..<6 { seen.append(button.exists && button.isHittable); RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1)) }
    XCTAssertTrue(seen.allSatisfy { $0 }, "The tab bar flickered after the pop (\(context)): \(seen)", file: file, line: line)
  }

  /// Starts 2 points from the left edge, mid-screen, and drags right.
  private func backSwipe(_ swipe: BackSwipe, in app: XCUIApplication, y: CGFloat) {
    let frame = app.windows.firstMatch.frame
    let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
    let start = origin.withOffset(CGVector(dx: 2, dy: frame.height * y))
    let end = origin.withOffset(CGVector(dx: frame.width * swipe.to, dy: frame.height * y))
    start.press(forDuration: 0.03, thenDragTo: end, withVelocity: XCUIGestureVelocity(rawValue: swipe.speed), thenHoldForDuration: swipe.hold)
  }

  private func run(_ journey: Journey, in app: XCUIApplication, y: CGFloat = 0.5, file: StaticString = #filePath, line: UInt = #line) {
    journey.open(app)
    XCTAssertTrue(journey.pushed(app).waitForExistence(timeout: 5), "The pushed screen opened", file: file, line: line)
    assertBarHidden(app, tab: journey.tab, "after the first push", file: file, line: line)
    // Let the push finish so the first swipe starts from a resting screen.
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.8))
    var completed = 0, cancelled = 0
    for (index, swipe) in Self.swipes.enumerated() {
      let context = "swipe \(index + 1) of \(Self.swipes.count) (to \(swipe.to), \(Int(swipe.speed)) pt/s, hold \(swipe.hold), aimed to \(swipe.completes ? "complete" : "cancel"))"
      backSwipe(swipe, in: app, y: y)
      assertRunning(app, context, file: file, line: line)
      // UIKit decides the outcome from distance and release speed; each swipe is aimed well to one
      // side of that line, and the bar is checked against what actually happened. Either way the
      // finishing or cancelling animation is over well within a second.
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))
      assertRunning(app, context, file: file, line: line)
      if !journey.pushed(app).exists {
        completed += 1
        XCTAssertTrue(wait(journey.underneath(app), "exists == true AND hittable == true"), "The swipe returned to the screen underneath: \(context)", file: file, line: line)
        if journey.barUnderneath {
          assertBarVisible(app, tab: journey.tab, "completed \(context)", file: file, line: line)
        } else {
          assertBarHidden(app, tab: journey.tab, "completed \(context)", file: file, line: line)
          RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.4))
          assertBarHidden(app, tab: journey.tab, "settled after completed \(context)", file: file, line: line)
        }
        assertRunning(app, context, file: file, line: line)
        journey.open(app)
        XCTAssertTrue(journey.pushed(app).waitForExistence(timeout: 5), "The pushed screen opened again: \(context)", file: file, line: line)
        assertBarHidden(app, tab: journey.tab, "re-pushed after \(context)", file: file, line: line)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.8))
      } else {
        cancelled += 1
        assertBarHidden(app, tab: journey.tab, "cancelled \(context)", file: file, line: line)
        // A late bar change after the cancel would show up here.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.4))
        assertBarHidden(app, tab: journey.tab, "settled after cancelled \(context)", file: file, line: line)
        XCTAssertFalse(journey.underneath(app).isHittable, "A cancelled swipe does not reveal the screen underneath: \(context)", file: file, line: line)
      }
      assertRunning(app, context, file: file, line: line)
    }
    print("Swipe-back outcomes: \(completed) completed, \(cancelled) cancelled")
    XCTAssertGreaterThanOrEqual(completed, 8, "Aimed completions complete (\(completed) completed, \(cancelled) cancelled)", file: file, line: line)
    // Fast cancels sometimes complete: UIKit reads the release speed as well as the distance.
    XCTAssertGreaterThanOrEqual(cancelled, 3, "Aimed cancellations cancel (\(completed) completed, \(cancelled) cancelled)", file: file, line: line)
  }

  func testInteractiveBackSwipesFromAPostThread() {
    let app = launch("swipe_thread")
    // The newest seeded post sits at the top of the feed, so no scroll (which can collapse the
    // bars) is needed to reach it.
    let post: (XCUIApplication) -> XCUIElement = { $0.buttons["Someone said it better than I could."] }
    XCTAssertTrue(post(app).waitForExistence(timeout: 5))
    XCTAssertTrue(post(app).isHittable, "The newest seeded post is on screen")
    XCTAssertTrue(wait(app.tabBars.buttons["Community"], "hittable == true"), "The feed starts with its bar")
    let journey = Journey(
      tab: "Community",
      pushed: { $0.descendants(matching: .any)["threadOriginalPost"].firstMatch },
      underneath: { $0.buttons["Create post"] },
      open: { app in
        XCTAssertTrue(post(app).waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3)); post(app).tap()
      })
    run(journey, in: app)
  }

  func testInteractiveBackSwipesFromAPlanOpenedInExplore() {
    let app = launch("swipe_plan")
    app.tabBars.buttons["Explore"].tap()
    let hangouts = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Hangouts")).firstMatch
    XCTAssertTrue(hangouts.waitForExistence(timeout: 5)); hangouts.tap()
    let plan: (XCUIApplication) -> XCUIElement = { $0.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Coffee")).firstMatch }
    XCTAssertTrue(plan(app).waitForExistence(timeout: 5))
    // The plan list is itself pushed, but without asking to hide the bar.
    XCTAssertTrue(wait(app.tabBars.buttons["Explore"], "hittable == true"), "The plan list keeps the bar")
    let journey = Journey(
      tab: "Explore",
      pushed: { $0.navigationBars["Plan details"] },
      underneath: plan,
      open: { app in
        XCTAssertTrue(plan(app).waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3)); plan(app).tap()
      })
    run(journey, in: app)
  }

  func testInteractiveBackSwipesFromAChat() {
    let app = launch("swipe_chat")
    app.tabBars.buttons["Inbox"].tap()
    let messages = app.buttons["inboxMessages"]
    XCTAssertTrue(messages.waitForExistence(timeout: 5)); messages.tap()
    let row: (XCUIApplication) -> XCUIElement = { $0.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Thanks for the study room tip!")).firstMatch }
    XCTAssertTrue(row(app).waitForExistence(timeout: 5))
    let journey = Journey(
      tab: "Inbox",
      pushed: { $0.textFields["messageText"] },
      underneath: row,
      open: { app in
        XCTAssertTrue(row(app).waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3)); row(app).tap()
      })
    // Above the message composer and below the pinned origin tag.
    run(journey, in: app, y: 0.45)
  }

  /// The reported crash: the screen a back swipe reveals hides the bar too, so its own appearance
  /// callback fires while UIKit adds it to the window at the start of the interactive pop. Here a
  /// plan's group chat is swiped back to the plan; the bar stays hidden on both.
  func testInteractiveBackSwipesFromAChatOpenedFromAPlan() {
    let app = launch("swipe_nested")
    app.tabBars.buttons["Explore"].tap()
    let hangouts = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Hangouts")).firstMatch
    XCTAssertTrue(hangouts.waitForExistence(timeout: 5)); hangouts.tap()
    let plan = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Coffee")).firstMatch
    XCTAssertTrue(plan.waitForExistence(timeout: 5)); plan.tap()
    XCTAssertTrue(app.navigationBars["Plan details"].waitForExistence(timeout: 5))
    let join = app.buttons["joinActivity"]
    XCTAssertTrue(join.waitForExistence(timeout: 5))
    for _ in 0..<5 where !join.isHittable { app.swipeUp() }
    join.tap()
    let chat: (XCUIApplication) -> XCUIElement = { $0.buttons["Open group chat"] }
    XCTAssertTrue(chat(app).waitForExistence(timeout: 5))
    for _ in 0..<5 where !chat(app).isHittable { app.swipeUp() }
    XCTAssertTrue(chat(app).isHittable, "The plan offers its group chat")
    assertBarHidden(app, tab: "Explore", "on the plan")
    let journey = Journey(
      tab: "Explore",
      pushed: { $0.descendants(matching: .any)["messageText"].firstMatch },
      underneath: chat,
      open: { app in
        XCTAssertTrue(chat(app).waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3)); chat(app).tap()
      },
      barUnderneath: false)
    run(journey, in: app, y: 0.45)
  }
}
