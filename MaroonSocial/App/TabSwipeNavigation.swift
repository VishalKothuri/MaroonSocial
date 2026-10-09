import SwiftUI
import UIKit
import WebKit

/// Keeps the system tab bar and each tab's NavigationStack. Adjacent roots move
/// together under the finger; UIKit retains ownership of navigation and bars.
struct TabSwipeNavigation: UIViewRepresentable {
  @Binding var selection: Int
  let count: Int
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeUIView(context: Context) -> ProbeView {
    let probe = ProbeView()
    probe.isUserInteractionEnabled = false
    probe.isAccessibilityElement = false
    probe.attach = { [weak coordinator = context.coordinator] view in coordinator?.attach(from: view) }
    return probe
  }
  func updateUIView(_ probe: ProbeView, context: Context) {
    context.coordinator.updateSelection(selection)
    context.coordinator.count = count
    context.coordinator.reduceMotion = reduceMotion
    context.coordinator.select = { selection = $0 }
    context.coordinator.attach(from: probe)
  }
  static func dismantleUIView(_ probe: ProbeView, coordinator: Coordinator) {
    probe.attach = nil
    coordinator.detach()
  }

  final class ProbeView: UIView {
    var attach: ((UIView) -> Void)?
    override func didMoveToWindow() {
      super.didMoveToWindow(); attach?(self)
      // SwiftUI installs controller containment after attaching its background
      // view. Retry once after that transaction; a zero-size probe may not lay out.
      DispatchQueue.main.async { [weak self] in if let self { self.attach?(self) } }
    }
    override func layoutSubviews() { super.layoutSubviews(); attach?(self) }
  }

  @MainActor final class Coordinator: NSObject, UIGestureRecognizerDelegate, UITabBarControllerDelegate {
    var current = 0
    var count = 5
    var reduceMotion = false
    var select: ((Int) -> Void)?
    private weak var tabs: UITabBarController?
    private weak var forwardedDelegate: (any UITabBarControllerDelegate)?
    private var interaction: UIPercentDrivenInteractiveTransition?
    private var swipeOrigin: Int?
    private var swipeDestination: Int?
    private var transitionActive = false
    private var transitionGeneration = 0
    private lazy var pan: UIPanGestureRecognizer = {
      let gesture = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
      gesture.maximumNumberOfTouches = 1
      gesture.cancelsTouchesInView = true
      gesture.delaysTouchesBegan = false
      gesture.delaysTouchesEnded = false
      gesture.delegate = self
      return gesture
    }()

