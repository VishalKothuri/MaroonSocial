import OSLog
import SwiftUI
import UIKit

/// Keep the header mounted while it slides through its clipping edge. Removing
/// a toolbar conditionally makes UIKit and SwiftUI resize the feed in two steps.
struct SlidingFeedHeader<Content: View>: View {
  let collapsed: Bool
  var onHeightChange: (CGFloat) -> Void = { _ in }
  @ViewBuilder var content: Content
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var expandedHeight: CGFloat = 104

  var body: some View {
    VStack(spacing: 0) { content }
      .fixedSize(horizontal: false, vertical: true)
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { expandedHeight = $0; onHeightChange($0) }
      .offset(y: collapsed && !reduceMotion ? -expandedHeight : 0)
      // Let expanded content choose its own height, especially when a search
      // field changes its fitting size as the keyboard becomes first responder.
      .frame(height: collapsed ? 0 : nil, alignment: .top)
      .clipped()
      .allowsHitTesting(!collapsed)
      .accessibilityHidden(collapsed)
      .animation(reduceMotion ? nil : .smooth(duration: 0.34), value: collapsed)
  }
}

/// iOS 26 can fade/snap even when setTabBarHidden is asked to animate. Translate
/// the actual native bar, then let UIKit commit its visibility and safe area.
struct SlidingFeedTabBar: UIViewRepresentable {
  let hidden: Bool
  let animated: Bool
  var onHeightChange: (CGFloat) -> Void = { _ in }

  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeUIView(context: Context) -> Probe {
    let probe = Probe()
    probe.isUserInteractionEnabled = false
    probe.isAccessibilityElement = false
    probe.attach = { [weak coordinator = context.coordinator] in coordinator?.attach(from: $0) }
    return probe
  }
  func updateUIView(_ probe: Probe, context: Context) {
    context.coordinator.hidden = hidden
    context.coordinator.animated = animated
    context.coordinator.onHeightChange = onHeightChange
    context.coordinator.attach(from: probe)
  }
  static func dismantleUIView(_ probe: Probe, coordinator: Coordinator) {
    probe.attach = nil
    coordinator.restore()
  }

  final class Probe: UIView {
    var attach: ((UIView) -> Void)?
    override func didMoveToWindow() {
      super.didMoveToWindow()
      DispatchQueue.main.async { [weak self] in if let self { self.attach?(self) } }
    }
    override func layoutSubviews() { super.layoutSubviews(); attach?(self) }
  }

  @MainActor final class Coordinator {
    var hidden = false
    var animated = true
    var onHeightChange: ((CGFloat) -> Void)?
    private var barHeight: CGFloat = 0
    private weak var tabs: UITabBarController?
    private var appliedHidden = false
    private var animator: UIViewPropertyAnimator?
    private var animationGeneration = 0
    private var updatingNativeLayout = false
    private static let live = NSHashTable<Coordinator>.weakObjects()

    init() { Self.live.add(self) }

    /// A navigation push or pop now owns the shared bar. Stop any feed slide
    /// so its completion cannot commit a stale visibility under that
    /// transition, and let the destination's own state decide a later collapse.
    static func yieldToNavigation(in tabs: UITabBarController) {
      for coordinator in live.allObjects {
        coordinator.relinquishMotion(in: tabs)
        coordinator.appliedHidden = false
      }
    }

    func attach(from probe: UIView) {
      guard !updatingNativeLayout else { return }
      // TabView caches offscreen pages instead of dismantling them. Leaving the
      // window is therefore also a visibility handoff, even if SwiftUI keeps
      // this representable and its coordinator alive for the next visit.
      guard let window = probe.window else { restore(); return }
      guard let root = window.rootViewController, let tabs = Self.findTabs(in: root) else { return }
      self.tabs = tabs
      if TabSwipeAvailability.hasFocusedInput(window) {
        // UIKit owns keyboard avoidance. Do not repeatedly unhide a tab bar it
        // has hidden for editing, or recurse into another SwiftUI layout pass.
        relinquishMotion(in: tabs)
        return
      }
      if !tabs.isTabBarHidden, animator == nil, tabs.tabBar.transform.isIdentity {
        let height = tabs.view.bounds.maxY - tabs.tabBar.convert(tabs.tabBar.bounds, to: tabs.view).minY
        if height > 0, height < 180, abs(height - barHeight) > 1 {
          barHeight = height
          DispatchQueue.main.async { [weak self] in self?.onHeightChange?(height) }
        }
      }
      // A background Community view must never override a pushed screen's
      // toolbar preference or another tab's native navigation state.
      if let selected = tabs.selectedTab?.viewController ?? tabs.selectedViewController, TabSwipeAvailability.hasPushedScreen(selected) {
        relinquishMotion(in: tabs)
        appliedHidden = false
        return
      }
      let onCommunity = tabs.tabs.isEmpty ? tabs.selectedIndex == 0 : tabs.selectedTab === tabs.tabs.first
      let shouldHide = hidden && onCommunity
      guard onCommunity || appliedHidden else { return }
      setHidden(shouldHide, in: tabs)
    }

