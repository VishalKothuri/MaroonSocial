import XCTest
import UIKit
@testable import MaroonSocial

final class TabSwipeNavigationTests: XCTestCase {
  private func target(_ current: Int = 2, x: CGFloat, y: CGFloat = 0, vx: CGFloat = 0, vy: CGFloat = 0, width: CGFloat = 402) -> Int? {
    TabSwipeIntent.destination(current: current, count: 5, width: width, translation: CGPoint(x: x, y: y), velocity: CGPoint(x: vx, y: vy))
  }
  func testDeliberateHorizontalTravelAndFlicksAdvanceOneTab() {
    XCTAssertEqual(target(x: -120), 3)
    XCTAssertEqual(target(x: 120), 1)
    XCTAssertEqual(target(x: -40, vx: -900), 3)
    XCTAssertEqual(target(x: 40, vx: 900), 1)
  }
  func testVerticalDiagonalAndSmallAccidentalMovesStayPut() {
    XCTAssertNil(target(x: -30, y: -150, vx: -900, vy: -1200))
    XCTAssertNil(target(x: -100, y: 85))
    XCTAssertNil(target(x: -20, vx: -1200))
    XCTAssertNil(target(x: 40))
    XCTAssertNil(target(x: 80, width: 1024))
  }
  func testInteractiveTravelTracksTheFingerAndClampsAtBothEnds() {
    XCTAssertEqual(TabSwipeIntent.progress(from: 1, to: 2, width: 400, translation: -100), 0.25)
    XCTAssertEqual(TabSwipeIntent.progress(from: 2, to: 1, width: 400, translation: 200), 0.5)
    XCTAssertEqual(TabSwipeIntent.progress(from: 1, to: 2, width: 400, translation: 20), 0)
    XCTAssertEqual(TabSwipeIntent.progress(from: 1, to: 2, width: 400, translation: -800), 1)
    XCTAssertEqual(TabSwipeIntent.progress(from: 1, to: 2, width: 0, translation: -100), 0)
    XCTAssertNil(target(x: -160, vx: 450), "Reversing a partial swipe should return to its original screen")
    XCTAssertNil(target(x: 160, vx: -450))
    XCTAssertEqual(target(x: -160, vx: 60), 3, "A small release wobble should not undo a completed gesture")
  }
  func testNavigationNeverWrapsOrAcceptsAnInvalidCurrentTab() {
    XCTAssertNil(target(0, x: 180))
    XCTAssertNil(target(4, x: -180))
    XCTAssertEqual(target(0, x: -180), 1)
    XCTAssertEqual(target(4, x: 180), 3)
    XCTAssertNil(target(-1, x: -180))
    XCTAssertNil(target(5, x: 180))
  }
}