    func attach(from probe: UIView) {
      guard let root = probe.window?.rootViewController,
        let candidate = findTabs(in: root), candidate.view.window === probe.window else { return }
      if candidate !== tabs {
        detach()
        tabs = candidate
        candidate.view.addGestureRecognizer(pan)
      }
      // SwiftUI's delegate owns its selection binding and system tab behavior.
      // Keep forwarding every callback we do not supply, including the iOS 18
      // UITab callbacks, and reattach if SwiftUI refreshes its delegate.
      if candidate.delegate !== self {
        forwardedDelegate = candidate.delegate
        candidate.delegate = self
      }
    }
    func detach() {
      transitionGeneration += 1
      interaction?.cancel()
      interaction = nil
      pan.view?.removeGestureRecognizer(pan)
      if tabs?.delegate === self { tabs?.delegate = forwardedDelegate }
      forwardedDelegate = nil
      tabs = nil
      swipeOrigin = nil; swipeDestination = nil; transitionActive = false
    }
    func updateSelection(_ selection: Int) {
      // A SwiftUI update during an interactive transition must not change the
      // gesture's origin. Its committed selection is published on completion.
      if !transitionActive { current = selection }
    }
    override func responds(to selector: Selector!) -> Bool {
      super.responds(to: selector) || forwardedDelegate?.responds(to: selector) == true
    }
    override func forwardingTarget(for selector: Selector!) -> Any? {
      if forwardedDelegate?.responds(to: selector) == true { return forwardedDelegate }
      return super.forwardingTarget(for: selector)
    }
    private func controllerCount(in tabs: UITabBarController) -> Int {
      tabs.tabs.isEmpty ? tabs.viewControllers?.count ?? 0 : tabs.tabs.count
    }
    private func controller(at index: Int, in tabs: UITabBarController) -> UIViewController? {
      if !tabs.tabs.isEmpty { return tabs.tabs.indices.contains(index) ? tabs.tabs[index].viewController : nil }
      guard let controllers = tabs.viewControllers, controllers.indices.contains(index) else { return nil }
      return controllers[index]
    }
    private func index(of controller: UIViewController, in tabs: UITabBarController) -> Int? {
      if !tabs.tabs.isEmpty { return tabs.tabs.firstIndex { $0.viewController === controller } }
      return tabs.viewControllers?.firstIndex { $0 === controller }
    }
    private func selectNative(_ index: Int, in tabs: UITabBarController) {
      if !tabs.tabs.isEmpty, tabs.tabs.indices.contains(index) { tabs.selectedTab = tabs.tabs[index] }
      else { tabs.selectedIndex = index }
    }
    func tabBarController(_ tabBarController: UITabBarController,
      animationControllerForTransitionFrom fromVC: UIViewController,
      to toVC: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
      guard !reduceMotion, !UIAccessibility.isReduceMotionEnabled,
        let from = index(of: fromVC, in: tabBarController),
        let to = index(of: toVC, in: tabBarController), from != to else { return nil }
      transitionActive = true
      transitionGeneration += 1
      let generation = transitionGeneration
      return RootTabSlideAnimator(direction: to > from ? 1 : -1, interactive: interaction != nil) { [weak self] completed in
        guard let self, self.transitionGeneration == generation else { return }
        let selection = completed ? to : from
        self.interaction = nil
        self.swipeOrigin = nil; self.swipeDestination = nil; self.transitionActive = false
        self.current = selection
        // UIKit normally restores selection when an interactive transition is
        // cancelled. Reconcile explicitly before SwiftUI renders another update.
        if let tabs = self.tabs, (0..<self.controllerCount(in: tabs)).contains(selection) {
          let selected = tabs.selectedTab?.viewController ?? tabs.selectedViewController
          if selected !== self.controller(at: selection, in: tabs) { self.selectNative(selection, in: tabs) }
        }
        self.select?(selection)
      }
    }
    func tabBarController(_ tabBarController: UITabBarController,
      interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning) -> (any UIViewControllerInteractiveTransitioning)? {
      interaction
    }
    private func findTabs(in controller: UIViewController) -> UITabBarController? {
      if let tabs = controller as? UITabBarController { return tabs }
      for child in controller.children { if let found = findTabs(in: child) { return found } }
      return nil
    }
    private func rootIsAvailable() -> Bool {
      guard let tabs else { return false }
      return TabSwipeAvailability.rootIsAvailable(in: tabs, expectedTabs: count)
    }
    private func belongsToHorizontalScrollerOrInput(_ view: UIView?) -> Bool {
      var ancestor = view
      while let node = ancestor, node !== tabs?.view {
        if node is UITabBar || node is UINavigationBar || node is WKWebView || node is UITextInput ||
          node is UISlider || node is UISwitch || node is UISegmentedControl { return true }
        if let scroll = node as? UIScrollView, scroll.isScrollEnabled,
          scroll.alwaysBounceHorizontal || scroll.contentSize.width + scroll.adjustedContentInset.left + scroll.adjustedContentInset.right > scroll.bounds.width + 2 { return true }
        ancestor = node.superview
      }
      return false
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
      guard current != 0, rootIsAvailable(), let view = tabs?.view else { return false }
      let point = touch.location(in: view)
      // Leave system edge navigation and both native bars entirely alone.
      guard point.x > max(24, view.safeAreaInsets.left + 20),
        point.x < view.bounds.width - max(24, view.safeAreaInsets.right + 20),
        !belongsToHorizontalScrollerOrInput(touch.view) else { return false }
      if let bar = tabs?.tabBar, TabSwipeAvailability.containsVisibleBar(point, in: view, bar: bar) { return false }
      return true
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
      guard current != 0, !transitionActive, rootIsAvailable(), let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
      let velocity = pan.velocity(in: pan.view)
      // Any decisive horizontal swipe begins, including one past the first or last
      // tab: beginning cancels the touch underneath, so a bounded swipe over a row
      // or link never turns into a tap. `panned` ignores out-of-range destinations.
      return abs(velocity.x) > 80 && abs(velocity.x) > abs(velocity.y) * 1.6
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
      // A vertical ScrollView remains free to track its own pan. Its horizontal
      // children were excluded at touch-down, as were text and game surfaces.
      other is UIPanGestureRecognizer && other.view is UIScrollView
    }
    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
      guard let tabs else { return }
      let offset = gesture.translation(in: tabs.view), speed = gesture.velocity(in: tabs.view)
      switch gesture.state {
      case .began:
        guard !transitionActive, rootIsAvailable() else { return }
        let origin = current, destination = origin + (speed.x < 0 ? 1 : -1)
        guard (0..<controllerCount(in: tabs)).contains(destination) else { return }
        swipeOrigin = origin; swipeDestination = destination
        if reduceMotion || UIAccessibility.isReduceMotionEnabled { return }
        let driver = UIPercentDrivenInteractiveTransition()
        driver.completionCurve = .easeOut
        interaction = driver
        selectNative(destination, in: tabs)
      case .changed:
        guard let origin = swipeOrigin, let destination = swipeDestination else { return }
        interaction?.update(TabSwipeIntent.progress(from: origin, to: destination, width: tabs.view.bounds.width, translation: offset.x))
      case .ended, .cancelled, .failed:
        guard let origin = swipeOrigin, let destination = swipeDestination else { return }
        let complete = gesture.state == .ended && TabSwipeIntent.destination(current: origin, count: count,
          width: tabs.view.bounds.width, translation: offset, velocity: speed) == destination
        if let interaction {
          if complete { interaction.finish() } else { interaction.cancel() }
        } else {
          swipeOrigin = nil; swipeDestination = nil
          if complete { selectNative(destination, in: tabs); current = destination; select?(destination) }
        }
      default: break
      }
    }
  }
}