    func restore() {
      defer { appliedHidden = false; tabs = nil }
      guard let tabs else { return }
      guard let selected = tabs.selectedTab?.viewController ?? tabs.selectedViewController,
        !TabSwipeAvailability.hasPushedScreen(selected) else {
        relinquishMotion(in: tabs)
        return
      }
      if appliedHidden { setHidden(false, in: tabs) }
    }

    private func setHidden(_ shouldHide: Bool, in tabs: UITabBarController) {
      // Layout callbacks during a slide must not restart it. A reverse scroll
      // changes the target and resumes from the live presentation position.
      // Only change visibility when our requested state changes. When we are
      // not hiding the feed, UIKit may independently hide its bar for keyboard
      // avoidance or navigation. A native mismatch is not permission to undo it.
      guard appliedHidden != shouldHide else { return }
      updatingNativeLayout = true
      defer { updatingNativeLayout = false }
      appliedHidden = shouldHide
      let bar = tabs.tabBar
      let currentTransform = bar.layer.presentation()?.affineTransform() ?? bar.transform
      animationGeneration += 1
      let generation = animationGeneration
      animator?.stopAnimation(true); animator = nil
      let animate = animated && !UIAccessibility.isReduceMotionEnabled && bar.window != nil
      guard animate else {
        UIView.performWithoutAnimation {
          bar.transform = .identity
          if tabs.isTabBarHidden != shouldHide { tabs.setTabBarHidden(shouldHide, animated: false) }
          tabs.view.layoutIfNeeded()
        }
        return
      }

      let wasHidden = tabs.isTabBarHidden
      if shouldHide && wasHidden { bar.transform = .identity; return }
      var distance: CGFloat = 0
      UIView.performWithoutAnimation {
        // Restore UIKit's real bar before reveal; only its own view is moved,
        // never a screenshot or the feed/container underneath it.
        bar.transform = .identity
        if wasHidden { tabs.setTabBarHidden(false, animated: false) }
        tabs.view.layoutIfNeeded()
        distance = max(bar.bounds.height, tabs.view.bounds.maxY - bar.convert(bar.bounds, to: tabs.view).minY) + 8
        bar.transform = wasHidden ? CGAffineTransform(translationX: 0, y: distance) : currentTransform
      }
      let motion = UIViewPropertyAnimator(duration: 0.34, curve: .easeInOut) {
        bar.transform = shouldHide ? CGAffineTransform(translationX: 0, y: distance) : .identity
      }
      // Retain this coordinator through dismantling until the native bar has
      // finished coming back. The completion releases the animator cycle.
      motion.addCompletion { [self] _ in
        guard animationGeneration == generation else { return }
        animator = nil
        updatingNativeLayout = true
        defer { updatingNativeLayout = false }
        UIView.performWithoutAnimation {
          if shouldHide, appliedHidden, !TabSwipeAvailability.hasFocusedInput(tabs.view.window ?? tabs.view),
            let selected = tabs.selectedTab?.viewController ?? tabs.selectedViewController,
            !TabSwipeAvailability.hasPushedScreen(selected) {
            tabs.setTabBarHidden(true, animated: false)
          }
          bar.transform = .identity
          tabs.view.layoutIfNeeded()
        }
      }
      animator = motion
      motion.startAnimation()
    }

    private func relinquishMotion(in tabs: UITabBarController) {
      guard animator != nil else { return }
      animationGeneration += 1
      animator?.stopAnimation(true); animator = nil
      // A conversation/game or a keyboard-driven navigation transition owns
      // native visibility now. Never leave our translation on its shared bar.
      UIView.performWithoutAnimation { tabs.tabBar.transform = .identity }
    }

    private static func findTabs(in controller: UIViewController) -> UITabBarController? {
      if let tabs = controller as? UITabBarController { return tabs }
      for child in controller.children { if let tabs = findTabs(in: child) { return tabs } }
      return nil
    }

  }
}

