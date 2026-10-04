import XCTest
import UIKit
@testable import MaroonSocial

@MainActor final class SlidingFeedChromeTests: XCTestCase {
  private final class RecordingTabs: UITabBarController {
    var requests: [(hidden: Bool, animated: Bool)] = []
    override func setTabBarHidden(_ hidden: Bool, animated: Bool) {
      requests.append((hidden, animated))
      super.setTabBarHidden(hidden, animated: false)
    }
  }

  func testOneNativeCommitPerDirectionAndRestoresOnTabChange() {
    let tabs = RecordingTabs()
    tabs.viewControllers = [UIViewController(), UIViewController()]
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true }
    let probe = UIView(); tabs.view.addSubview(probe)
    let coordinator = SlidingFeedTabBar.Coordinator()
    coordinator.animated = false
    coordinator.hidden = true; coordinator.attach(from: probe)
    XCTAssertEqual(tabs.requests.count, 1)
    XCTAssertTrue(tabs.requests[0].hidden); XCTAssertFalse(tabs.requests[0].animated)
    coordinator.attach(from: probe)
    XCTAssertEqual(tabs.requests.count, 1, "Layout passes must not restart the animation")
    tabs.selectedIndex = 1
    coordinator.attach(from: probe)
    XCTAssertEqual(tabs.requests.count, 2)
    XCTAssertFalse(tabs.requests[1].hidden)
    XCTAssertFalse(tabs.requests[1].animated, "The explicit translation owns motion; the native API only commits visibility")
    coordinator.attach(from: probe); coordinator.restore()
    XCTAssertEqual(tabs.requests.count, 2, "Repeated layout/teardown must not restart the return transition")
  }

  func testDismantlingCollapsedFeedRestoresOnceOnDestinationRoot() {
    let tabs = RecordingTabs(); tabs.viewControllers = [UIViewController(), UIViewController()]
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true }
    let probe = UIView(); tabs.view.addSubview(probe)
    let coordinator = SlidingFeedTabBar.Coordinator()
    coordinator.animated = false
    coordinator.hidden = true; coordinator.attach(from: probe)
    tabs.selectedIndex = 1
    // SwiftUI can dismantle the outgoing probe before a destination layout.
    coordinator.restore(); coordinator.restore()
    XCTAssertEqual(tabs.requests.count, 2)
    XCTAssertFalse(tabs.requests[1].hidden); XCTAssertFalse(tabs.requests[1].animated)
    XCTAssertFalse(tabs.isTabBarHidden)
  }

  func testCachedOutgoingTabRestoresWhenItsProbeLeavesTheWindowWithoutDismantling() {
    let tabs = RecordingTabs(); tabs.viewControllers = [UIViewController(), UIViewController()]
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true }
    let probe = UIView(); tabs.view.addSubview(probe)
    let coordinator = SlidingFeedTabBar.Coordinator()
    coordinator.animated = false; coordinator.hidden = true; coordinator.attach(from: probe)
    XCTAssertTrue(tabs.isTabBarHidden)
    tabs.selectedIndex = 1
    probe.removeFromSuperview()
    // A cached SwiftUI tab's probe receives didMoveToWindow(nil), but no
    // dismantleUIView. The destination must still regain the shared bar.
    coordinator.attach(from: probe)
    XCTAssertFalse(tabs.isTabBarHidden)
    XCTAssertEqual(tabs.requests.count, 2)
    coordinator.attach(from: probe); coordinator.restore()
    XCTAssertEqual(tabs.requests.count, 2)
  }

  func testNativeKeyboardVisibilityRemainsOwnedByUIKitAfterOurBarIsRestored() {
    let tabs = RecordingTabs(); tabs.viewControllers = [UIViewController(), UIViewController()]
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true }
    let probe = UIView(); tabs.view.addSubview(probe)
    let coordinator = SlidingFeedTabBar.Coordinator(); coordinator.animated = false
    coordinator.hidden = true; coordinator.attach(from: probe)
    coordinator.hidden = false; coordinator.attach(from: probe)
    XCTAssertEqual(tabs.requests.count, 2)
    // Once our collapse has been restored, a native visibility change belongs
    // to UIKit (for example keyboard avoidance), even on the Community root.
    tabs.setTabBarHidden(true, animated: false)
    let nativeRequests = tabs.requests.count
    for _ in 0..<5 { coordinator.attach(from: probe) }
    coordinator.restore()
    XCTAssertTrue(tabs.isTabBarHidden)
    XCTAssertEqual(tabs.requests.count, nativeRequests,
      "Root layout must not repeatedly unhide the bar while UIKit is hiding it for editing")
  }

  func testFocusedInputDefersFeedChromeChangesUntilEditingEnds() throws {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let originalWindow = scene.windows.first(where: \.isKeyWindow)
    let tabs = RecordingTabs(); tabs.viewControllers = [UIViewController(), UIViewController()]
    let window = UIWindow(windowScene: scene); window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true; originalWindow?.makeKey() }
    let probe = UIView(); tabs.view.addSubview(probe)
    let coordinator = SlidingFeedTabBar.Coordinator(); coordinator.animated = false
    coordinator.hidden = true; coordinator.attach(from: probe)
    let field = UITextField(frame: CGRect(x: 20, y: 120, width: 200, height: 44)); tabs.view.addSubview(field)
    XCTAssertTrue(field.becomeFirstResponder())
    let requests = tabs.requests.count
    coordinator.hidden = false
    for _ in 0..<5 { coordinator.attach(from: probe) }
    XCTAssertEqual(tabs.requests.count, requests, "Focused input owns keyboard/layout visibility")
    field.resignFirstResponder()
    coordinator.attach(from: probe)
    XCTAssertFalse(tabs.isTabBarHidden)
    XCTAssertEqual(tabs.requests.count, requests + 1, "Restore our old collapse once editing has ended")
  }

  func testReducedMotionRestoresDestinationWithoutAnimation() {
    let tabs = RecordingTabs(); tabs.viewControllers = [UIViewController(), UIViewController()]
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true }
    let probe = UIView(); tabs.view.addSubview(probe)
    let coordinator = SlidingFeedTabBar.Coordinator()
    coordinator.animated = false; coordinator.hidden = true; coordinator.attach(from: probe)
    tabs.selectedIndex = 1; coordinator.restore()
    XCTAssertEqual(tabs.requests.count, 2)
    XCTAssertFalse(tabs.requests[1].hidden); XCTAssertFalse(tabs.requests[1].animated)
  }

  func testDismantlingAfterPushCannotOverrideDestinationToolbarOwnership() {
    let navigation = UINavigationController(rootViewController: UIViewController())
    let tabs = RecordingTabs(); tabs.viewControllers = [navigation]
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true }
    let probe = UIView(); tabs.view.addSubview(probe)
    let coordinator = SlidingFeedTabBar.Coordinator()
    coordinator.animated = false
    coordinator.hidden = true; coordinator.attach(from: probe)
    navigation.pushViewController(UIViewController(), animated: false)
    coordinator.restore()
    XCTAssertEqual(tabs.requests.count, 1, "Teardown must inspect destination navigation even without another attach call")
  }

  func testReducedMotionAndPushedScreenOwnTheirVisibility() {
    let navigation = UINavigationController(rootViewController: UIViewController())
    let tabs = RecordingTabs(); tabs.viewControllers = [navigation]
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true }
    let probe = UIView(); tabs.view.addSubview(probe)
    let coordinator = SlidingFeedTabBar.Coordinator()
    coordinator.animated = false; coordinator.hidden = true; coordinator.attach(from: probe)
    XCTAssertEqual(tabs.requests.count, 1)
    XCTAssertFalse(tabs.requests[0].animated)
    navigation.pushViewController(UIViewController(), animated: false)
    coordinator.hidden = false; coordinator.attach(from: probe); coordinator.restore()
    XCTAssertEqual(tabs.requests.count, 1, "Root chrome must not override a conversation's own hidden tab bar")
  }
}