/// Only the two page views move. The native tab bar is outside this container,
/// so its independent vertical slide never gets captured in a page crossfade.
@MainActor final class RootTabSlideAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  private let direction: CGFloat
  private let interactive: Bool
  private let completion: (Bool) -> Void
  private var animator: UIViewPropertyAnimator?

  init(direction: CGFloat, interactive: Bool, completion: @escaping (Bool) -> Void) {
    self.direction = direction; self.interactive = interactive; self.completion = completion
  }
  func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval { 0.34 }
  func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
    interruptibleAnimator(using: transitionContext).startAnimation()
  }
  func interruptibleAnimator(using context: any UIViewControllerContextTransitioning) -> any UIViewImplicitlyAnimating {
    if let animator { return animator }
    guard let from = context.view(forKey: .from), let to = context.view(forKey: .to),
      let destination = context.viewController(forKey: .to) else {
      let fallback = UIViewPropertyAnimator(duration: 0, curve: .linear)
      fallback.addCompletion { [completion] _ in context.completeTransition(false); completion(false) }
      animator = fallback
      return fallback
    }
    let container = context.containerView
    let finalFrame = context.finalFrame(for: destination)
    to.frame = finalFrame.isEmpty ? container.bounds : finalFrame
    // View transforms preserve safe-area geometry while the screens slide.
    // Moving frames instead can make SwiftUI relayout a page under the finger.
    let distance = container.bounds.width * direction
    to.transform = CGAffineTransform(translationX: distance, y: 0)
    container.addSubview(to)
    to.layoutIfNeeded()
    let animation = UIViewPropertyAnimator(duration: transitionDuration(using: context), curve: interactive ? .linear : .easeInOut) {
      from.transform = CGAffineTransform(translationX: -distance, y: 0)
      to.transform = .identity
    }
    animation.addCompletion { [weak self, completion] _ in
      let completed = !context.transitionWasCancelled
      from.transform = .identity; to.transform = .identity
      if !completed { to.removeFromSuperview() }
      context.completeTransition(completed)
      self?.animator = nil
      completion(completed)
    }
    animator = animation
    return animation
  }
}

