import SwiftUI
import UIKit

/// Retains SwiftUI's native pull distance, async action and cancellation handling.
/// Only the refresh control's artwork changes; scroll delegates remain untouched.
private struct MaroonRefreshModifier: ViewModifier {
  let scope: String
  let onPresentationChanged: ((Bool) -> Void)?
  let onProgressChanged: ((RefreshPresentation) -> Void)?
  let action: @Sendable () async -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var refreshing = false
  @State private var refreshTask: Task<Void, Never>?
  private let gate = RefreshGate.shared
  private func decorated(_ content: Content) -> some View {
    content.refreshable { await refresh() }
      .background(RefreshWordmarkProbe(refreshing: refreshing, reduceMotion: reduceMotion,
        enabled: true,
        onPresentationChanged: onPresentationChanged, onProgressChanged: onProgressChanged))
      .onDisappear { refreshTask?.cancel(); onPresentationChanged?(false); onProgressChanged?(.idle) }
  }
  func body(content: Content) -> some View { decorated(content) }
  @MainActor private func refresh() async {
    if let refreshTask { await refreshTask.value; return }
    let ticket: UUID
    switch gate.begin(scope: scope) {
    case .admitted(let value): ticket = value
    // A blocked pull still follows the user's finger with the white wordmark,
    // but it cannot claim to load or replay a progress sweep without a request.
    case .inFlight, .cooldown: return
    }
    refreshing = true
    // SwiftUI can replace/cancel the native action when the gate and artwork
    // update. Own the work for this presentation's lifetime so those updates
    // cannot clip a fast fill or cancel its request; disappearance still cancels.
    let task = Task { @MainActor in
      let started = ContinuousClock.now
      defer {
        refreshing = false; refreshTask = nil
        gate.finish(scope: scope, ticket: ticket)
      }
      #if DEBUG
      let arguments = ProcessInfo.processInfo.arguments
      if arguments.contains("--uitesting") && arguments.contains("--uitesting-slow-refresh") {
        do { try await Task.sleep(for: .seconds(2)) } catch { return }
      }
      #endif
      guard !Task.isCancelled else { return }
      await action()
      guard !reduceMotion, !Task.isCancelled else { return }
      // The request starts immediately. A fast result gets only enough visual
      // completion time for its progress sweep before the control retracts.
      do {
        try await Task.sleep(until: started.advanced(by: .seconds(LoadingWordmarkTiming.minimumFill)), clock: .continuous)
        refreshing = false
        try await Task.sleep(for: .seconds(LoadingWordmarkTiming.settle))
      } catch { }
    }
    refreshTask = task
    await task.value
  }
}

extension View {
  func maroonRefreshable(scope: String = "social", onPresentationChanged: ((Bool) -> Void)? = nil,
    onProgressChanged: ((RefreshPresentation) -> Void)? = nil, action: @escaping @Sendable () async -> Void) -> some View {
    modifier(MaroonRefreshModifier(scope: scope, onPresentationChanged: onPresentationChanged, onProgressChanged: onProgressChanged, action: action))
  }
}

struct RefreshWordmarkProbe: UIViewRepresentable {
  let refreshing: Bool
  let reduceMotion: Bool
  var enabled = true
  var onPresentationChanged: ((Bool) -> Void)? = nil
  var onProgressChanged: ((RefreshPresentation) -> Void)? = nil
  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeUIView(context: Context) -> ProbeView {
    let view = ProbeView(); view.isUserInteractionEnabled = false; view.isAccessibilityElement = false
    view.attach = { [weak coordinator = context.coordinator] in coordinator?.attach(from: $0) }
    return view
  }
  func updateUIView(_ view: ProbeView, context: Context) {
    context.coordinator.onPresentationChanged = onPresentationChanged
    context.coordinator.onProgressChanged = onProgressChanged
    context.coordinator.update(refreshing: refreshing, reduceMotion: reduceMotion, enabled: enabled)
    context.coordinator.attach(from: view)
  }
  static func dismantleUIView(_ view: ProbeView, coordinator: Coordinator) { view.attach = nil; coordinator.detach() }

  final class ProbeView: UIView {
    var attach: ((UIView) -> Void)?
    override func didMoveToWindow() {
      super.didMoveToWindow(); attach?(self)
      DispatchQueue.main.async { [weak self] in if let self { self.attach?(self) } }
    }
    override func layoutSubviews() { super.layoutSubviews(); attach?(self) }
  }

  @MainActor final class Coordinator: NSObject {
    private weak var control: UIRefreshControl?
    private var originalTint: UIColor?
    private var originalLabel: String?
    private var originalIdentifier: String?
    private var originalAccessible = false
    private var originalEnabled = true
    private var host: UIHostingController<AnyView>?
    private let artworkClip = CAShapeLayer()
    private var refreshing = false
    private var reduceMotion = false
    private var enabled = true
    private weak var scrollView: UIScrollView?
    private var offsetObservation: NSKeyValueObservation?
    private var insetObservation: NSKeyValueObservation?
    private var displayLink: CADisplayLink?
    private var pullLifecycleActive = false
    private var idleFrames = 0
    private var lastScrollSample: CGPoint?
    @MainActor private final class FrameTarget: NSObject {
      weak var coordinator: Coordinator?
      @objc func tick(_ link: CADisplayLink) {
        guard let coordinator else { link.invalidate(); return }
        coordinator.followRetraction()
      }
    }
    private var presentation = RefreshPresentation.idle
    private var presentedToObserver = false
    var onProgressChanged: ((RefreshPresentation) -> Void)?
    var onPresentationChanged: ((Bool) -> Void)?

