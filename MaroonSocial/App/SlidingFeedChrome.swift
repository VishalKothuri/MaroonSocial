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
