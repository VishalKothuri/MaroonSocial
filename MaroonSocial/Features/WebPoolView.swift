import SwiftUI
import WebKit

/// The hosted GPL pool has only a short-lived, pool-only credential. Account
/// tokens never enter web content, browser storage, URLs, or navigation history.
struct WebPoolView: View {
  var sessionID: String? = nil
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  @State private var lease = WebPoolSessionStore()
  private var identity: String { "\(store.compositions.owner)|\(store.social.identityRevision)|\(store.auth.userID ?? "")|\(store.auth.signedIn)" }
  var body: some View {
    ZStack {
      Palette.paper.ignoresSafeArea()
      if let session = lease.session, lease.owner == identity {
        HostedPoolTable(session: session, sessionID: sessionID, active: scenePhase == .active, loading: $lease.loading, error: $lease.error).id(session.token)
      }
      if lease.loading { VStack(spacing: 14) { LoadingWordmark(size: 24); Text("Loading your table…").font(.callout) }.padding(24).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18)) }
      if let error = lease.error { VStack(spacing: 16) { Image(systemName: "wifi.exclamationmark").font(.title); Text(error).multilineTextAlignment(.center); Button("Retry") { Task { await connect() } }.buttonStyle(PrimaryButton()) }.padding(24).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18)).padding(24) }
    }
    .navigationTitle("Pool").navigationBarTitleDisplayMode(.inline)
    .toolbar(.hidden, for: .tabBar)
    .task(id: identity) { await connect() }
    .onDisappear { lease.invalidate(revoke: WebPoolSessionStore.revoke) }
  }
  private func connect() async {
    await lease.connect(owner: identity, currentOwner: { identity }, create: {
      guard !store.fixtureMode else { throw SocialServiceError(error: "Online pool needs a connected account. Your saved games are unchanged.", code: "unavailable") }
      let data = try await store.social.sendData(endpoint: "web-pool", action: "session")
      return try JSONDecoder().decode(WebPoolSession.self, from: data)
    }, revoke: WebPoolSessionStore.revoke)
  }
}
struct WebPoolSession: Decodable {
  let token, endpoint, rules: String
  let expiresAt: Double
  var configuration: [String: Any] { ["token": token, "endpoint": endpoint, "expiresAt": expiresAt] }
}
enum WebPoolPolicy {
  static func trustedOrigin(_ url: URL) -> Bool {
    url.scheme == "https" && ["maroon-social-games.vercel.app", "games.maroonsocial.chat"].contains(url.host ?? "") && (url.port == nil || url.port == 443) && url.user == nil && url.password == nil
  }
  static func table(_ url: URL) -> Bool { trustedOrigin(url) && ["/", "/index.html"].contains(url.path) && url.query == nil }
  static func source(_ url: URL) -> Bool { trustedOrigin(url) && ["/source.html", "/LICENSE.txt", "/THIRD-PARTY-LICENSES.txt", "/source/maroon-pool-source.tar.gz"].contains(url.path) && url.query == nil }
}
private struct HostedPoolTable: UIViewRepresentable {
  let session: WebPoolSession
  let sessionID: String?
  let active: Bool
  @Binding var loading: Bool
  @Binding var error: String?
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
    let view = WKWebView(frame: .zero, configuration: config)
    view.navigationDelegate = context.coordinator; view.uiDelegate = context.coordinator
    view.isOpaque = false; view.backgroundColor = UIColor(Palette.paper); view.scrollView.backgroundColor = UIColor(Palette.paper)
    view.scrollView.bounces = false
    view.load(URLRequest(url: URL(string: "https://maroon-social-games.vercel.app/")!, cachePolicy: .reloadRevalidatingCacheData))
    return view
  }
  func updateUIView(_ view: WKWebView, context: Context) {
    context.coordinator.parent = self
    if context.coordinator.active != active {
      context.coordinator.active = active
      if active { context.coordinator.configure(view) }
      else { context.coordinator.callbackGeneration += 1; view.evaluateJavaScript("window.MaroonPool?.disconnect()") }
    }
  }
  static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) { coordinator.disposed = true; coordinator.callbackGeneration += 1; view.evaluateJavaScript("window.MaroonPool?.disconnect()"); view.stopLoading(); view.navigationDelegate = nil; view.uiDelegate = nil }
  final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    var parent: HostedPoolTable
    var active = true
    var ready = false
    var disposed = false
    var callbackGeneration = 0
    init(_ parent: HostedPoolTable) { self.parent = parent }
    func webView(_ view: WKWebView, didFinish navigation: WKNavigation!) { ready = true; configure(view) }
    func configure(_ view: WKWebView) {
      guard ready, active, !disposed, let url = view.url, WebPoolPolicy.table(url) else { return }
      callbackGeneration += 1; let callback = callbackGeneration
      var config = parent.session.configuration
      if let sessionID = parent.sessionID { config["gameID"] = sessionID }
      view.callAsyncJavaScript(WebPoolBridge.connectScript, arguments: ["config": config], in: nil, in: .page) { [weak self] result in
        Task { @MainActor in guard let self, !self.disposed, self.active, self.callbackGeneration == callback else { return }; self.parent.loading = false
          switch result {
          case .success(let value):
            if let details = value as? [String: Any], details["ok"] as? Bool == true { self.parent.error = nil }
            else { self.parent.error = WebPoolBridge.failure(value as? [String: Any]) }
          case .failure(let error):
            WebPoolBridge.logWebKit(error)
            self.parent.error = "The pool table couldn’t start. Please reload it."
          } }
      }
    }
    func webView(_ view: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ view: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webViewWebContentProcessDidTerminate(_ view: WKWebView) { parent.loading = false; parent.error = "The table closed unexpectedly. Reload to return to your match." }
    private func failed(_ error: Error) { guard (error as NSError).code != NSURLErrorCancelled else { return }; parent.loading = false; parent.error = "The pool table couldn’t load. Check your connection and retry." }
    func webView(_ view: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
      guard !disposed, let url = action.request.url, WebPoolPolicy.trustedOrigin(url) else { decisionHandler(.cancel); return }
      // Source/license pages stay on the same published origin and receive no
      // fresh credential injection because they have no MaroonPool bridge.
      if action.navigationType == .linkActivated, WebPoolPolicy.source(url) { UIApplication.shared.open(url); decisionHandler(.cancel); return }
      decisionHandler(WebPoolPolicy.table(url) ? .allow : .cancel)
    }
    func webView(_ view: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
      guard let presenter = view.window?.rootViewController else { completionHandler(false); return }
      var top = presenter; while let shown = top.presentedViewController { top = shown }
      let alert = UIAlertController(title: "Pool", message: message, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
      alert.addAction(UIAlertAction(title: "Resign", style: .destructive) { _ in completionHandler(true) })
      top.present(alert, animated: true)
    }
  }
}