/// Pushed screens used to ask SwiftUI for `.toolbar(.hidden, for: .tabBar)`.
/// On iOS 26 that hands the bar to UIKit, which fades or snaps it instead of
/// sliding. This owns the same native bar for navigation: the real bar
/// translates alongside the push/pop transition, follows an interactive back
/// swipe, and the non-animated visibility API commits once the move ends.
struct SlidingPushedTabBar: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> Probe {
    let probe = Probe()
    NavigationTabBarMotion.shared.register(probe)
    return probe
  }
  func updateUIViewController(_ probe: Probe, context: Context) {}
  static func dismantleUIViewController(_ probe: Probe, coordinator: Void) {
    NavigationTabBarMotion.shared.unregister(probe)
  }

  /// SwiftUI hosts this as a child of the pushed screen's controller, so it
  /// receives that screen's appearance callbacks and transition coordinator.
  final class Probe: UIViewController {
    override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .clear
      view.isUserInteractionEnabled = false
      view.isAccessibilityElement = false
    }
    override func didMove(toParent parent: UIViewController?) {
      super.didMove(toParent: parent)
      if parent != nil { NavigationTabBarMotion.shared.attach(self) }
    }
    override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      NavigationTabBarMotion.shared.attach(self)
      NavigationTabBarMotion.shared.screenWillChange(self)
    }
    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      NavigationTabBarMotion.shared.screenDidChange(self)
    }
    override func viewWillDisappear(_ animated: Bool) {
      super.viewWillDisappear(animated)
      NavigationTabBarMotion.shared.screenWillChange(self)
    }
    override func viewDidDisappear(_ animated: Bool) {
      super.viewDidDisappear(animated)
      NavigationTabBarMotion.shared.screenDidChange(self)
    }
  }
}

extension View {
  /// Use instead of `.toolbar(.hidden, for: .tabBar)` on pushed screens. The
  /// native bar slides down with the push and back up with the pop or back
  /// swipe, and stays hidden for screens pushed above one that asked for
  /// this, like UIKit's `hidesBottomBarWhenPushed`.
  func hidesTabBarWhenPushed() -> some View {
    background(SlidingPushedTabBar().frame(width: 0, height: 0))
  }
}

/// One owner for the shared bar across every tab's navigation stack. Probes
/// only report appearance changes; the stack that will be on screen decides
/// visibility, so the two sides of one transition cannot disagree.
@MainActor final class NavigationTabBarMotion {
  static let shared = NavigationTabBarMotion()
  private let probes = NSHashTable<UIViewController>.weakObjects()
  private struct Compensation {
    weak var controller: UIViewController?
    var applied: CGFloat
    var original: CGFloat
  }
  /// The one transient offset that keeps a screen steady during a transition.
  private var compensation: Compensation?
  /// Standing offsets while the bar is hidden: a pushed screen must never keep
  /// the bar's inset once the bar is gone, whatever UIKit or SwiftUI left there.
  private var corrections: [Compensation] = []
  private var hooks: [ObjectIdentifier: NavigationHook] = [:]
  static let log = Logger(subsystem: "app.maroonsocial.MaroonSocial", category: "TabBarMotion")

  /// The navigation controller's own delegate callbacks are the reliable
  /// moment to slide: they fire with the transition coordinator for every
  /// push and pop, whether or not SwiftUI forwards appearance to the probe.
  func attach(_ probe: UIViewController) {
    var node = probe.parent
    while let current = node {
      if let navigation = current as? UINavigationController {
        let key = ObjectIdentifier(navigation)
        let hook = hooks[key] ?? NavigationHook(owner: self)
        hooks[key] = hook
        hook.install(on: navigation)
        return
      }
      node = current.parent
    }
  }

