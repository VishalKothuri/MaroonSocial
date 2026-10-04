import XCTest
import WebKit
import UIKit
@testable import MaroonSocial

/// Opt in with MAROON_HOSTED_POOL_TESTS=1 in the test runner environment.
/// Loads the real published page, but uses an invalid synthetic scope: no
/// account is created, no opponent is searched, and no turn is submitted.
@MainActor final class WebPoolHostedTests: XCTestCase {
  func testBridgeWaitsForDeferredModuleExportAndAcknowledgesOneConnection() async throws {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    let loaded = expectation(description: "Bridge fixture loaded")
    let peer = HostedPoolTestHarness(scene: scene, loaded: loaded)
    defer { peer.close() }
    peer.web.loadHTMLString("<!doctype html><body>Waiting for pool module</body>", baseURL: nil)
    await fulfillment(of: [loaded], timeout: 5)
    let initiallyMissing = try await peer.web.callAsyncJavaScript("""
      delete window.MaroonPool; window.poolConnections = 0;
      setTimeout(() => { window.MaroonPool = {connect: async () => { window.poolConnections++; document.body.textContent = 'Connected'; },disconnect: async () => {}}; }, 250);
      return typeof window.MaroonPool === 'undefined';
      """, arguments: [:], in: nil, contentWorld: .page) as? Bool
    XCTAssertEqual(initiallyMissing, true)
    let config = WebPoolSession(token: String(repeating: "a", count: 64), endpoint: "https://myxbghfbapbfffkpndwo.supabase.co/functions/v1/web-pool", rules: "maroon-web-pool-3.0.0", expiresAt: Date.now.timeIntervalSince1970 + 3600)
    let result = try await peer.web.callAsyncJavaScript(WebPoolBridge.connectScript, arguments: ["config": config.configuration], in: nil, contentWorld: .page) as? [String: Any]
    XCTAssertEqual(result?["ok"] as? Bool, true)
    let connections = try await peer.web.evaluateJavaScript("window.poolConnections") as? Int
    XCTAssertEqual(connections, 1)
    let text = try await peer.web.evaluateJavaScript("document.body.textContent") as? String
    XCTAssertEqual(text, "Connected")
  }
  func testPublishedPoolInitializesInPortraitWebKitWithNativeBridge() async throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["MAROON_HOSTED_POOL_TESTS"] == "1", "Opt-in published-page check")
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    let loaded = expectation(description: "Published pool page loaded")
    let peer = HostedPoolTestHarness(scene: scene, loaded: loaded)
    defer { peer.close() }
    peer.web.load(URLRequest(url: try XCTUnwrap(URL(string: "https://maroon-social-games.vercel.app/")), cachePolicy: .reloadIgnoringLocalCacheData))
    await fulfillment(of: [loaded], timeout: 15)
    XCTAssertTrue(peer.errors.isEmpty, peer.errors.joined(separator: "; "))
    let config = WebPoolSession(token: String(repeating: "a", count: 64), endpoint: "https://myxbghfbapbfffkpndwo.supabase.co/functions/v1/web-pool", rules: "maroon-web-pool-3.0.0", expiresAt: Date.now.timeIntervalSince1970 + 3600)
    let result = try await peer.web.callAsyncJavaScript(WebPoolBridge.connectScript, arguments: ["config": config.configuration], in: nil, contentWorld: .page) as? [String: Any]
    XCTAssertEqual(result?["ok"] as? Bool, true, WebPoolBridge.failure(result))
    let state = try await peer.web.callAsyncJavaScript("""
      const deadline = Date.now() + 8000;
      while (document.querySelector('.preview-pill')?.textContent !== 'Pool · online' && Date.now() < deadline && document.getElementById('previewFailure')?.hidden !== false) {
        await new Promise(resolve => setTimeout(resolve, 80));
      }
      return {online:document.querySelector('.preview-pill')?.textContent === 'Pool · online',
        failed:document.getElementById('previewFailure')?.hidden === false,
        disabled:document.getElementById('cueHit')?.disabled === true,
        canvasWidth:document.querySelector('#viewP1 canvas')?.getBoundingClientRect().width ?? 0,
        canvasHeight:document.querySelector('#viewP1 canvas')?.getBoundingClientRect().height ?? 0};
      """, arguments: [:], in: nil, contentWorld: .page) as? [String: Any]
    XCTAssertEqual(state?["online"] as? Bool, true, peer.errors.joined(separator: "; "))
    XCTAssertEqual(state?["failed"] as? Bool, false)
    XCTAssertEqual(state?["disabled"] as? Bool, true, "An invalid test scope must never enable a shot")
    XCTAssertGreaterThan(state?["canvasWidth"] as? Double ?? 0, 350)
    XCTAssertGreaterThan(state?["canvasHeight"] as? Double ?? 0, 250)
  }
}

@MainActor private final class HostedPoolTestHarness: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
  let web: WKWebView
  let window: UIWindow
  let loaded: XCTestExpectation
  var errors: [String] = []
  init(scene: UIWindowScene, loaded: XCTestExpectation) {
    self.loaded = loaded
    let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
    web = WKWebView(frame: CGRect(x: 0, y: 0, width: 402, height: 760), configuration: config)
    window = UIWindow(windowScene: scene)
    super.init()
    config.userContentController.add(self, name: "poolTestError")
    config.userContentController.addUserScript(WKUserScript(source: """
      const report = value => window.webkit.messageHandlers.poolTestError.postMessage(String(value).replace(/[a-f0-9]{64}/gi,'[redacted]').slice(0,180));
      window.addEventListener('error', e => report(e.message));
      window.addEventListener('unhandledrejection', e => report(e.reason?.message ?? 'Unhandled promise rejection'));
      """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    web.navigationDelegate = self
    let controller = UIViewController(); window.rootViewController = controller; window.isHidden = false
    controller.view.addSubview(web)
  }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded.fulfill() }
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { errors.append(error.localizedDescription); loaded.fulfill() }
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) { if let value = message.body as? String { errors.append(value) } }
  func close() { web.evaluateJavaScript("window.MaroonPool?.disconnect()"); web.stopLoading(); web.removeFromSuperview(); web.navigationDelegate = nil; web.configuration.userContentController.removeScriptMessageHandler(forName: "poolTestError"); window.isHidden = true }
}