@MainActor final class TabSwipeAvailabilityTests: XCTestCase {
  private func makeTabs() -> (UITabBarController, UINavigationController) {
    let tabs = UITabBarController()
    let navigation = UINavigationController(rootViewController: UIViewController())
    tabs.viewControllers = [navigation, UIViewController(), UIViewController(), UIViewController(), UIViewController()]
    tabs.selectedIndex = 0
    tabs.loadViewIfNeeded()
    return (tabs, navigation)
  }
  func testCollapsingBarsKeepsRootAvailableButCannotBypassPushedScreen() {
    let (tabs, navigation) = makeTabs()
    XCTAssertTrue(TabSwipeAvailability.rootIsAvailable(in: tabs, expectedTabs: 5))
    tabs.tabBar.isHidden = true; navigation.setNavigationBarHidden(true, animated: false)
    XCTAssertTrue(TabSwipeAvailability.rootIsAvailable(in: tabs, expectedTabs: 5))
    navigation.setViewControllers([navigation.viewControllers[0], UIViewController()], animated: false)
    XCTAssertFalse(TabSwipeAvailability.rootIsAvailable(in: tabs, expectedTabs: 5))
    XCTAssertFalse(TabSwipeAvailability.rootIsAvailable(in: tabs, expectedTabs: 4))
  }
  func testOnlyVisibleNativeBarGeometryReservesTheBottomTouchRegion() {
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    let wrapper = UIView(frame: container.bounds); container.addSubview(wrapper)
    let bar = UITabBar(frame: CGRect(x: 0, y: 770, width: 402, height: 70)); wrapper.addSubview(bar)
    let point = CGPoint(x: 200, y: 800)
    XCTAssertTrue(TabSwipeAvailability.containsVisibleBar(point, in: container, bar: bar))
    bar.isHidden = true
    XCTAssertFalse(TabSwipeAvailability.containsVisibleBar(point, in: container, bar: bar), "A collapsed bar's stale frame must not block feed swipes")
    bar.isHidden = false; wrapper.alpha = 0
    XCTAssertFalse(TabSwipeAvailability.containsVisibleBar(point, in: container, bar: bar))
    wrapper.alpha = 1; bar.transform = CGAffineTransform(translationX: 0, y: 120)
    XCTAssertFalse(TabSwipeAvailability.containsVisibleBar(point, in: container, bar: bar))
    bar.removeFromSuperview()
    XCTAssertFalse(TabSwipeAvailability.containsVisibleBar(point, in: container, bar: bar))
  }
  func testCollapsedRootStillRejectsFocusedInput() throws {
    let (tabs, _) = makeTabs()
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let original = scene.windows.first(where: \.isKeyWindow)
    let window = UIWindow(windowScene: scene); window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true; original?.makeKey() }
    tabs.tabBar.isHidden = true
    let field = UITextField(frame: CGRect(x: 20, y: 150, width: 200, height: 44))
    tabs.view.addSubview(field)
    XCTAssertTrue(field.becomeFirstResponder())
    XCTAssertFalse(TabSwipeAvailability.rootIsAvailable(in: tabs, expectedTabs: 5))
    field.resignFirstResponder()
    XCTAssertTrue(TabSwipeAvailability.rootIsAvailable(in: tabs, expectedTabs: 5))
  }
  func testCollapsedRootStillRejectsPresentedModal() async throws {
    let (tabs, navigation) = makeTabs()
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let original = scene.windows.first(where: \.isKeyWindow)
    let window = UIWindow(windowScene: scene); window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true; original?.makeKey() }
    tabs.tabBar.isHidden = true
    await withCheckedContinuation { continuation in
      navigation.present(UIViewController(), animated: false) { continuation.resume() }
    }
    XCTAssertFalse(TabSwipeAvailability.rootIsAvailable(in: tabs, expectedTabs: 5))
    await withCheckedContinuation { continuation in navigation.dismiss(animated: false) { continuation.resume() } }
    XCTAssertTrue(TabSwipeAvailability.rootIsAvailable(in: tabs, expectedTabs: 5))
  }
}

@MainActor final class RootTabSlideAnimatorTests: XCTestCase {
  private final class Transition: NSObject, UIViewControllerContextTransitioning {
    let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 800))
    let source = UIViewController()
    let destination = UIViewController()
    var isAnimated = true
    var isInteractive = true
    var transitionWasCancelled = false
    var presentationStyle = UIModalPresentationStyle.none
    var targetTransform = CGAffineTransform.identity
    var completed: Bool?
    override init() {
      super.init()
      source.view.frame = containerView.bounds
      containerView.addSubview(source.view)
    }
    func updateInteractiveTransition(_ percentComplete: CGFloat) {}
    func finishInteractiveTransition() {}
    func cancelInteractiveTransition() { transitionWasCancelled = true }
    func pauseInteractiveTransition() {}
    func completeTransition(_ didComplete: Bool) { completed = didComplete }
    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? { key == .from ? source : destination }
    func view(forKey key: UITransitionContextViewKey) -> UIView? { key == .from ? source.view : destination.view }
    func initialFrame(for vc: UIViewController) -> CGRect { containerView.bounds }
    func finalFrame(for vc: UIViewController) -> CGRect { containerView.bounds }
  }

  func testAdjacentScreensStartEdgeToEdgeWithoutMovingTheTabBar() throws {
    for direction: CGFloat in [-1, 1] {
      let context = Transition()
      let shell = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
      shell.addSubview(context.containerView)
      let bar = UITabBar(frame: CGRect(x: 0, y: 800, width: 402, height: 74))
      shell.addSubview(bar)
      var completed: Bool?
      let slide = RootTabSlideAnimator(direction: direction, interactive: true) { completed = $0 }
      let animator = try XCTUnwrap(slide.interruptibleAnimator(using: context) as? UIViewPropertyAnimator)
      XCTAssertTrue(slide.interruptibleAnimator(using: context) === animator)
      XCTAssertEqual(context.destination.view.frame.minX, 402 * direction)
      XCTAssertEqual(context.destination.view.bounds.size, context.source.view.bounds.size)
      XCTAssertEqual(context.source.view.frame.minX, 0)
      XCTAssertTrue(bar.transform.isIdentity, "The native bar must keep its separate vertical transition")
      animator.startAnimation(); animator.stopAnimation(false); animator.finishAnimation(at: .end)
      XCTAssertEqual(context.completed, true); XCTAssertEqual(completed, true)
      XCTAssertTrue(context.destination.view.transform.isIdentity)
      XCTAssertTrue(context.source.view.transform.isIdentity)
      XCTAssertTrue(context.destination.view.superview === context.containerView)
      XCTAssertTrue(bar.transform.isIdentity)
    }
  }

  func testCancelledDragRestoresSourceAndRemovesDestination() throws {
    let context = Transition()
    var completed: Bool?
    let slide = RootTabSlideAnimator(direction: 1, interactive: true) { completed = $0 }
    let animator = try XCTUnwrap(slide.interruptibleAnimator(using: context) as? UIViewPropertyAnimator)
    animator.startAnimation(); animator.pauseAnimation(); animator.fractionComplete = 0.3
    context.cancelInteractiveTransition()
    animator.stopAnimation(false); animator.finishAnimation(at: .start)
    XCTAssertEqual(context.completed, false); XCTAssertEqual(completed, false)
    XCTAssertTrue(context.source.view.superview === context.containerView)
    XCTAssertNil(context.destination.view.superview)
    XCTAssertTrue(context.source.view.transform.isIdentity)
    XCTAssertTrue(context.destination.view.transform.isIdentity)
  }
}