  /// Delegate-driven entry: `shown` is the controller the stack is moving to.
  func navigationWillShow(_ navigation: UINavigationController, shown: UIViewController, coordinator: (any UIViewControllerTransitionCoordinator)?) {
    guard let tabs = Self.tabBarController(above: navigation), tabs.view.window != nil else { return }
    let hidden = wantsHidden(stack: navigation.viewControllers, top: shown)
    let departing = coordinator?.viewController(forKey: .from)
    Self.log.info("willShow stack=\(navigation.viewControllers.count) hidden=\(hidden) committed=\(tabs.isTabBarHidden) animated=\(coordinator?.isAnimated ?? false)")
    if tabs.isTabBarHidden == hidden { return }
    apply(hidden: hidden, in: tabs, coordinator: coordinator, arriving: shown, departing: departing)
  }
  func navigationDidShow(_ navigation: UINavigationController, shown: UIViewController) {
    guard let tabs = Self.tabBarController(above: navigation), tabs.view.window != nil else { return }
    let hidden = wantsHidden(stack: navigation.viewControllers, top: shown)
    Self.log.info("didShow hidden=\(hidden) committed=\(tabs.isTabBarHidden) inset=\(Double(shown.view.safeAreaInsets.bottom)) device=\(Double(tabs.view.window?.safeAreaInsets.bottom ?? -1))")
    if tabs.isTabBarHidden == hidden { if hidden { correctHiddenLayout(of: shown, in: tabs) }; return }
    apply(hidden: hidden, in: tabs, coordinator: nil, arriving: shown, departing: nil)
  }
  private var generation = 0
  private var applying = false
  private var handledTransition: ObjectIdentifier?

  func register(_ probe: UIViewController) { probes.add(probe) }
  func unregister(_ probe: UIViewController) { probes.remove(probe) }

  /// A pushed screen is about to appear or disappear: decide the destination
  /// state now, while the transition coordinator can still carry the slide.
  func screenWillChange(_ probe: UIViewController) { evaluate(from: probe, settling: false) }
  /// The transition has ended. Reconcile without motion in case the slide
  /// could not be queued, so a pushed screen never keeps a visible bar.
  func screenDidChange(_ probe: UIViewController) { evaluate(from: probe, settling: true) }

  private func evaluate(from probe: UIViewController, settling: Bool) {
    guard !applying, let tabs = Self.tabBarController(above: probe), tabs.view.window != nil else { return }
    let coordinator = settling ? nil : probe.transitionCoordinator
    // A cancelled interactive pop re-appears the departing screen while the
    // original completion is still responsible for restoring the bar.
    if let coordinator, coordinator.isCancelled { return }
    guard let destination = Self.destination(in: tabs, coordinator: coordinator) else { return }
    let hidden = wantsHidden(stack: destination.navigation.viewControllers, top: destination.top)
    Self.log.debug("appearance settling=\(settling) hidden=\(hidden) committed=\(tabs.isTabBarHidden) coordinator=\(coordinator != nil)")
    if tabs.isTabBarHidden == hidden {
      // Nothing to move. A screen that appeared above a hidden bar still needs
      // its layout checked, since only transitions apply the offset below.
      if settling, hidden { correctHiddenLayout(of: destination.top, in: tabs) }
      return
    }
    apply(hidden: hidden, in: tabs, coordinator: coordinator, arriving: destination.top, departing: destination.departing)
  }

  private struct Destination {
    var navigation: UINavigationController
    var top: UIViewController?
    var departing: UIViewController?
  }
  /// The stack that will be visible once the current transition (a push, pop
  /// or root tab change) finishes, plus the screen leaving in its place.
  private static func destination(in tabs: UITabBarController,
    coordinator: (any UIViewControllerTransitionCoordinator)?) -> Destination? {
    var root = tabs.selectedTab?.viewController ?? tabs.selectedViewController
    var departing: UIViewController?
    let to = coordinator?.viewController(forKey: .to), from = coordinator?.viewController(forKey: .from)
    if let to, to.parent === tabs {
      root = to
      if let from, from.parent === tabs { departing = navigation(in: from)?.topViewController }
    }
    guard let root, let navigation = navigation(in: root) else { return nil }
    var top = navigation.topViewController
    if let to, to.parent === navigation { top = to; departing = from }
    return Destination(navigation: navigation, top: top, departing: departing)
  }

  /// UIKit's `hidesBottomBarWhenPushed` rule: hidden while any pushed screen
  /// in the destination stack asks for it, never because of the root alone.
  private func wantsHidden(stack: [UIViewController], top: UIViewController?) -> Bool {
    var entries = Array(stack.dropFirst())
    if let top, top !== stack.first, !entries.contains(where: { $0 === top }) { entries.append(top) }
    guard !entries.isEmpty else { return false }
    return probes.allObjects.contains { probe in
      var node: UIViewController? = probe
      while let current = node {
        if entries.contains(where: { $0 === current }) { return true }
        node = current.parent
      }
      return false
    }
  }

