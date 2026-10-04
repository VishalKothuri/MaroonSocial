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