/// Explicit acknowledgement separates module startup, scope validation and
/// renderer errors. Diagnostics never include credentials or request payloads.
enum WebPoolBridge {
  static let connectScript = #"""
  let stage = 'module';
  try {
    const deadline = Date.now() + 10000;
    while (typeof window.MaroonPool?.connect !== 'function' && Date.now() < deadline) {
      await new Promise(resolve => setTimeout(resolve, 40));
    }
    if (typeof window.MaroonPool?.connect !== 'function') return {ok:false,stage,detail:'The pool module did not finish loading.'};
    stage = 'session';
    if (config.endpoint !== 'https://myxbghfbapbfffkpndwo.supabase.co/functions/v1/web-pool') return {ok:false,stage,detail:'The pool endpoint is unavailable.'};
    if (typeof config.token !== 'string' || !/^[a-f0-9]{64}$/.test(config.token)) return {ok:false,stage,detail:'The pool credential is invalid.'};
    if (typeof config.expiresAt !== 'number' || config.expiresAt * 1000 < Date.now()) return {ok:false,stage,detail:'This pool session expired. Reopen the table.'};
    stage = 'renderer';
    await window.MaroonPool.connect(config);
    return {ok:true};
  } catch (error) {
    const detail = String(error?.message ?? 'The table could not start.').replace(/[a-f0-9]{64}/gi,'[redacted]').slice(0,160);
    return {ok:false,stage,detail};
  }
  """#
  static func logWebKit(_ error: Error) {
    #if DEBUG
    let failure = error as NSError
    print("Pool WebKit failure: \(failure.domain) \(failure.code)")
    #endif
  }
  static func failure(_ value: [String: Any]?) -> String {
    let stage = value?["stage"] as? String ?? "unknown"
    let safeStage = ["module", "session", "renderer"].contains(stage) ? stage : "unknown"
    let detail = (value?["detail"] as? String ?? "Please reload the table.")
      .replacingOccurrences(of: "[a-fA-F0-9]{64}", with: "[redacted]", options: .regularExpression)
    #if DEBUG
    print("Pool bridge [\(safeStage)]: \(String(detail.prefix(160)))")
    #endif
    switch safeStage {
    case "module": return "The pool table is taking too long to load. Check your connection and retry."
    case "session": return "Your pool session couldn’t be verified. Reopen the table to reconnect."
    default: return "The pool table couldn’t start. Please reload it."
    }
  }
}