    func update(refreshing: Bool, reduceMotion: Bool, enabled: Bool = true) {
      self.refreshing = refreshing; self.reduceMotion = reduceMotion; self.enabled = enabled
      host?.rootView = artwork
      control?.tintColor = .clear
      control?.isEnabled = enabled
      control?.isAccessibilityElement = enabled
      control?.accessibilityLabel = refreshing ? "Refreshing" : "Pull to refresh"
      updatePresentation()
    }
    private var artwork: AnyView {
      AnyView(LoadingWordmark(animating: refreshing && !reduceMotion, size: RefreshPresentation.logoSize)
        .preferredColorScheme(.dark))
    }
    private var activelyMovingOrLoading: Bool {
      guard let scrollView else { return refreshing || control?.isRefreshing == true }
      let phase = scrollView.panGestureRecognizer.state
      return scrollView.isDragging || scrollView.isTracking || scrollView.isDecelerating ||
        phase == .began || phase == .changed || refreshing || control?.isRefreshing == true
    }
    private func followFrames() {
      guard displayLink == nil, let scrollView else { return }
      let target = FrameTarget(); target.coordinator = self
      let link = CADisplayLink(target: target, selector: #selector(FrameTarget.tick(_:)))
      lastScrollSample = CGPoint(x: scrollView.contentOffset.y, y: scrollView.adjustedContentInset.top)
      idleFrames = 0; displayLink = link
      link.add(to: .main, forMode: .common)
    }
    private func followRetraction() {
      guard let scrollView else { displayLink?.invalidate(); displayLink = nil; return }
      let sample = CGPoint(x: scrollView.contentOffset.y, y: scrollView.adjustedContentInset.top)
      let moving = lastScrollSample.map { abs($0.x - sample.x) > 0.25 || abs($0.y - sample.y) > 0.25 } ?? true
      lastScrollSample = sample
      if activelyMovingOrLoading || moving { idleFrames = 0 }
      else { idleFrames += 1 }
      // UIKit can finish with a small negative offset. Once bounce/retraction
      // has actually stopped, that residual must not keep a logo sliver alive.
      if idleFrames >= 3 || (!activelyMovingOrLoading && sample.x + sample.y >= 0) {
        pullLifecycleActive = false
        displayLink?.invalidate(); displayLink = nil
      }
      updatePresentation()
    }
    @objc private func pullGestureChanged(_ gesture: UIPanGestureRecognizer) {
      if gesture.state == .began || gesture.state == .changed {
        pullLifecycleActive = true
        updatePresentation()
      }
      // End is followed by UIKit deciding whether to decelerate; inspect that
      // on the next frame rather than hiding between touch-up and the bounce.
      followFrames()
    }
    private func updatePresentation() {
      if activelyMovingOrLoading { pullLifecycleActive = true; followFrames() }
      var pull: CGFloat = 0
      if let scrollView, pullLifecycleActive, enabled || refreshing || control?.isRefreshing == true {
        pull = max(0, -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top))
        // Native refresh changes the inset after release. Keep the completed
        // logo visible while that control owns the loading presentation.
        if refreshing || control?.isRefreshing == true { pull = max(pull, RefreshPresentation.logoHeight) }
      }
      if let scrollView, let artwork = host?.view {
        // Reveal bottom-to-top from the very first pull pixel. Once revealed,
        // the logo stays directly below the header instead of traveling down
        // with the refresh control's increasingly distant bottom edge.
        let reveal = min(RefreshPresentation.logoHeight, pull)
        // adjustedContentInset can include the refresh control's own ~62pt
        // reservation. That is pull space, not another header to sit below.
        let topBarInset = max(0, scrollView.safeAreaInsets.top)
        artwork.frame = CGRect(x: scrollView.bounds.midX - RefreshPresentation.logoWidth / 2,
          y: scrollView.bounds.minY + topBarInset + reveal - RefreshPresentation.logoHeight,
          width: RefreshPresentation.logoWidth, height: RefreshPresentation.logoHeight)
        artwork.alpha = reveal > 0 ? 1 : 0
        // UIScrollView clips at its outer edge, not at the safe-area/content
        // edge. A nonzero top inset must not reveal the whole mark behind the
        // navigation/status area on the first few pixels of a pull. Apply the
        // same clipping at the artwork itself.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        artworkClip.frame = CGRect(x: 0, y: 0, width: RefreshPresentation.logoWidth,
          height: RefreshPresentation.logoHeight)
        artworkClip.path = CGPath(rect: CGRect(x: 0, y: RefreshPresentation.logoHeight - reveal,
          width: RefreshPresentation.logoWidth, height: reveal), transform: nil)
        CATransaction.commit()
        scrollView.bringSubviewToFront(artwork)
      }
      let next = RefreshPresentation(pullDistance: (pull * 2).rounded() / 2,
        refreshing: refreshing, dragging: scrollView?.isDragging == true)
      guard next != presentation else { return }
      presentation = next
      DispatchQueue.main.async { [weak self] in
        guard let self, self.presentation == next else { return }
        self.onProgressChanged?(next)
        if self.presentedToObserver != (next.progress > 0) {
          self.presentedToObserver = next.progress > 0
          self.onPresentationChanged?(self.presentedToObserver)
        }
      }
    }
    func attach(from probe: UIView) {
      guard probe.window != nil else { detach(); return }
      var ancestor: UIView? = probe.superview
      while let node = ancestor {
        let candidates = Self.refreshScrolls(in: node)
        if let scroll = candidates.min(by: { Self.distance($0, to: probe) < Self.distance($1, to: probe) }),
          let refresh = scroll.refreshControl {
          attach(to: refresh, scrollView: scroll); return
        }
        ancestor = node.superview
      }
    }
    private static func refreshScrolls(in view: UIView) -> [UIScrollView] {
      if let scroll = view as? UIScrollView, scroll.refreshControl != nil { return [scroll] }
      return view.subviews.flatMap { refreshScrolls(in: $0) }
    }
    private static func distance(_ scroll: UIScrollView, to probe: UIView) -> CGFloat {
      let bounds = scroll.convert(scroll.bounds, to: probe)
      return abs(bounds.midX - probe.bounds.midX) + abs(bounds.midY - probe.bounds.midY)
        + abs(bounds.width - probe.bounds.width) + abs(bounds.height - probe.bounds.height)
    }
    func attach(to refresh: UIRefreshControl, scrollView: UIScrollView? = nil) {
      guard control !== refresh else { updatePresentation(); return }
      detach(); control = refresh; self.scrollView = scrollView
      scrollView?.panGestureRecognizer.addTarget(self, action: #selector(pullGestureChanged(_:)))
      offsetObservation = scrollView?.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
        MainActor.assumeIsolated { self?.updatePresentation() }
      }
      insetObservation = scrollView?.observe(\.contentInset, options: [.new]) { [weak self] _, _ in
        MainActor.assumeIsolated { self?.updatePresentation() }
      }
      originalTint = refresh.tintColor; originalLabel = refresh.accessibilityLabel
      originalIdentifier = refresh.accessibilityIdentifier; originalAccessible = refresh.isAccessibilityElement
      originalEnabled = refresh.isEnabled
      refresh.tintColor = .clear
      refresh.accessibilityIdentifier = "maroonRefreshControl"
      refresh.isAccessibilityElement = enabled; refresh.isEnabled = enabled
      refresh.accessibilityLabel = refreshing ? "Refreshing" : "Pull to refresh"
      let host = UIHostingController(rootView: artwork); self.host = host
      // This is a fixed-size decoration already positioned in scroll/content
      // coordinates. Inheriting window safe areas would move its actual glyphs
      // away from the frame we just assigned, especially during refresh.
      host.safeAreaRegions = []
      host.view.backgroundColor = .clear; host.view.isUserInteractionEnabled = false
      host.view.accessibilityElementsHidden = true
      if let scrollView {
        host.view.translatesAutoresizingMaskIntoConstraints = true
        host.view.layer.mask = artworkClip
        scrollView.addSubview(host.view)
      } else {
        host.view.translatesAutoresizingMaskIntoConstraints = false
        refresh.addSubview(host.view)
        NSLayoutConstraint.activate([
          host.view.centerXAnchor.constraint(equalTo: refresh.centerXAnchor),
          host.view.bottomAnchor.constraint(equalTo: refresh.bottomAnchor),
          host.view.widthAnchor.constraint(equalToConstant: RefreshPresentation.logoWidth),
          host.view.heightAnchor.constraint(equalToConstant: RefreshPresentation.logoHeight)
        ])
      }
      updatePresentation()
    }
    func detach() {
      displayLink?.invalidate(); displayLink = nil
      pullLifecycleActive = false; idleFrames = 0; lastScrollSample = nil
      scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(pullGestureChanged(_:)))
      offsetObservation = nil; insetObservation = nil; scrollView = nil
      let wasPresented = presentedToObserver; presentation = .idle; presentedToObserver = false
      if wasPresented {
        let callback = onPresentationChanged, progress = onProgressChanged
        DispatchQueue.main.async { callback?(false); progress?(.idle) }
      }
      host?.view.layer.mask = nil
      host?.view.removeFromSuperview(); host = nil
      control?.tintColor = originalTint
      control?.accessibilityLabel = originalLabel
      control?.accessibilityIdentifier = originalIdentifier
      control?.isAccessibilityElement = originalAccessible
      control?.isEnabled = originalEnabled
      control = nil
    }
  }
}
