import XCTest
import SwiftUI
import UIKit
@testable import MaroonSocial

@MainActor final class MaroonRefreshTests: XCTestCase {
  func testDecorationIsIdempotentAndRestoresOnDetach() {
    let control = UIRefreshControl()
    control.tintColor = .systemBlue; control.accessibilityLabel = "Original refresh"
    let originalCount = control.subviews.count
    let coordinator = RefreshWordmarkProbe.Coordinator()
    coordinator.update(refreshing: false, reduceMotion: true)
    coordinator.attach(to: control)
    XCTAssertEqual(control.tintColor, .clear)
    XCTAssertEqual(control.accessibilityIdentifier, "maroonRefreshControl")
    XCTAssertEqual(control.accessibilityLabel, "Pull to refresh")
    XCTAssertEqual(control.subviews.count, originalCount + 1)
    coordinator.attach(to: control)
    XCTAssertEqual(control.subviews.count, originalCount + 1, "Layout passes never add duplicate wordmarks")
    coordinator.update(refreshing: true, reduceMotion: true)
    XCTAssertEqual(control.tintColor, .clear)
    XCTAssertEqual(control.accessibilityLabel, "Refreshing")
    coordinator.update(refreshing: false, reduceMotion: true)
    XCTAssertEqual(control.accessibilityLabel, "Pull to refresh")
    coordinator.detach()
    XCTAssertEqual(control.tintColor, .systemBlue)
    XCTAssertEqual(control.accessibilityLabel, "Original refresh")
    XCTAssertNil(control.accessibilityIdentifier)
    XCTAssertEqual(control.subviews.count, originalCount)
  }

  func testNativeAsyncRefreshRunsOnceAndEndsAfterWorkCompletes() async throws {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    let action = HeldRefreshAction()
    let controller = UIHostingController(rootView: ScrollView {
      Text("Existing content").frame(height: 900)
    }.maroonRefreshable(scope: "native-test-" + UUID().uuidString) { await action.run() })
    let window = UIWindow(windowScene: scene); window.rootViewController = controller; window.isHidden = false
    defer { action.complete(); window.isHidden = true }
    let control = try await waitForControl(in: controller.view)
    XCTAssertEqual(control.tintColor, .clear)
    control.beginRefreshing(); control.sendActions(for: .valueChanged)
    for _ in 0..<30 where action.started == 0 { try await Task.sleep(for: .milliseconds(50)) }
    XCTAssertEqual(action.started, 1)
    XCTAssertTrue(control.isRefreshing)
    XCTAssertEqual(control.accessibilityLabel, "Refreshing")
    action.complete()
    for _ in 0..<30 where control.isRefreshing { try await Task.sleep(for: .milliseconds(50)) }
    XCTAssertFalse(control.isRefreshing)
    XCTAssertEqual(control.accessibilityLabel, "Pull to refresh")
  }

  func testPullOffsetPresentationRestoresWithoutReplacingScrollDelegate() async {
    let revealed = expectation(description: "Pull reveals wordmark area")
    let restored = expectation(description: "Release restores header")
    let scroll = InsetRefreshScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
    let delegate = RefreshTestScrollDelegate(); scroll.delegate = delegate
    scroll.simulatesDragging = true
    let control = UIRefreshControl(); scroll.refreshControl = control
    let coordinator = RefreshWordmarkProbe.Coordinator()
    coordinator.onPresentationChanged = { value in value ? revealed.fulfill() : restored.fulfill() }
    coordinator.attach(to: control, scrollView: scroll)
    scroll.contentOffset.y = -35
    await fulfillment(of: [revealed], timeout: 2)
    XCTAssertTrue(scroll.delegate === delegate)
    XCTAssertEqual(control.accessibilityLabel, "Pull to refresh", "Dragging alone does not claim data is loading")
    scroll.contentOffset.y = 0
    await fulfillment(of: [restored], timeout: 2)
    coordinator.detach()
    XCTAssertTrue(scroll.delegate === delegate)
  }

  func testSeveralPullFramesInOneRunLoopStillDeliverVisibilityEdges() async {
    let revealed = expectation(description: "Coalesced pulls reveal")
    let restored = expectation(description: "Release restores")
    let scroll = InsetRefreshScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
    scroll.simulatesDragging = true
    let control = UIRefreshControl(); scroll.refreshControl = control
    let coordinator = RefreshWordmarkProbe.Coordinator()
    coordinator.onPresentationChanged = { $0 ? revealed.fulfill() : restored.fulfill() }
    coordinator.attach(to: control, scrollView: scroll)
    for distance in [8, 16, 24, 35] { scroll.contentOffset.y = -CGFloat(distance) }
    await fulfillment(of: [revealed], timeout: 2)
    scroll.contentOffset.y = 0
    await fulfillment(of: [restored], timeout: 2)
    coordinator.detach()
  }