@MainActor final class TabSwipeDelegateTests: XCTestCase {
  private final class OriginalDelegate: NSObject, UITabBarControllerDelegate {
    var consulted = false
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
      consulted = true
      return false
    }
  }
  func testSwiftUIDelegateCallbacksAreForwardedAndOwnershipIsRestored() {
    let tabs = UITabBarController(); tabs.viewControllers = [UIViewController(), UIViewController()]
    let original = OriginalDelegate(); tabs.delegate = original
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true }
    let probe = UIView(); tabs.view.addSubview(probe)
    let coordinator = TabSwipeNavigation.Coordinator(); coordinator.attach(from: probe)
    XCTAssertTrue(tabs.delegate === coordinator)
    XCTAssertEqual(tabs.delegate?.tabBarController?(tabs, shouldSelect: tabs.viewControllers![1]), false)
    XCTAssertTrue(original.consulted, "SwiftUI must retain its selection and native tab delegate callbacks")
    coordinator.attach(from: probe)
    coordinator.detach()
    XCTAssertTrue(tabs.delegate === original)
  }
  func testReducedMotionSkipsSlidingTransition() {
    let tabs = UITabBarController(), from = UIViewController(), to = UIViewController()
    tabs.viewControllers = [from, to]
    let coordinator = TabSwipeNavigation.Coordinator(); coordinator.reduceMotion = true
    XCTAssertNil(coordinator.tabBarController(tabs, animationControllerForTransitionFrom: from, to: to))
  }
}

final class CommunitySortSwipeIntentTests: XCTestCase {
  private func destination(_ selected: String, x: CGFloat, y: CGFloat = 0, vx: CGFloat = 0) -> String? {
    CommunitySortSwipeIntent.destination(selection: selected, width: 402,
      translation: CGPoint(x: x, y: y), velocity: CGPoint(x: vx, y: 0))
  }
  func testNewAndHotMoveOnlyTowardTheirNeighborWithoutWrapping() {
    XCTAssertEqual(destination("New", x: -140), "Hot")
    XCTAssertEqual(destination("Hot", x: 140), "New")
    XCTAssertNil(destination("New", x: 140))
    XCTAssertNil(destination("Hot", x: -140))
    XCTAssertNil(destination("Unknown", x: -140))
  }
  func testVerticalShortAndReversedGesturesDoNotChangeFeedOrder() {
    XCTAssertNil(destination("New", x: -20, vx: -900))
    XCTAssertNil(destination("New", x: -140, y: 180))
    XCTAssertNil(destination("New", x: -140, vx: 500))
    XCTAssertEqual(destination("New", x: -40, vx: -900), "Hot")
  }
}

@MainActor final class CommunityRootGestureOwnershipTests: XCTestCase {
  private final class HorizontalPan: UIPanGestureRecognizer {
    override func velocity(in view: UIView?) -> CGPoint { CGPoint(x: -500, y: 0) }
  }
  func testRootRecognizerLeavesCommunityAxisEntirelyToFeedSort() {
    let tabs = UITabBarController()
    tabs.viewControllers = (0..<5).map { _ in UIViewController() }
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = tabs; window.makeKeyAndVisible()
    defer { window.isHidden = true }
    let probe = UIView(); tabs.view.addSubview(probe)
    let coordinator = TabSwipeNavigation.Coordinator(); coordinator.reduceMotion = true; coordinator.attach(from: probe)
    defer { coordinator.detach() }
    coordinator.current = 0
    XCTAssertFalse(coordinator.gestureRecognizerShouldBegin(HorizontalPan()),
      "Even an outward Hot swipe must not fall through to root navigation")
    tabs.selectedIndex = 1; coordinator.current = 1
    XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(HorizontalPan()), "Other root tabs retain horizontal navigation")
  }
}