@MainActor final class NativeFeedTabBarMotionTests: XCTestCase {
  func testReversingAnUnfinishedHideAndDismantlingLeavesAVisibleUsableBar() async throws {
    guard !UIAccessibility.isReduceMotionEnabled else { throw XCTSkip("Reduced Motion intentionally skips the slide") }
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let originalWindow = scene.windows.first(where: \.isKeyWindow)
    let tabs = UITabBarController(); tabs.viewControllers = [UIViewController(), UIViewController()]
    let window = UIWindow(windowScene: scene); window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true; originalWindow?.makeKey() }
    tabs.view.layoutIfNeeded()
    let probe = UIView(); tabs.view.addSubview(probe)
    let coordinator = SlidingFeedTabBar.Coordinator(); coordinator.attach(from: probe)
    try await Task.sleep(for: .milliseconds(100))
    coordinator.hidden = true; coordinator.attach(from: probe)
    try await Task.sleep(for: .milliseconds(100))
    coordinator.hidden = false; coordinator.attach(from: probe)
    for _ in 0..<4 { coordinator.attach(from: probe); try await Task.sleep(for: .milliseconds(20)) }
    try await Task.sleep(for: .milliseconds(400))
    XCTAssertFalse(tabs.isTabBarHidden)
    XCTAssertTrue(tabs.tabBar.transform.isIdentity)
    XCTAssertTrue(tabs.tabBar.isUserInteractionEnabled)
    coordinator.hidden = true; coordinator.attach(from: probe)
    try await Task.sleep(for: .milliseconds(450))
    XCTAssertTrue(tabs.isTabBarHidden)
    tabs.selectedIndex = 1
    coordinator.restore(); coordinator.restore()
    try await Task.sleep(for: .milliseconds(450))
    XCTAssertFalse(tabs.isTabBarHidden)
    XCTAssertTrue(tabs.tabBar.transform.isIdentity)
  }

  func testReturningFromFullscreenPassesThroughPositionsBelowTheRestingBar() async throws {
    guard !UIAccessibility.isReduceMotionEnabled else { throw XCTSkip("Reduced Motion intentionally skips the slide") }
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let originalWindow = scene.windows.first(where: \.isKeyWindow)
    let tabs = UITabBarController()
    tabs.viewControllers = [UINavigationController(rootViewController: UIViewController()), UIViewController()]
    tabs.viewControllers?[0].tabBarItem = UITabBarItem(title: "Community", image: UIImage(systemName: "bubble.left"), tag: 0)
    tabs.viewControllers?[1].tabBarItem = UITabBarItem(title: "Classes", image: UIImage(systemName: "books.vertical"), tag: 1)
    let window = UIWindow(windowScene: scene); window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true; originalWindow?.makeKey() }
    tabs.view.layoutIfNeeded()
    let probe = UIView(); tabs.view.addSubview(probe)
    let coordinator = SlidingFeedTabBar.Coordinator()
    coordinator.attach(from: probe)
    try await Task.sleep(for: .milliseconds(100))
    let restingY = tabs.tabBar.convert(tabs.tabBar.bounds, to: window).minY
    coordinator.hidden = true; coordinator.attach(from: probe)
    try await Task.sleep(for: .milliseconds(500))
    XCTAssertTrue(tabs.isTabBarHidden)
    coordinator.hidden = false; coordinator.attach(from: probe)
    var positions: [CGFloat] = []
    let deadline = ProcessInfo.processInfo.systemUptime + 0.6
    while ProcessInfo.processInfo.systemUptime < deadline {
      if let bar = tabs.tabBar.layer.presentation(), let root = window.layer.presentation() {
        positions.append(bar.convert(bar.bounds, to: root).minY)
      }
      try await Task.sleep(for: .milliseconds(12))
    }
    XCTAssertFalse(tabs.isTabBarHidden)
    XCTAssertEqual(tabs.tabBar.convert(tabs.tabBar.bounds, to: window).minY, restingY, accuracy: 1)
    XCTAssertTrue(positions.contains { $0 > restingY + 2 && $0 < window.bounds.maxY - 2 },
      "The visible bar must travel upward from below its resting position, not snap/fade into place: \(positions)")
  }
}

