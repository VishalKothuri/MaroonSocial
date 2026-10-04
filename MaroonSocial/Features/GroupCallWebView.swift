import SwiftUI
import WebKit

struct GroupCallWebView: UIViewRepresentable {
  let call: GroupCallSession
  let iceServers: [RandomChatIceServer]
  let signals: [GroupCallSignal]
  let onSignal: (String, String, String) -> Void
  let onStatus: (String) -> Void
  let onFailure: (String) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true; config.mediaTypesRequiringUserActionForPlayback = []
    config.websiteDataStore = .nonPersistent()
    config.userContentController.add(context.coordinator, name: "maroonGroup")
    let view = WKWebView(frame: .zero, configuration: config)
    view.isOpaque = false; view.backgroundColor = UIColor(Palette.paper); view.scrollView.isScrollEnabled = false
    view.navigationDelegate = context.coordinator; view.uiDelegate = context.coordinator; context.coordinator.view = view
    if let file = Bundle.main.url(forResource: "group-call", withExtension: "html") { view.loadFileURL(file, allowingReadAccessTo: file.deletingLastPathComponent()) }
    else { onFailure("The group call screen could not load.") }
    return view
  }
  func updateUIView(_ view: WKWebView, context: Context) { context.coordinator.parent = self; context.coordinator.sync() }
  static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
    coordinator.stopped = true
    view.evaluateJavaScript("window.MaroonGroup?.stop()")
    view.setCameraCaptureState(.none); view.setMicrophoneCaptureState(.none)
    view.configuration.userContentController.removeScriptMessageHandler(forName: "maroonGroup")
    view.stopLoading(); view.navigationDelegate = nil; view.uiDelegate = nil
  }
  @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    var parent: GroupCallWebView
    weak var view: WKWebView?
    var stopped = false
    private var ready = false
    private var started: String?
    private var starting = false
    init(_ parent: GroupCallWebView) { self.parent = parent }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { ready = true; sync() }
    func sync() {
      guard ready, !stopped, let view, let seat = parent.call.mySeat else { return }
      let people = parent.call.participants.map { ["seat": $0.seat, "alias": $0.alias] }
      if started != parent.call.id + seat {
        guard !starting else { return }; starting = true; started = parent.call.id + seat
        let servers = parent.iceServers.map { server -> [String: Any] in
          var value: [String: Any] = ["urls": server.urls]; if let username = server.username { value["username"] = username }; if let credential = server.credential { value["credential"] = credential }; return value
        }
        let config: [String: Any] = ["mySeat": seat, "video": parent.call.mode == "video", "transport": parent.call.transport, "iceServers": servers, "people": people]
        view.callAsyncJavaScript("await window.MaroonGroup.start(config)", arguments: ["config": config], in: nil, in: .page) { [weak self] result in
          guard let self, !self.stopped else { return }; self.starting = false
          if case .failure = result { self.parent.onFailure("The camera or microphone could not start.") } else { self.sync() }
        }
        return
      }
      guard !starting else { return }
      let signals: [[String: Any]] = parent.signals.compactMap { signal in
        guard let payload = try? JSONSerialization.jsonObject(with: Data(signal.payloadJSON.utf8)) else { return nil }
        return ["id": signal.id, "from": signal.from, "kind": signal.kind, "payload": payload]
      }
      view.callAsyncJavaScript("await window.MaroonGroup.update(value)", arguments: ["value": ["people": people, "signals": signals]], in: nil, in: .page)
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      guard !stopped, message.frameInfo.isMainFrame, let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
      if type == "status", let value = body["value"] as? String { parent.onStatus(value) }
      if type == "failure", let value = body["value"] as? String { parent.onFailure(value) }
      if type == "signal", let to = body["to"] as? String, let kind = body["kind"] as? String, let payload = body["payload"], JSONSerialization.isValidJSONObject(payload), let data = try? JSONSerialization.data(withJSONObject: payload) { parent.onSignal(to, kind, String(decoding: data, as: UTF8.self)) }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { parent.onFailure("The call was interrupted.") }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) { decisionHandler(navigationAction.request.url?.isFileURL == true ? .allow : .cancel) }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(!stopped && frame.isMainFrame && webView.url?.isFileURL == true ? .prompt : .deny) }
  }
}
