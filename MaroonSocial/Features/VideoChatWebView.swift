import SwiftUI
import WebKit

/// Bundled WebRTC client. The backend supplies media configuration after matching;
/// direct transport requires explicit consent. No third-party page is loaded.
struct VideoChatWebView: UIViewRepresentable {
  let roomID: String
  let initiator: Bool
  let mode: String
  let transport: String
  let iceServers: [RandomChatIceServer]
  let signals: [RandomChatSignal]
  var onSignal: (String, String) -> Void
  var onStatus: (String) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []
    config.websiteDataStore = .nonPersistent()
    config.userContentController.add(context.coordinator, name: "maroonCall")
    let view = WKWebView(frame: .zero, configuration: config)
    view.isOpaque = false
    view.backgroundColor = UIColor(Palette.paper)
    view.scrollView.backgroundColor = UIColor(Palette.paper)
    view.underPageBackgroundColor = UIColor(Palette.paper)
    view.scrollView.isScrollEnabled = false
    view.navigationDelegate = context.coordinator
    view.uiDelegate = context.coordinator
    context.coordinator.webView = view
    if let file = Bundle.main.url(forResource: "video-call", withExtension: "html") {
      view.loadFileURL(file, allowingReadAccessTo: file.deletingLastPathComponent())
    } else {
      onStatus("The call screen could not load. Please reopen the conversation.")
    }
    return view
  }
  func updateUIView(_ view: WKWebView, context: Context) {
    context.coordinator.parent = self
    context.coordinator.synchronize()
  }
  static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
    uiView.evaluateJavaScript("window.MaroonCall?.stop()")
    uiView.setCameraCaptureState(.none)
    uiView.setMicrophoneCaptureState(.none)
    uiView.configuration.userContentController.removeScriptMessageHandler(forName: "maroonCall")
    uiView.stopLoading()
    uiView.navigationDelegate = nil
    uiView.uiDelegate = nil
  }

  @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    var parent: VideoChatWebView
    weak var webView: WKWebView?
    private var ready = false
    private var startedRoom: String?
    private var received = Set<Int>()
    init(_ parent: VideoChatWebView) { self.parent = parent }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      ready = true
      synchronize()
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      ready = false
      parent.onStatus("The call screen couldn’t load. End this call and try again.")
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      ready = false
      parent.onStatus("The call screen couldn’t load. End this call and try again.")
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
      ready = false
      parent.onStatus("The call was interrupted. End this call and try again.")
    }
    func synchronize() {
      guard ready, let webView else { return }
      if startedRoom != parent.roomID {
        startedRoom = parent.roomID
        received = []
        let servers = parent.iceServers.map { server -> [String: Any] in
          var result: [String: Any] = ["urls": server.urls]
          if let username = server.username { result["username"] = username }
          if let credential = server.credential { result["credential"] = credential }
          return result
        }
        let config: [String: Any] = ["initiator": parent.initiator, "video": parent.mode == "video", "iceServers": servers, "transport": parent.transport]
        webView.callAsyncJavaScript("await window.MaroonCall.start(config)", arguments: ["config": config], in: nil, in: .page) { [weak self] result in
          if case .failure = result { self?.parent.onStatus("The camera or microphone could not start. Check iPhone permissions and try again.") }
        }
      }
      for signal in parent.signals where !received.contains(signal.id) {
        guard let bytes = signal.payloadJSON.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: bytes) else { continue }
        received.insert(signal.id)
        webView.callAsyncJavaScript("await window.MaroonCall.receive(signal)", arguments: ["signal": ["type": signal.kind, "payload": payload]], in: nil, in: .page)
      }
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      guard message.frameInfo.isMainFrame, let body = message.body as? [String: Any],
            let type = body["type"] as? String else { return }
      if type == "status", let value = body["value"] as? String { parent.onStatus(value) }
      if type == "signal", let kind = body["kind"] as? String,
         let payload = body["payload"], JSONSerialization.isValidJSONObject(payload),
         let data = try? JSONSerialization.data(withJSONObject: payload),
         let json = String(data: data, encoding: .utf8) { parent.onSignal(kind, json) }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
      decisionHandler(navigationAction.request.url?.isFileURL == true ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
      decisionHandler(frame.isMainFrame && webView.url?.isFileURL == true ? .prompt : .deny)
    }
  }
}
