import XCTest
import WebKit
import UIKit
@testable import MaroonSocial

/// Exercises the actual renderer and navigation delegate with local fixture HTML.
/// No KLIPY key, ad request, impression, tracking URL or click is used.
@MainActor final class KlipyAdvertisementTests: XCTestCase {
  func testHTMLWithHTTPSBaseRendersAndAutomaticTopNavigationIsBlocked() async throws {
    let loaded = expectation(description: "Fixture HTML loaded")
    let blocked = expectation(description: "Automatic top navigation rejected")
    let coordinator = KlipyAdvertisement.Coordinator()
    coordinator.onLoad = { loaded.fulfill() }
    coordinator.onBlockedNavigation = { blocked.fulfill() }
    let web = KlipyAdvertisement.makeWebView(coordinator: coordinator)
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    let window = UIWindow(windowScene: scene)
    let controller = UIViewController(); window.rootViewController = controller; window.isHidden = false
    web.frame = CGRect(x: 0, y: 80, width: 300, height: 100)
    controller.view.addSubview(web)
    defer { web.stopLoading(); web.navigationDelegate = nil; web.removeFromSuperview(); window.isHidden = true }
    let html = """
      <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
      <body style="margin:0;background:#500000;color:white"><p id="fixture" style="font:22px sans-serif">Local renderer test</p></body></html>
      """
    coordinator.load(html, in: web)
    await fulfillment(of: [loaded], timeout: 8)
    let visible = try await web.evaluateJavaScript("(() => { const e=document.getElementById('fixture'); const r=e.getBoundingClientRect(); return e.textContent === 'Local renderer test' && r.width > 0 && r.height > 0 && r.top < innerHeight; })()") as? Bool
    XCTAssertEqual(visible, true, "The actual local HTML document must render, not remain an empty WebView")
    XCTAssertFalse(web.configuration.websiteDataStore.isPersistent)
    XCTAssertFalse(web.scrollView.isScrollEnabled)
    // The destination is rejected before loading; it has no server or tracker.
    _ = try await web.evaluateJavaScript("window.location.href='https://example.invalid/automatic-redirect'")
    await fulfillment(of: [blocked], timeout: 5)
    let retainedText = try await web.evaluateJavaScript("document.getElementById('fixture')?.textContent") as? String
    XCTAssertEqual(retainedText, "Local renderer test")
    XCTAssertEqual(web.url?.host, "api.klipy.com")
    // SwiftUI updates with unchanged content must not reload/impress an ad.
    _ = try await web.evaluateJavaScript("document.getElementById('fixture').dataset.marker='retained'")
    coordinator.load(html, in: web)
    let marker = try await web.evaluateJavaScript("document.getElementById('fixture').dataset.marker") as? String
    XCTAssertEqual(marker, "retained")
    let replacement = expectation(description: "Replacement fixture HTML loaded")
    coordinator.onLoad = { replacement.fulfill() }
    coordinator.load(html.replacingOccurrences(of: "Local renderer test", with: "Updated renderer test"), in: web)
    await fulfillment(of: [replacement], timeout: 8)
    let updatedText = try await web.evaluateJavaScript("document.getElementById('fixture')?.textContent") as? String
    XCTAssertEqual(updatedText, "Updated renderer test", "A reused SwiftUI ad row loads changed HTML")
    let rendered = try await web.takeSnapshot(configuration: nil)
    let attachment = XCTAttachment(image: rendered); attachment.name = "Local fixture rendered in actual WKWebView"; attachment.lifetime = .keepAlways; add(attachment)
  }
}