  func testFastRefreshAndImmediateRepeatKeepFeedbackWithoutDuplicateNetworkWork() async throws {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    var requests = 0
    let controller = UIHostingController(rootView: ScrollView {
      Text("Existing content").frame(height: 900)
    }.maroonRefreshable(scope: "fast-native-" + UUID().uuidString) { requests += 1 })
    let window = UIWindow(windowScene: scene); window.rootViewController = controller; window.isHidden = false
    defer { window.isHidden = true }
    let control = try await waitForControl(in: controller.view)
    let started = ContinuousClock.now
    control.beginRefreshing(); control.sendActions(for: .valueChanged)
    for _ in 0..<30 where requests == 0 { try await Task.sleep(for: .milliseconds(10)) }
    XCTAssertEqual(requests, 1, "The network action starts without waiting for the artwork")
    XCTAssertTrue(control.isRefreshing, "A fast response must not clip the fill to its first letters")
    for _ in 0..<100 where control.isRefreshing { try await Task.sleep(for: .milliseconds(20)) }
    XCTAssertFalse(control.isRefreshing)
    XCTAssertGreaterThanOrEqual(started.duration(to: .now), .seconds(LoadingWordmarkTiming.minimumFill))
    XCTAssertTrue(control.isEnabled, "Cooldown must not disable pull feedback")
    control.beginRefreshing()
    control.sendActions(for: .valueChanged)
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertEqual(requests, 1, "Repeated pulls never send another request during cooldown")
    XCTAssertEqual(control.accessibilityLabel, "Pull to refresh", "A cooldown pull must not claim to fetch data or animate progress")
    for _ in 0..<100 where control.isRefreshing { try await Task.sleep(for: .milliseconds(20)) }
    XCTAssertFalse(control.isRefreshing)
    XCTAssertTrue(control.isEnabled)
  }

  func testDisabledControlKeepsHeaderAtRestAndRestoresItsOriginalEnabledState() async {
    let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
    let control = UIRefreshControl(); scroll.refreshControl = control
    let coordinator = RefreshWordmarkProbe.Coordinator()
    coordinator.update(refreshing: false, reduceMotion: false, enabled: false)
    coordinator.onProgressChanged = { value in XCTAssertEqual(value, .idle) }
    coordinator.attach(to: control, scrollView: scroll)
    scroll.contentOffset.y = -35
    await Task.yield()
    XCTAssertFalse(control.isEnabled); XCTAssertFalse(control.isAccessibilityElement)
    coordinator.onProgressChanged = nil
    coordinator.update(refreshing: false, reduceMotion: false, enabled: true)
    XCTAssertTrue(control.isEnabled); XCTAssertTrue(control.isAccessibilityElement)
    coordinator.detach()
    XCTAssertTrue(control.isEnabled)
  }

  func testArtworkRevealsFromFirstPixelsAndStaysCloseToHeaderOnLongPull() async throws {
    let scroll = InsetRefreshScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
    scroll.simulatesDragging = true
    let control = UIRefreshControl(); scroll.refreshControl = control
    let existing = Set(scroll.subviews.map(ObjectIdentifier.init))
    let coordinator = RefreshWordmarkProbe.Coordinator()
    coordinator.attach(to: control, scrollView: scroll)
    defer { coordinator.detach() }
    let artwork = try XCTUnwrap(scroll.subviews.first { !existing.contains(ObjectIdentifier($0)) })
    scroll.contentOffset.y = -8
    coordinator.update(refreshing: false, reduceMotion: false)
    XCTAssertEqual(artwork.alpha, 1)
    XCTAssertEqual(artwork.frame.intersection(scroll.bounds).height, 8, accuracy: 0.5)
    scroll.contentOffset.y = -120
    coordinator.update(refreshing: false, reduceMotion: false)
    XCTAssertEqual(artwork.frame.minY, scroll.bounds.minY, accuracy: 0.5)
    XCTAssertEqual(artwork.frame.maxY - scroll.bounds.minY, RefreshPresentation.logoHeight, accuracy: 0.5)
    scroll.contentOffset.y = 0
    coordinator.update(refreshing: false, reduceMotion: false)
    XCTAssertEqual(artwork.alpha, 0)
  }