  private func apply(hidden: Bool, in tabs: UITabBarController, coordinator: (any UIViewControllerTransitionCoordinator)?,
    arriving: UIViewController?, departing: UIViewController?) {
    // Only our committed visibility matters here. In-flight slides of either
    // owner are picked up from the bar's live position below.
    guard tabs.isTabBarHidden != hidden else { return }
    if let coordinator, handledTransition == ObjectIdentifier(coordinator) { return }
    applying = true
    defer { applying = false }
    generation += 1
    let generation = self.generation
    handledTransition = coordinator.map { ObjectIdentifier($0) }
    let bar = tabs.tabBar
    let current = bar.layer.presentation()?.affineTransform() ?? bar.transform
    SlidingFeedTabBar.Coordinator.yieldToNavigation(in: tabs)
    settleCompensation()
    let animated = coordinator?.isAnimated == true && !UIAccessibility.isReduceMotionEnabled
    guard animated, let coordinator else {
      Self.log.info("commit without motion hidden=\(hidden)")
      commit(hidden: hidden, in: tabs, entry: arriving); return
    }
    var distance: CGFloat = 0
    if hidden {
      // UIKit keeps its bar until the push lands, so the departing root keeps
      // its layout. The arriving screen is laid out without the bar at once.
      UIView.performWithoutAnimation {
        bar.transform = .identity
        tabs.view.layoutIfNeeded()
        distance = Self.travel(of: bar, in: tabs)
        if let arriving { compensate(arriving, by: -Self.barInset(in: tabs)) }
        bar.transform = current
      }
      let queued = coordinator.animate(alongsideTransition: { _ in
        bar.transform = CGAffineTransform(translationX: 0, y: distance)
      }, completion: { [weak self] context in
        guard let self, self.generation == generation else { return }
        self.handledTransition = nil
        UIView.performWithoutAnimation {
          if !context.isCancelled, !tabs.isTabBarHidden { tabs.setTabBarHidden(true, animated: false) }
          bar.transform = .identity
          self.settleCompensation()
          tabs.view.layoutIfNeeded()
          if !context.isCancelled { self.correctHiddenLayout(of: arriving, in: tabs) }
        }
      })
      Self.log.info("hide alongside queued=\(queued) distance=\(Double(distance))")
      if !queued { commit(hidden: true, in: tabs, entry: arriving) }
    } else {
      // Restore UIKit's real bar first so the destination root regains its
      // inset from the first frame; the departing screen keeps its layout
      // while it slides away, and a cancelled swipe hides the bar again.
      UIView.performWithoutAnimation {
        bar.transform = .identity
        let before = Self.contentInset(in: tabs)
        tabs.setTabBarHidden(false, animated: false)
        tabs.view.layoutIfNeeded()
        let after = Self.contentInset(in: tabs)
        if let departing, after > before { compensate(departing, by: before - after) }
        distance = Self.travel(of: bar, in: tabs)
        bar.transform = CGAffineTransform(translationX: 0, y: distance)
      }
      let queued = coordinator.animate(alongsideTransition: { _ in
        bar.transform = .identity
      }, completion: { [weak self] context in
        guard let self, self.generation == generation else { return }
        self.handledTransition = nil
        UIView.performWithoutAnimation {
          if context.isCancelled, !tabs.isTabBarHidden { tabs.setTabBarHidden(true, animated: false) }
          bar.transform = .identity
          self.settleCompensation()
          if !context.isCancelled { self.releaseCorrections() }
          tabs.view.layoutIfNeeded()
        }
      })
      Self.log.info("show alongside queued=\(queued) distance=\(Double(distance))")
      if !queued { commit(hidden: false, in: tabs, entry: nil) }
    }
  }

  private func commit(hidden: Bool, in tabs: UITabBarController, entry: UIViewController?) {
    UIView.performWithoutAnimation {
      tabs.tabBar.transform = .identity
      if tabs.isTabBarHidden != hidden { tabs.setTabBarHidden(hidden, animated: false) }
      settleCompensation()
      if !hidden { releaseCorrections() }
      tabs.view.layoutIfNeeded()
      if hidden { correctHiddenLayout(of: entry, in: tabs) }
    }
  }