/// Availability follows the actual navigation/presentation state. A feed may
/// temporarily hide both native bars without ceasing to be a root tab.
@MainActor enum TabSwipeAvailability {
  static func rootIsAvailable(in tabs: UITabBarController, expectedTabs: Int) -> Bool {
    guard let selected = tabs.selectedTab?.viewController ?? tabs.selectedViewController,
      (tabs.tabs.isEmpty ? tabs.viewControllers?.count : tabs.tabs.count) == expectedTabs,
      !hasPushedScreen(selected), !hasPresentedScreen(selected) else { return false }
    var controller: UIViewController? = tabs
    while let current = controller {
      if current.presentedViewController != nil { return false }
      controller = current.parent
    }
    return !hasFocusedInput(tabs.view.window ?? tabs.view)
  }
  static func containsVisibleBar(_ point: CGPoint, in container: UIView, bar: UIView) -> Bool {
    var ancestor: UIView? = bar
    while let view = ancestor {
      if view.isHidden || view.alpha <= 0.01 { return false }
      if view === container { return bar.bounds.contains(bar.convert(point, from: container)) }
      ancestor = view.superview
    }
    return false
  }
  static func hasPushedScreen(_ controller: UIViewController) -> Bool {
    if let navigation = controller as? UINavigationController {
      if navigation.viewControllers.count > 1 { return true }
      // A tab transition also appears as this navigation controller's
      // transitionCoordinator. Only a transition *within* its own stack is a
      // push/pop; otherwise root chrome can safely restore the native bar.
      if let transition = navigation.transitionCoordinator {
        return [transition.viewController(forKey: .from), transition.viewController(forKey: .to)]
          .compactMap { $0 }.contains { transitioning in navigation.viewControllers.contains { $0 === transitioning } }
      }
      return false
    }
    return controller.children.contains { hasPushedScreen($0) }
  }
  private static func hasPresentedScreen(_ controller: UIViewController) -> Bool {
    controller.presentedViewController != nil || controller.children.contains { hasPresentedScreen($0) }
  }
  static func hasFocusedInput(_ view: UIView) -> Bool {
    if view.isFirstResponder && view is UITextInput { return true }
    return view.subviews.contains { hasFocusedInput($0) }
  }
}

enum TabSwipeIntent {
  static func progress(from origin: Int, to destination: Int, width: CGFloat, translation: CGFloat) -> CGFloat {
    guard width > 0, origin != destination else { return 0 }
    return min(1, max(0, translation * (destination > origin ? -1 : 1) / width))
  }
  static func destination(current: Int, count: Int, width: CGFloat, translation: CGPoint, velocity: CGPoint) -> Int? {
    guard count > 1, (0..<count).contains(current),
      abs(translation.x) > abs(translation.y) * 1.5 else { return nil }
    // A deliberate reverse flick cancels even after enough initial travel.
    // Otherwise a person trying to pull a page back still gets sent forward.
    if translation.x * velocity.x < 0, abs(velocity.x) > 180 { return nil }
    let travelled = abs(translation.x) >= max(64, width * 0.18)
    let flicked = abs(translation.x) >= 32 && abs(velocity.x) > 650 && abs(velocity.x) > abs(velocity.y) * 1.5
    guard travelled || flicked else { return nil }
    let next = current + (translation.x < 0 ? 1 : -1)
    return (0..<count).contains(next) ? next : nil
  }
}

extension View {
  func swipeBetweenRootTabs(selection: Binding<Int>, count: Int) -> some View {
    background(TabSwipeNavigation(selection: selection, count: count).frame(width: 0, height: 0))
  }
}