  func testPartialPullClipsAtTheContentEdgeWithAndWithoutATopSafeArea() throws {
    for inset: CGFloat in [0, 62] {
      let scroll = InsetRefreshScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
      scroll.topSafeArea = inset; scroll.simulatesDragging = true
      let control = UIRefreshControl(); scroll.refreshControl = control
      let existing = Set(scroll.subviews.map(ObjectIdentifier.init))
      let coordinator = RefreshWordmarkProbe.Coordinator()
      coordinator.attach(to: control, scrollView: scroll)
      let artwork = try XCTUnwrap(scroll.subviews.first { !existing.contains(ObjectIdentifier($0)) })
      for pull: CGFloat in [8, 120] {
        scroll.contentOffset.y = -(inset + pull)
        coordinator.update(refreshing: false, reduceMotion: false)
        let clip = try XCTUnwrap(artwork.layer.mask as? CAShapeLayer, "A safe-area inset requires its own clipping edge")
        let path = try XCTUnwrap(clip.path)
        // Inspect the actual CALayer clipping geometry in scroll coordinates,
        // independently of the host frame (which extends behind the header).
        let visibleGlyphBounds = artwork.convert(path.boundingBoxOfPath.intersection(artwork.bounds), to: scroll)
        XCTAssertEqual(visibleGlyphBounds.minY, scroll.bounds.minY + inset, accuracy: 0.5,
          "No part of the mark may appear above the content/header edge")
        XCTAssertEqual(visibleGlyphBounds.height, min(pull, RefreshPresentation.logoHeight), accuracy: 0.5,
          "An 8-point pull reveals only 8 points even with a 62-point top inset")
        XCTAssertEqual(artwork.alpha, 1)
      }
      scroll.contentOffset.y = -inset
      coordinator.update(refreshing: false, reduceMotion: false)
      XCTAssertEqual(artwork.alpha, 0)
      coordinator.detach()
      XCTAssertNil(artwork.layer.mask)
    }
  }