@MainActor final class PushedTabBarMotionTests: XCTestCase {
  private final class RecordingTabs: UITabBarController {
    var requests: [(hidden: Bool, animated: Bool)] = []
    override func setTabBarHidden(_ hidden: Bool, animated: Bool) {
      requests.append((hidden, animated))
      super.setTabBarHidden(hidden, animated: false)
    }
  }
  /// Drives a pop like a real back swipe: UIKit asks the delegate for the
  /// interaction controller, and the test scrubs or cancels it.
  @MainActor private final class InteractivePopDelegate: NSObject, UINavigationControllerDelegate {
    let interaction = UIPercentDrivenInteractiveTransition()
    func navigationController(_ navigationController: UINavigationController,
      animationControllerFor operation: UINavigationController.Operation,
      from fromVC: UIViewController, to toVC: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
      RootTabSlideAnimator(direction: operation == .pop ? -1 : 1, interactive: true) { _ in }
    }
    func navigationController(_ navigationController: UINavigationController,
      interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning) -> (any UIViewControllerInteractiveTransitioning)? {
      interaction
    }
  }

  /// A pushed screen asking for a hidden bar, hosting the probe the way
  /// SwiftUI does: as a child controller inside the screen's own controller.
  private func pushedScreen() -> UIViewController {
    let screen = UIViewController()
    let probe = SlidingPushedTabBar.Probe()
    NavigationTabBarMotion.shared.register(probe)
    screen.addChild(probe)
    screen.view.addSubview(probe.view)
    probe.didMove(toParent: screen)
    return screen
  }
  private func settle(_ seconds: TimeInterval = 0.05) {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
  }
  private func makeTabbedStack<Tabs: UITabBarController>(_ tabs: Tabs) -> UINavigationController {
    let navigation = UINavigationController(rootViewController: UIViewController())
    tabs.viewControllers = [navigation, UIViewController()]
    tabs.viewControllers?[0].tabBarItem = UITabBarItem(title: "Inbox", image: UIImage(systemName: "tray"), tag: 0)
    tabs.viewControllers?[1].tabBarItem = UITabBarItem(title: "Classes", image: UIImage(systemName: "books.vertical"), tag: 1)
    return navigation
  }