/// Community owns its horizontal axis: New and Hot are the only two pages.
/// Keeping this recognizer on the feed leaves the composer and header controls
/// outside its touch region and never replaces the vertical scroll delegate.
struct CommunitySortSwipeNavigation: UIViewRepresentable {
  @Binding var selection: String
  let enabled: Bool
  /// The sorts the swipe moves between, in order.
  var options = ["New", "Hot"]
  /// Names the feed page on screen. A new page is a new scroll view, so a change re-attaches once
  /// the outgoing page has left (it slides or fades out first).
  var page = ""

  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeUIView(context: Context) -> Probe {
    let probe = Probe(); probe.isUserInteractionEnabled = false; probe.isAccessibilityElement = false
    probe.attach = { [weak coordinator = context.coordinator] in coordinator?.attach(from: $0) }
    return probe
  }
  func updateUIView(_ probe: Probe, context: Context) {
    context.coordinator.selection = selection
    context.coordinator.options = options
    context.coordinator.enabled = enabled
    context.coordinator.select = { selection = $0 }
    context.coordinator.attach(from: probe)
    if context.coordinator.page != page {
      context.coordinator.page = page
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak probe] in if let probe { probe.attach?(probe) } }
    }
  }
  static func dismantleUIView(_ probe: Probe, coordinator: Coordinator) { probe.attach = nil; coordinator.detach() }

  final class Probe: UIView {
    var attach: ((UIView) -> Void)?
    override func didMoveToWindow() {
      super.didMoveToWindow(); attach?(self)
      DispatchQueue.main.async { [weak self] in if let self { self.attach?(self) } }
    }
    override func layoutSubviews() { super.layoutSubviews(); attach?(self) }
  }
  @MainActor final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var selection = "New"
    var options = ["New", "Hot"]
    var enabled = true
    var page = ""
    var select: ((String) -> Void)?
    private weak var scroll: UIScrollView?
    private weak var tabs: UITabBarController?
    private lazy var pan: UIPanGestureRecognizer = {
      let gesture = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
      gesture.maximumNumberOfTouches = 1
      gesture.cancelsTouchesInView = true
      gesture.delaysTouchesBegan = false; gesture.delaysTouchesEnded = false
      gesture.delegate = self
      return gesture
    }()
    func attach(from probe: UIView) {
      guard let window = probe.window else { detach(); return }
      tabs = window.rootViewController.flatMap(Self.findTabs)
      // The probe is the feed's background, so the feed is the scroll view under its center. That
      // skips sideways scrollers elsewhere in the screen (the header's topic strip).
      let center = probe.convert(CGPoint(x: probe.bounds.midX, y: probe.bounds.midY), to: nil)
      var ancestor = probe.superview
      while let view = ancestor {
        if let candidate = Self.findScroll(in: view, containing: center) {
          if candidate !== scroll { pan.view?.removeGestureRecognizer(pan); scroll = candidate; candidate.addGestureRecognizer(pan) }
          return
        }
        ancestor = view.superview
      }
    }
    func detach() { pan.view?.removeGestureRecognizer(pan); scroll = nil; tabs = nil }
    private static func findScroll(in view: UIView, containing point: CGPoint) -> UIScrollView? {
      if let scroll = view as? UIScrollView, scroll.convert(scroll.bounds, to: nil).contains(point) { return scroll }
      for child in view.subviews { if let scroll = findScroll(in: child, containing: point) { return scroll } }
      return nil
    }
    private static func findTabs(in controller: UIViewController) -> UITabBarController? {
      if let tabs = controller as? UITabBarController { return tabs }
      for child in controller.children { if let tabs = findTabs(in: child) { return tabs } }
      return nil
    }
    private var available: Bool {
      guard enabled, let tabs else { return false }
      let onCommunity = tabs.tabs.isEmpty ? tabs.selectedIndex == 0 : tabs.selectedTab === tabs.tabs.first
      return onCommunity && TabSwipeAvailability.rootIsAvailable(in: tabs, expectedTabs: 5)
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
      guard available, let scroll else { return false }
      let point = touch.location(in: scroll)
      // Leave screen-edge system navigation and nested media/input gestures.
      guard point.x > scroll.bounds.minX + 24, point.x < scroll.bounds.maxX - 24 else { return false }
      var node = touch.view
      while let view = node, view !== scroll {
        if view is UITextInput || view is WKWebView || view is UISlider || view is UISwitch || view is UISegmentedControl { return false }
        if let child = view as? UIScrollView, child.isScrollEnabled,
          child.alwaysBounceHorizontal || child.contentSize.width + child.adjustedContentInset.left + child.adjustedContentInset.right > child.bounds.width + 2 { return false }
        node = view.superview
      }
      return true
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
      guard available, let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
      let speed = pan.velocity(in: scroll)
      // Begins for both directions so a swipe past "New" or "Hot" cancels the touch
      // under the finger instead of activating a post or quote card as a tap;
      // `panned` still finds no destination for the bounded direction.
      return abs(speed.x) > 80 && abs(speed.x) > abs(speed.y) * 1.6
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
      other is UIPanGestureRecognizer && other.view is UIScrollView
    }
    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
      guard gesture.state == .ended, available, let scroll,
        let next = CommunitySortSwipeIntent.destination(selection: selection, options: options, width: scroll.bounds.width,
          translation: gesture.translation(in: scroll), velocity: gesture.velocity(in: scroll)) else { return }
      select?(next)
    }
  }
}

enum CommunitySortSwipeIntent {
  /// The sort a sideways swipe moves to: New ↔ Hot, and Hot ↔ Top while the server offers Top.
  static func destination(selection: String, options: [String] = ["New", "Hot"], width: CGFloat, translation: CGPoint, velocity: CGPoint) -> String? {
    guard let current = options.firstIndex(of: selection),
      let destination = TabSwipeIntent.destination(current: current, count: options.count, width: width, translation: translation, velocity: velocity) else { return nil }
    return options[destination]
  }
}