  /// Tells one screen the bar is already gone (or still there) while UIKit's
  /// committed visibility says otherwise, so its layout never jumps mid-slide.
  private func compensate(_ controller: UIViewController, by inset: CGFloat) {
    guard abs(inset) > 0.5 else { return }
    let original = controller.additionalSafeAreaInsets.bottom
    controller.additionalSafeAreaInsets.bottom = original + inset
    compensation = Compensation(controller: controller, applied: original + inset, original: original)
  }
  /// Undo exactly our own write. If something else changed the inset since,
  /// leave that value alone rather than shifting it by our amount.
  private func settleCompensation() {
    guard let pending = compensation else { return }
    compensation = nil
    restore(pending)
  }
  private func restore(_ entry: Compensation) {
    guard let controller = entry.controller, abs(controller.additionalSafeAreaInsets.bottom - entry.applied) < 0.5 else { return }
    controller.additionalSafeAreaInsets.bottom = entry.original
  }
  /// With the bar committed hidden, the on-screen pushed screen must sit on the
  /// device's own bottom inset. Cancel any bar-height inset that remains.
  private func correctHiddenLayout(of entry: UIViewController?, in tabs: UITabBarController) {
    guard let entry, entry.isViewLoaded, let window = entry.view.window, tabs.isTabBarHidden else { return }
    let excess = entry.view.safeAreaInsets.bottom - window.safeAreaInsets.bottom
    guard excess > 1 else { return }
    let original = entry.additionalSafeAreaInsets.bottom
    entry.additionalSafeAreaInsets.bottom = original - excess
    corrections.removeAll { $0.controller == nil || $0.controller === entry }
    corrections.append(Compensation(controller: entry, applied: original - excess, original: original))
    entry.view.layoutIfNeeded()
  }
  private func releaseCorrections() {
    let pending = corrections
    corrections = []
    for entry in pending { restore(entry) }
  }

  private static func contentInset(in tabs: UITabBarController) -> CGFloat {
    let selected = tabs.selectedTab?.viewController ?? tabs.selectedViewController
    return selected?.view.safeAreaInsets.bottom ?? 0
  }
  /// The bottom inset the visible bar adds beyond the device's own. A
  /// destination that has not laid out yet (a root tab change) falls back to
  /// the bar's resting geometry.
  private static func barInset(in tabs: UITabBarController) -> CGFloat {
    let device = tabs.view.window?.safeAreaInsets.bottom ?? 0
    let measured = contentInset(in: tabs) - device
    if measured > 0.5 { return measured }
    let bar = tabs.tabBar
    return max(0, tabs.view.bounds.maxY - bar.convert(bar.bounds, to: tabs.view).minY - device)
  }
  private static func travel(of bar: UIView, in tabs: UITabBarController) -> CGFloat {
    max(bar.bounds.height, tabs.view.bounds.maxY - bar.convert(bar.bounds, to: tabs.view).minY) + 8
  }
  private static func tabBarController(above controller: UIViewController) -> UITabBarController? {
    var node = controller.parent
    while let current = node {
      if let tabs = current as? UITabBarController { return tabs }
      node = current.parent
    }
    return nil
  }
  private static func navigation(in controller: UIViewController) -> UINavigationController? {
    if let navigation = controller as? UINavigationController { return navigation }
    for child in controller.children { if let found = navigation(in: child) { return found } }
    return nil
  }
}


/// Forwards every delegate callback SwiftUI's navigation controller expects,
/// adding only the will/didShow observation the bar slide needs.
@MainActor final class NavigationHook: NSObject, UINavigationControllerDelegate {
  private unowned let owner: NavigationTabBarMotion
  private weak var navigation: UINavigationController?
  private weak var forwardedDelegate: (any UINavigationControllerDelegate)?
  init(owner: NavigationTabBarMotion) { self.owner = owner }
  func install(on navigation: UINavigationController) {
    self.navigation = navigation
    guard navigation.delegate !== self else { return }
    // SwiftUI may refresh its delegate; keep forwarding to whatever it set last.
    forwardedDelegate = navigation.delegate
    navigation.delegate = self
  }
  override func responds(to selector: Selector!) -> Bool {
    super.responds(to: selector) || forwardedDelegate?.responds(to: selector) == true
  }
  override func forwardingTarget(for selector: Selector!) -> Any? {
    if forwardedDelegate?.responds(to: selector) == true { return forwardedDelegate }
    return super.forwardingTarget(for: selector)
  }
  func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
    forwardedDelegate?.navigationController?(navigationController, willShow: viewController, animated: animated)
    owner.navigationWillShow(navigationController, shown: viewController, coordinator: navigationController.transitionCoordinator)
  }
  func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
    forwardedDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
    owner.navigationDidShow(navigationController, shown: viewController)
  }
}