  func testPushedScreenHidesTheBarOnceAndPoppingToTheRootRestoresItOnce() {
    let tabs = RecordingTabs()
    let navigation = makeTabbedStack(tabs)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true }
    tabs.view.layoutIfNeeded(); settle()
    XCTAssertFalse(tabs.isTabBarHidden)
    navigation.pushViewController(pushedScreen(), animated: false)
    navigation.view.layoutIfNeeded(); settle()
    XCTAssertTrue(tabs.isTabBarHidden)
    XCTAssertEqual(tabs.requests.map { $0.hidden }, [true])
    XCTAssertFalse(tabs.requests[0].animated, "Navigation owns the motion; the native API only commits visibility")
    navigation.popViewController(animated: false)
    navigation.view.layoutIfNeeded(); settle()
    XCTAssertFalse(tabs.isTabBarHidden)
    XCTAssertEqual(tabs.requests.map { $0.hidden }, [true, false])
    XCTAssertTrue(tabs.requests.allSatisfy { !$0.animated })
  }

  func testScreensAboveAHidingScreenKeepTheBarHiddenUntilItPops() {
    let tabs = RecordingTabs()
    let navigation = makeTabbedStack(tabs)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true }
    tabs.view.layoutIfNeeded(); settle()
    navigation.pushViewController(pushedScreen(), animated: false)
    navigation.view.layoutIfNeeded(); settle()
    XCTAssertEqual(tabs.requests.map { $0.hidden }, [true])
    // A plain screen above a conversation keeps its hidden bar, like UIKit's
    // hidesBottomBarWhenPushed, instead of flashing the bar back in.
    navigation.pushViewController(UIViewController(), animated: false)
    navigation.view.layoutIfNeeded(); settle()
    XCTAssertTrue(tabs.isTabBarHidden)
    XCTAssertEqual(tabs.requests.count, 1)
    navigation.popViewController(animated: false)
    navigation.view.layoutIfNeeded(); settle()
    XCTAssertTrue(tabs.isTabBarHidden)
    XCTAssertEqual(tabs.requests.count, 1, "Returning to the hiding screen changes nothing")
    navigation.popViewController(animated: false)
    navigation.view.layoutIfNeeded(); settle()
    XCTAssertFalse(tabs.isTabBarHidden)
    XCTAssertEqual(tabs.requests.map { $0.hidden }, [true, false])
  }

  func testAHidingScreenInsideAPresentedStackLeavesTheRootBarAlone() async throws {
    let tabs = RecordingTabs()
    let navigation = makeTabbedStack(tabs)
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let originalWindow = scene.windows.first(where: \.isKeyWindow)
    let window = UIWindow(windowScene: scene); window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true; originalWindow?.makeKey() }
    tabs.view.layoutIfNeeded()
    let presented = UINavigationController(rootViewController: UIViewController())
    await withCheckedContinuation { continuation in
      navigation.present(presented, animated: false) { continuation.resume() }
    }
    // Settings and notification routes open their own stacks in sheets; a
    // post or conversation there must not touch the root tabs' bar.
    presented.pushViewController(pushedScreen(), animated: false)
    presented.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertFalse(tabs.isTabBarHidden)
    XCTAssertTrue(tabs.requests.isEmpty)
    await withCheckedContinuation { continuation in navigation.dismiss(animated: false) { continuation.resume() } }
  }

  func testPoppingSlidesTheBarUpFromBelowWhileTheDepartingScreenKeepsItsLayout() async throws {
    guard !UIAccessibility.isReduceMotionEnabled else { throw XCTSkip("Reduced Motion intentionally skips the slide") }
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let originalWindow = scene.windows.first(where: \.isKeyWindow)
    let tabs = UITabBarController()
    let navigation = makeTabbedStack(tabs)
    let window = UIWindow(windowScene: scene); window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true; originalWindow?.makeKey() }
    tabs.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    let restingY = tabs.tabBar.convert(tabs.tabBar.bounds, to: window).minY
    let rootInset = navigation.viewControllers[0].view.safeAreaInsets.bottom
    let screen = pushedScreen()
    navigation.pushViewController(screen, animated: false)
    navigation.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(150))
    XCTAssertTrue(tabs.isTabBarHidden)
    let hiddenInset = screen.view.safeAreaInsets.bottom
    XCTAssertLessThan(hiddenInset, rootInset, "A pushed screen lays out without the bar")
    navigation.popViewController(animated: true)
    var positions: [CGFloat] = [], departingInsets: [CGFloat] = []
    let deadline = ProcessInfo.processInfo.systemUptime + 0.7
    while ProcessInfo.processInfo.systemUptime < deadline {
      if let bar = tabs.tabBar.layer.presentation(), let root = window.layer.presentation() {
        positions.append(bar.convert(bar.bounds, to: root).minY)
      }
      if screen.view.window != nil { departingInsets.append(screen.view.safeAreaInsets.bottom) }
      try await Task.sleep(for: .milliseconds(12))
    }
    XCTAssertFalse(tabs.isTabBarHidden)
    XCTAssertTrue(tabs.tabBar.transform.isIdentity)
    XCTAssertEqual(tabs.tabBar.convert(tabs.tabBar.bounds, to: window).minY, restingY, accuracy: 1)
    XCTAssertTrue(positions.contains { $0 > restingY + 2 && $0 < window.bounds.maxY - 2 },
      "The returning bar must travel upward from below its resting position, not snap/fade into place: \(positions)")
    XCTAssertFalse(departingInsets.isEmpty)
    XCTAssertTrue(departingInsets.allSatisfy { abs($0 - hiddenInset) < 1 },
      "The departing screen keeps its no-bar layout while sliding away: \(departingInsets)")
    XCTAssertEqual(screen.additionalSafeAreaInsets.bottom, 0, accuracy: 0.5, "Layout compensation settles with the transition")
    XCTAssertEqual(navigation.viewControllers[0].view.safeAreaInsets.bottom, rootInset, accuracy: 1)
  }

  func testPushingSlidesTheBarDownWhileTheArrivingScreenLaysOutWithoutIt() async throws {
    guard !UIAccessibility.isReduceMotionEnabled else { throw XCTSkip("Reduced Motion intentionally skips the slide") }
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let originalWindow = scene.windows.first(where: \.isKeyWindow)
    let tabs = UITabBarController()
    let navigation = makeTabbedStack(tabs)
    let window = UIWindow(windowScene: scene); window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true; originalWindow?.makeKey() }
    tabs.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    let root = navigation.viewControllers[0]
    let restingY = tabs.tabBar.convert(tabs.tabBar.bounds, to: window).minY
    let rootInset = root.view.safeAreaInsets.bottom
    let screen = pushedScreen()
    navigation.pushViewController(screen, animated: true)
    var positions: [CGFloat] = [], arrivingInsets: [CGFloat] = [], rootInsets: [CGFloat] = []
    let deadline = ProcessInfo.processInfo.systemUptime + 0.7
    while ProcessInfo.processInfo.systemUptime < deadline {
      if let bar = tabs.tabBar.layer.presentation(), let window = window.layer.presentation() {
        positions.append(bar.convert(bar.bounds, to: window).minY)
      }
      if screen.view.window != nil, screen.view.bounds.height > 0 { arrivingInsets.append(screen.view.safeAreaInsets.bottom) }
      if root.view.window != nil { rootInsets.append(root.view.safeAreaInsets.bottom) }
      try await Task.sleep(for: .milliseconds(12))
    }
    XCTAssertTrue(tabs.isTabBarHidden)
    XCTAssertTrue(tabs.tabBar.transform.isIdentity)
    XCTAssertTrue(positions.contains { $0 > restingY + 2 && $0 < window.bounds.maxY - 2 },
      "The bar must travel downward past its resting position, not fade in place: \(positions)")
    XCTAssertEqual(screen.additionalSafeAreaInsets.bottom, 0, accuracy: 0.5, "Layout compensation settles with the transition")
    let hiddenInset = screen.view.safeAreaInsets.bottom
    XCTAssertLessThan(hiddenInset, rootInset)
    XCTAssertFalse(arrivingInsets.isEmpty)
    XCTAssertTrue(arrivingInsets.allSatisfy { $0 < rootInset - 1 },
      "The arriving screen is laid out without the bar from its first frame: \(arrivingInsets)")
    XCTAssertTrue(rootInsets.allSatisfy { abs($0 - rootInset) < 1 },
      "The departing root keeps its layout while the bar is still UIKit-visible: \(rootInsets)")
    XCTAssertEqual(hiddenInset, window.safeAreaInsets.bottom, accuracy: 1,
      "Once the bar is gone the pushed screen sits on the device's own bottom inset, not the bar's")
  }

  func testAForeignSafeAreaWriteDuringThePushCannotLeaveTheBarInsetBehind() async throws {
    guard !UIAccessibility.isReduceMotionEnabled else { throw XCTSkip("Reduced Motion intentionally skips the slide") }
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let originalWindow = scene.windows.first(where: \.isKeyWindow)
    let tabs = UITabBarController()
    let navigation = makeTabbedStack(tabs)
    let window = UIWindow(windowScene: scene); window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true; originalWindow?.makeKey() }
    tabs.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    let rootInset = navigation.viewControllers[0].view.safeAreaInsets.bottom
    let screen = pushedScreen()
    navigation.pushViewController(screen, animated: true)
    try await Task.sleep(for: .milliseconds(80))
    // A hosting controller may rewrite its own additionalSafeAreaInsets while it
    // appears. Our transient offset must be undone absolutely, never relatively.
    screen.additionalSafeAreaInsets.bottom = 0
    try await Task.sleep(for: .milliseconds(700))
    XCTAssertTrue(tabs.isTabBarHidden)
    XCTAssertEqual(screen.view.safeAreaInsets.bottom, window.safeAreaInsets.bottom, accuracy: 1,
      "The pushed screen must not keep a bar-height gap after the bar is hidden")
    navigation.popViewController(animated: false)
    navigation.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(150))
    XCTAssertFalse(tabs.isTabBarHidden)
    XCTAssertEqual(navigation.viewControllers[0].view.safeAreaInsets.bottom, rootInset, accuracy: 1)
  }

  func testAScreenAppearingAboveAHiddenBarIsLaidOutOnTheDeviceInset() {
    let tabs = RecordingTabs()
    let navigation = makeTabbedStack(tabs)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true }
    tabs.view.layoutIfNeeded(); settle()
    navigation.pushViewController(pushedScreen(), animated: false)
    navigation.view.layoutIfNeeded(); settle()
    XCTAssertTrue(tabs.isTabBarHidden)
    // A second hiding screen never moves the bar, so its layout is checked when
    // it settles: any leftover bottom inset beyond the device's own is removed.
    let above = pushedScreen()
    above.additionalSafeAreaInsets.bottom = 49
    navigation.pushViewController(above, animated: false)
    navigation.view.layoutIfNeeded(); settle()
    XCTAssertTrue(tabs.isTabBarHidden)
    XCTAssertEqual(tabs.requests.count, 1)
    XCTAssertEqual(above.view.safeAreaInsets.bottom, window.safeAreaInsets.bottom, accuracy: 1)
    navigation.popToRootViewController(animated: false)
    navigation.view.layoutIfNeeded(); settle()
    XCTAssertFalse(tabs.isTabBarHidden)
  }

  func testACancelledInteractivePopRestoresTheHiddenBarAndTheScreenLayout() async throws {
    guard !UIAccessibility.isReduceMotionEnabled else { throw XCTSkip("Reduced Motion intentionally skips the slide") }
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let originalWindow = scene.windows.first(where: \.isKeyWindow)
    let tabs = UITabBarController()
    let navigation = makeTabbedStack(tabs)
    let window = UIWindow(windowScene: scene); window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true; originalWindow?.makeKey() }
    tabs.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    let screen = pushedScreen()
    navigation.pushViewController(screen, animated: false)
    navigation.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(150))
    XCTAssertTrue(tabs.isTabBarHidden)
    let hiddenInset = screen.view.safeAreaInsets.bottom
    let delegate = InteractivePopDelegate()
    navigation.delegate = delegate
    defer { navigation.delegate = nil }
    navigation.popViewController(animated: true)
    try await Task.sleep(for: .milliseconds(120))
    XCTAssertFalse(tabs.isTabBarHidden, "UIKit's real bar is restored before it slides back up under the finger")
    delegate.interaction.update(0.4)
    try await Task.sleep(for: .milliseconds(100))
    delegate.interaction.cancel()
    try await Task.sleep(for: .milliseconds(600))
    XCTAssertEqual(navigation.viewControllers.count, 2)
    XCTAssertTrue(tabs.isTabBarHidden, "A cancelled back swipe re-hides the bar for the screen that stayed")
    XCTAssertTrue(tabs.tabBar.transform.isIdentity)
    XCTAssertEqual(screen.additionalSafeAreaInsets.bottom, 0, accuracy: 0.5)
    XCTAssertEqual(screen.view.safeAreaInsets.bottom, hiddenInset, accuracy: 1)
  }

  func testYieldedFeedCollapseNoLongerRestoresTheBarItself() {
    let tabs = RecordingTabs(); tabs.viewControllers = [UIViewController(), UIViewController()]
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true }
    let probe = UIView(); tabs.view.addSubview(probe)
    let feed = SlidingFeedTabBar.Coordinator(); feed.animated = false
    feed.hidden = true; feed.attach(from: probe)
    XCTAssertEqual(tabs.requests.map { $0.hidden }, [true])
    SlidingFeedTabBar.Coordinator.yieldToNavigation(in: tabs)
    feed.restore()
    XCTAssertEqual(tabs.requests.count, 1, "Navigation owns visibility after a takeover; the feed must not restore it")
  }

  func testNavigationTakeoverStopsAFeedCollapseFromCommittingLater() async throws {
    guard !UIAccessibility.isReduceMotionEnabled else { throw XCTSkip("Reduced Motion intentionally skips the slide") }
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let originalWindow = scene.windows.first(where: \.isKeyWindow)
    let tabs = UITabBarController(); tabs.viewControllers = [UIViewController(), UIViewController()]
    let window = UIWindow(windowScene: scene); window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true; originalWindow?.makeKey() }
    tabs.view.layoutIfNeeded()
    let probe = UIView(); tabs.view.addSubview(probe)
    let feed = SlidingFeedTabBar.Coordinator(); feed.attach(from: probe)
    try await Task.sleep(for: .milliseconds(100))
    feed.hidden = true; feed.attach(from: probe)
    try await Task.sleep(for: .milliseconds(60))
    SlidingFeedTabBar.Coordinator.yieldToNavigation(in: tabs)
    try await Task.sleep(for: .milliseconds(500))
    XCTAssertFalse(tabs.isTabBarHidden, "A yielded collapse must not commit after navigation took the bar")
    XCTAssertTrue(tabs.tabBar.transform.isIdentity)
  }
}
