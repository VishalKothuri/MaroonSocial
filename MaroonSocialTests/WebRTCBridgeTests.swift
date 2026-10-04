import XCTest
import WebKit
import UIKit
@testable import MaroonSocial

/// Real WebKit peer connections with generated canvas video. No camera, microphone,
/// public stranger or TURN credentials are used by this test.
@MainActor final class WebRTCBridgeTests: XCTestCase {
  func testTwoBundledWebViewsExchangeSyntheticVideoAndStopTracks() async throws {
    let loaded = expectation(description: "Both bundled pages loaded")
    loaded.expectedFulfillmentCount = 2
    let connected = expectation(description: "Both peer connections connected")
    connected.expectedFulfillmentCount = 2
    let a = BridgeTestPeer(loaded: loaded, connected: connected)
    let b = BridgeTestPeer(loaded: loaded, connected: connected)
    a.partner = b; b.partner = a
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    let window = UIWindow(windowScene: scene)
    let controller = UIViewController()
    window.rootViewController = controller
    window.isHidden = false
    a.web.frame = CGRect(x: 0, y: 0, width: 190, height: 300)
    b.web.frame = CGRect(x: 195, y: 0, width: 190, height: 300)
    controller.view.addSubview(a.web); controller.view.addSubview(b.web)
    defer { a.close(); b.close(); window.isHidden = true }
    let source = try XCTUnwrap(Bundle.main.url(forResource: "video-call", withExtension: "html"))
    a.web.loadFileURL(source, allowingReadAccessTo: source.deletingLastPathComponent())
    b.web.loadFileURL(source, allowingReadAccessTo: source.deletingLastPathComponent())
    await fulfillment(of: [loaded], timeout: 10)
    let supports = try await a.web.evaluateJavaScript("typeof RTCPeerConnection === 'function' && typeof HTMLCanvasElement.prototype.captureStream === 'function'") as? Bool
    XCTAssertEqual(supports, true)
    try await b.start(initiator: false)
    try await a.start(initiator: true)
    await fulfillment(of: [connected], timeout: 25)
    XCTAssertTrue(a.errors.isEmpty, a.errors.joined(separator: "; "))
    XCTAssertTrue(b.errors.isEmpty, b.errors.joined(separator: "; "))
    // Wait for actual decoded frames, not just SDP or an ICE state.
    let frameCheck = """
      return await new Promise((resolve, reject) => {
        const start = Date.now();
        const check = () => {
          const v = document.getElementById('remote');
          if (v.videoWidth > 0 && v.videoHeight > 0 && v.srcObject?.active) return resolve(true);
          if (Date.now() - start > 8000) return reject(new Error('No remote video frames decoded'));
          setTimeout(check, 100);
        }; check();
      });
      """
    let frameA = try await a.web.callAsyncJavaScript(frameCheck, arguments: [:], in: nil, contentWorld: .page) as? Bool
    let frameB = try await b.web.callAsyncJavaScript(frameCheck, arguments: [:], in: nil, contentWorld: .page) as? Bool
    XCTAssertEqual(frameA, true); XCTAssertEqual(frameB, true)
    // Read actual WebKit sender settings after negotiation and decoded frames.
    // A constructor wrapper observes the real peer; it does not replace codecs.
    let limits = """
      const sender = window.__qaPeers.at(-1).getSenders().find(s => s.track?.kind === 'video');
      const encodings = sender.getParameters().encodings;
      return window.__qaMediaConstraints.video.width.max === 640 &&
        window.__qaMediaConstraints.video.frameRate.max === 24 &&
        encodings.length > 0 && encodings.every(e => e.maxBitrate === 650000 && e.maxFramerate === 24);
      """
    let boundedA = try await a.web.callAsyncJavaScript(limits, arguments: [:], in: nil, contentWorld: .page) as? Bool
    let boundedB = try await b.web.callAsyncJavaScript(limits, arguments: [:], in: nil, contentWorld: .page) as? Bool
    XCTAssertEqual(boundedA, true); XCTAssertEqual(boundedB, true)
    let cleanup = """
      const tracks = document.getElementById('local').srcObject.getTracks();
      window.MaroonCall.stop();
      return tracks.every(t => t.readyState === 'ended') && document.getElementById('remote').srcObject === null;
      """
    let stoppedA = try await a.web.callAsyncJavaScript(cleanup, arguments: [:], in: nil, contentWorld: .page) as? Bool
    let stoppedB = try await b.web.callAsyncJavaScript(cleanup, arguments: [:], in: nil, contentWorld: .page) as? Bool
    XCTAssertEqual(stoppedA, true); XCTAssertEqual(stoppedB, true)
  }
}

@MainActor private final class BridgeTestPeer: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
  var web: WKWebView!
  weak var partner: BridgeTestPeer?
  let loaded: XCTestExpectation
  let connected: XCTestExpectation
  var didConnect = false
  var errors: [String] = []
  init(loaded: XCTestExpectation, connected: XCTestExpectation) {
    self.loaded = loaded; self.connected = connected
    super.init()
    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []
    config.websiteDataStore = .nonPersistent()
    config.userContentController.add(self, name: "maroonCall")
    config.userContentController.addUserScript(WKUserScript(source: """
      window.__qaPeers = [];
      const NativePeer = window.RTCPeerConnection;
      window.RTCPeerConnection = class extends NativePeer {
        constructor(config) { super(config); window.__qaPeers.push(this); }
      };
      navigator.mediaDevices.getUserMedia = async constraints => {
        window.__qaMediaConstraints = constraints;
        const canvas = document.createElement('canvas'); canvas.width = 320; canvas.height = 240;
        const ctx = canvas.getContext('2d'); let x = 0;
        const timer = setInterval(() => {
          ctx.fillStyle = '#5c0e1c'; ctx.fillRect(0, 0, 320, 240);
          ctx.fillStyle = '#d1f571'; ctx.fillRect((x++ * 7) % 260, 75, 60, 60);
          ctx.fillStyle = 'white'; ctx.font = '20px sans-serif'; ctx.fillText('SYNTHETIC QA VIDEO', 40, 205);
        }, 80);
        const stream = canvas.captureStream(12);
        stream.getVideoTracks()[0].addEventListener('ended', () => clearInterval(timer));
        return stream;
      };
      """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    web = WKWebView(frame: .zero, configuration: config)
    web.navigationDelegate = self
  }
  func start(initiator: Bool) async throws {
    _ = try await web.callAsyncJavaScript("await window.MaroonCall.start(config)", arguments: ["config": ["initiator": initiator, "video": true, "transport": "direct", "iceServers": []]], in: nil, contentWorld: .page)
  }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded.fulfill() }
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let body = message.body as? [String: Any] else { return }
    if body["type"] as? String == "signal", let kind = body["kind"] as? String, let payload = body["payload"] {
      partner?.web.callAsyncJavaScript("await window.MaroonCall.receive(signal)", arguments: ["signal": ["type": kind, "payload": payload]], in: nil, in: .page) { [weak self] result in
        if case .failure(let error) = result { self?.errors.append(error.localizedDescription) }
      }
    }
    if body["type"] as? String == "status", let status = body["value"] as? String {
      if status == "Video connected", !didConnect { didConnect = true; connected.fulfill() }
      if status.contains("could not") || status.contains("unavailable") || status.contains("interrupted") { errors.append(status) }
    }
  }
  func close() {
    web.configuration.userContentController.removeScriptMessageHandler(forName: "maroonCall")
    web.evaluateJavaScript("window.MaroonCall?.stop()")
    web.stopLoading()
    web.removeFromSuperview()
    web.navigationDelegate = nil
  }
}