  func testRenderedRefreshGlyphsStayImmediatelyUnderSeparateHeaderDespiteNativeRefreshInset() async throws {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let originalWindow = scene.windows.first(where: \.isKeyWindow)
    let controller = UIViewController(); controller.view.backgroundColor = .black
    let window = UIWindow(windowScene: scene); window.rootViewController = controller; window.makeKeyAndVisible()
    defer { window.isHidden = true; originalWindow?.makeKey() }
    let headerBottom: CGFloat = 170
    let scroll = InsetRefreshScrollView(frame: CGRect(x: 0, y: headerBottom,
      width: window.bounds.width, height: window.bounds.height - headerBottom))
    scroll.backgroundColor = .black; scroll.contentInsetAdjustmentBehavior = .never
    scroll.contentSize = CGSize(width: scroll.bounds.width, height: 1200)
    scroll.alwaysBounceVertical = true
    controller.view.addSubview(scroll)
    let control = UIRefreshControl(); scroll.refreshControl = control
    let coordinator = RefreshWordmarkProbe.Coordinator()
    coordinator.update(refreshing: true, reduceMotion: true)
    coordinator.attach(to: control, scrollView: scroll)
    defer { coordinator.detach() }
    for (nativeInset, extraPull): (CGFloat, CGFloat) in [(0, 100), (62, 100), (62, 0)] {
      scroll.nativeRefreshInset = nativeInset
      scroll.contentOffset.y = -(nativeInset + extraPull)
      coordinator.update(refreshing: true, reduceMotion: true)
      try await Task.sleep(for: .milliseconds(100))
      let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
      let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
        XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
      }
      let attachment = XCTAttachment(image: image)
      attachment.name = "Hosted refresh glyphs with native inset \(Int(nativeInset)), pull \(Int(extraPull))"; attachment.lifetime = .keepAlways; add(attachment)
      let cgImage = try XCTUnwrap(image.cgImage)
      var rgba = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
      try rgba.withUnsafeMutableBytes { bytes in
        let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: cgImage.width, height: cgImage.height,
          bitsPerComponent: 8, bytesPerRow: cgImage.width * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
      }
      var glyphRows: [Int] = []
      for y in Int(headerBottom)..<min(cgImage.height, Int(headerBottom + 150)) {
        var lightPixels = 0
        for x in 0..<cgImage.width {
          let index = (y * cgImage.width + x) * 4
          if rgba[index] > 190 && rgba[index + 1] > 190 && rgba[index + 2] > 180 { lightPixels += 1 }
        }
        if lightPixels >= 3 { glyphRows.append(y) }
      }
      XCTAssertGreaterThan(glyphRows.count, 8, "The actual hosted artwork must render both words")
      if let lastGlyph = glyphRows.last {
        XCTAssertLessThanOrEqual(CGFloat(lastGlyph), headerBottom + RefreshPresentation.logoHeight + 1,
          "The real glyphs must stay under the header, not 62 points lower in the first post")
        if nativeInset > 0 && extraPull == 0 {
          XCTAssertLessThan(CGFloat(lastGlyph), headerBottom + nativeInset,
            "After release the indicator must remain entirely above the first post's content edge")
        }
      }
    }
  }

  func testIdleResidualAfterLoadingHidesArtworkAndANewPullStillRevealsImmediately() async throws {
    let scroll = InsetRefreshScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
    let control = UIRefreshControl(); scroll.refreshControl = control
    let existing = Set(scroll.subviews.map(ObjectIdentifier.init))
    let delegate = RefreshTestScrollDelegate(); scroll.delegate = delegate
    let coordinator = RefreshWordmarkProbe.Coordinator()
    coordinator.attach(to: control, scrollView: scroll)
    defer { coordinator.detach() }
    let artwork = try XCTUnwrap(scroll.subviews.first { !existing.contains(ObjectIdentifier($0)) })
    coordinator.update(refreshing: true, reduceMotion: true)
    XCTAssertEqual(artwork.alpha, 1)
    scroll.contentOffset.y = -12
    coordinator.update(refreshing: false, reduceMotion: true)
    try await Task.sleep(for: .milliseconds(250))
    XCTAssertEqual(artwork.alpha, 0, "A stable 12pt residual is not an ongoing pull")
    XCTAssertEqual(scroll.contentOffset.y, -12, "Decoration must not move the actual feed to hide its leftover artwork")
    scroll.simulatesDragging = true
    scroll.contentOffset.y = -8
    XCTAssertEqual(artwork.alpha, 1, "The next pull reveals from its first pixels synchronously")
    let clip = try XCTUnwrap(artwork.layer.mask as? CAShapeLayer)
    XCTAssertEqual(try XCTUnwrap(clip.path).boundingBoxOfPath.intersection(artwork.bounds).height, 8, accuracy: 0.5)
    XCTAssertTrue(scroll.delegate === delegate)
    scroll.simulatesDragging = false
    coordinator.update(refreshing: false, reduceMotion: true)
    try await Task.sleep(for: .milliseconds(250))
    XCTAssertEqual(artwork.alpha, 0, "A short pull settles completely too")
  }

  private func waitForControl(in view: UIView) async throws -> UIRefreshControl {
    for _ in 0..<40 {
      if let control = findControl(in: view), control.accessibilityIdentifier == "maroonRefreshControl" { return control }
      try await Task.sleep(for: .milliseconds(50))
    }
    XCTFail("The native SwiftUI refresh control was not decorated")
    throw NSError(domain: "Refresh test", code: 1)
  }
  private func findControl(in view: UIView) -> UIRefreshControl? {
    if let scroll = view as? UIScrollView, let refresh = scroll.refreshControl { return refresh }
    return view.subviews.lazy.compactMap { self.findControl(in: $0) }.first
  }
}

private final class RefreshTestScrollDelegate: NSObject, UIScrollViewDelegate {}

@MainActor private final class HeldRefreshAction {
  var started = 0
  private var pending: CheckedContinuation<Void, Never>?
  func run() async {
    started += 1
    await withCheckedContinuation { pending = $0 }
  }
  func complete() { pending?.resume(); pending = nil }
}

private final class InsetRefreshScrollView: UIScrollView {
  var topSafeArea: CGFloat = 0
  var nativeRefreshInset: CGFloat = 0
  var simulatesDragging = false
  override var isDragging: Bool { simulatesDragging || super.isDragging }
  override var safeAreaInsets: UIEdgeInsets { UIEdgeInsets(top: topSafeArea, left: 0, bottom: 0, right: 0) }
  override var adjustedContentInset: UIEdgeInsets {
    UIEdgeInsets(top: contentInset.top + topSafeArea + nativeRefreshInset, left: contentInset.left,
      bottom: contentInset.bottom, right: contentInset.right)
  }
}
