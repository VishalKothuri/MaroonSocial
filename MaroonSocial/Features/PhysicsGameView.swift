import SwiftUI
import WebKit

struct PhysicsGameView: View {
  let kind: String
  var body: some View {
    PhysicsTableView(configuration: ["kind": kind == "8 Ball" ? "pool" : "pong", "online": false]) { _ in }
      .background(Palette.paper)
  }
}
struct PhysicsTableView: UIViewRepresentable {
  var configuration: [String: Any]
  var onShot: ([String: Any]) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(onShot: onShot) }
  func makeUIView(context: Context) -> PhysicsGameContainer {
    let config = WKWebViewConfiguration()
    config.userContentController.add(context.coordinator, name: "game")
    let view = WKWebView(frame: .zero, configuration: config)
    view.isOpaque = false; view.backgroundColor = UIColor(Palette.paper)
    view.scrollView.isScrollEnabled = false; view.scrollView.bounces = false
    view.navigationDelegate = context.coordinator; view.uiDelegate = context.coordinator
    view.accessibilityIdentifier = "physics-game-table"
    view.isAccessibilityElement = false
    view.accessibilityElementsHidden = false
    let container = PhysicsGameContainer(web: view)
    context.coordinator.view = view; context.coordinator.container = container; context.coordinator.configuration = configuration
    container.retry = { [weak coordinator = context.coordinator] in coordinator?.load() }
    context.coordinator.load()
    return container
  }
  func updateUIView(_ container: PhysicsGameContainer, context: Context) {
    context.coordinator.onShot = onShot; context.coordinator.configuration = configuration; context.coordinator.update()
  }
  static func dismantleUIView(_ container: PhysicsGameContainer, coordinator: Coordinator) {
    coordinator.loadingTimeout?.cancel()
    let view = container.web
    view.configuration.userContentController.removeScriptMessageHandler(forName: "game")
    view.stopLoading(); view.navigationDelegate = nil; view.uiDelegate = nil
  }
  @MainActor final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    weak var view: WKWebView?
    weak var container: PhysicsGameContainer?
    var loadingTimeout: Task<Void, Never>?
    var configuration: [String: Any] = [:]
    var onShot: ([String: Any]) -> Void
    var ready = false
    var lastData: Data?
    init(onShot: @escaping ([String: Any]) -> Void) { self.onShot = onShot }
    func load() {
      ready = false; lastData = nil; loadingTimeout?.cancel(); container?.showLoading()
      guard let url = Bundle.main.url(forResource: "game-table", withExtension: "html") else { container?.showError("The game files are missing. Reinstall the app to restore them."); return }
      view?.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
      loadingTimeout = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(12))
        guard !Task.isCancelled, let self, !self.ready else { return }
        self.container?.showError("The table took too long to load. Try again.")
      }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { container?.showError("The table could not load. Try again.") }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { container?.showError("The table could not load. Try again.") }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { ready = false; container?.showError("The game renderer restarted. Reload the table to continue.") }
    func update() {
      guard ready, let data = try? JSONSerialization.data(withJSONObject: configuration, options: .sortedKeys), data != lastData else { return }
      lastData = data
      let snapshot = configuration
      Task { @MainActor [weak self] in
        do { _ = try await self?.view?.callAsyncJavaScript("window.MaroonGame.configure(config)", arguments: ["config": snapshot], in: nil, contentWorld: .page); self?.container?.hideOverlay() }
        catch { self?.lastData = nil; self?.container?.showError("The table could not start. Try again.") }
      }
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
      if type == "ready" { ready = true; loadingTimeout?.cancel(); update() }
      else if type == "error" { ready = false; container?.showError(body["message"] as? String ?? "The game renderer could not start.") }
      else if type == "shot", let input = body["input"] as? [String: Any] { AppHaptics.shared.play(.impact); onShot(input) }
      else if type == "haptic", configuration["online"] as? Bool != true {
        // Online replays also arrive through this bridge after polling; only
        // explicit local practice/replay interaction supplies table feedback.
        AppHaptics.shared.play(.impact)
      }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
      decisionHandler(navigationAction.request.url?.isFileURL == true ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
      let alert = UIAlertController(title: "New game", message: message, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "Keep playing", style: .cancel) { _ in completionHandler(false) })
      alert.addAction(UIAlertAction(title: "Start over", style: .destructive) { _ in completionHandler(true) })
      var presenter = webView.window?.rootViewController
      while let next = presenter?.presentedViewController { presenter = next }
      guard let presenter else { completionHandler(false); return }; presenter.present(alert, animated: true)
    }
  }
}

@MainActor final class PhysicsGameContainer: UIView {
  let web: WKWebView
  private let overlay = UIView()
  private let spinner = UIActivityIndicatorView(style: .medium)
  private let message = UILabel()
  private let retryButton = UIButton(type: .system)
  var retry: (() -> Void)?
  init(web: WKWebView) {
    self.web = web; super.init(frame: .zero)
    isAccessibilityElement = false
    backgroundColor = UIColor(Palette.paper)
    overlay.backgroundColor = backgroundColor
    web.translatesAutoresizingMaskIntoConstraints = false; overlay.translatesAutoresizingMaskIntoConstraints = false
    addSubview(web); addSubview(overlay)
    for child in [web, overlay] { NSLayoutConstraint.activate([child.topAnchor.constraint(equalTo: topAnchor), child.bottomAnchor.constraint(equalTo: bottomAnchor), child.leadingAnchor.constraint(equalTo: leadingAnchor), child.trailingAnchor.constraint(equalTo: trailingAnchor)]) }
    message.font = .preferredFont(forTextStyle: .callout); message.numberOfLines = 0; message.textAlignment = .center; message.textColor = UIColor(Palette.ink)
    retryButton.setTitle("Reload table", for: .normal); retryButton.addTarget(self, action: #selector(reload), for: .touchUpInside)
    let stack = UIStackView(arrangedSubviews: [spinner, message, retryButton]); stack.axis = .vertical; stack.spacing = 14; stack.alignment = .center; stack.translatesAutoresizingMaskIntoConstraints = false; overlay.addSubview(stack)
    NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor), stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor), stack.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 28), stack.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -28)])
    showLoading()
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  @objc private func reload() { retry?() }
  func showLoading() { overlay.isHidden = false; spinner.startAnimating(); message.text = "Loading table…"; retryButton.isHidden = true }
  func showError(_ error: String) { overlay.isHidden = false; spinner.stopAnimating(); message.text = error; retryButton.isHidden = false }
  func hideOverlay() { spinner.stopAnimating(); overlay.isHidden = true }
}

struct GameInviteSheet: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let roomID: String
  var onSent: (() async -> Void)? = nil
  @State private var service = GameService()
  @State private var kind = "pool"
  @State private var nonce = UUID().uuidString
  @State private var sending = false
  @State private var error: String?
  @State private var opponent = ""
  private var isGroup: Bool { store.conversationMeta[roomID]?.kind == "group" }
  private var opponents: [SocialGroupMember] {
    GroupGameOpponents.eligible(store.conversationMeta[roomID]?.members ?? [])
  }
  var body: some View {
    NavigationStack {
      ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Choose a game. Your friend accepts before play starts.").font(.callout).foregroundStyle(.secondary)
        if isGroup {
          Picker("Invite a member", selection: $opponent) {
            Text("Choose a player").tag("")
            ForEach(opponents, id: \.memberKey) { Text($0.username).tag($0.memberKey ?? "") }
          }.accessibilityIdentifier("gameOpponentPicker")
          Text(opponents.isEmpty ? "Another member must join this chat before you can invite them." : "Only the selected member can accept. Others in the chat can see the invitation.").font(.caption).foregroundStyle(.secondary)
        }
        ForEach(["pool", "pong", "chess"], id: \.self) { option in
          Button { kind = option; nonce = UUID().uuidString } label: {
            HStack(spacing: 15) {
              Image(systemName: option == "pool" ? "circle.fill" : option == "pong" ? "cup.and.saucer.fill" : "crown.fill").frame(width: 32)
              VStack(alignment: .leading) { Text(OnlineGame.title(option)).font(.headline); Text(option == "pool" ? "Real collisions. Plan your next shot." : option == "pong" ? "Arc, bounce, and clear six cups." : "Classic rules. Your move.").font(.caption).foregroundStyle(.secondary) }
              Spacer(); Image(systemName: kind == option ? "checkmark.circle.fill" : "circle")
            }.padding().background(Palette.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
          }.buttonStyle(.plain)
        }
        if let error { Text(error).foregroundStyle(.red).font(.callout) }
        Button { Task {
          guard !isGroup || opponents.contains(where: { $0.memberKey == opponent }) else { error = "Choose a current group member to invite."; return }
          sending = true; defer { sending = false }
          do { _ = try await service.invite(room: roomID, kind: kind, nonce: nonce, opponentMemberKey: isGroup ? opponent : nil, using: store.social); await onSent?(); dismiss() }
          catch { self.error = error.localizedDescription }
        } } label: { HStack { Spacer(); if sending { ProgressView().tint(Palette.onAccent) } else { Text("Send invitation").bold() }; Spacer() }.padding() }.buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent).disabled(sending || (isGroup && !opponents.contains { $0.memberKey == opponent })).accessibilityIdentifier("sendGameInvitation")
      }.padding(20).frame(maxHeight: .infinity, alignment: .top).background(Palette.paper).navigationTitle("Invite to play").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
      }.background(Palette.paper).onChange(of: opponent) { _, _ in nonce = UUID().uuidString }
    }
  }
}
struct GroupGameInvitationCard: View {
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  let sessionID: String
  let title: String
  @State private var information: GameInvitationInfo?
  @State private var unavailable = false
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      if let information, information.canOpen {
        NavigationLink { OnlineGameView(sessionID: sessionID) } label: {
          Label(information.status == "pending" ? "Open \(title) invitation" : "Open \(title)", systemImage: "gamecontroller.fill").font(.headline)
        }
      } else { Label(title, systemImage: "gamecontroller.fill").font(.headline) }
      if let information {
        Text(information.players.joined(separator: " · ")).font(.caption)
        Text(information.status == "pending" ? "Waiting for the invited player" : information.status.capitalized).font(.caption).foregroundStyle(.secondary)
      } else if unavailable { Text("This invitation is unavailable.").font(.caption).foregroundStyle(.secondary) }
      else { ProgressView().controlSize(.mini) }
    }.accessibilityIdentifier("groupGameCard-\(sessionID)")
      .task(id: scenePhase) {
        guard scenePhase == .active else { return }
        guard !store.fixtureMode else { unavailable = true; return }
        while !Task.isCancelled {
          do { information = try await GameService().invitation(sessionID, using: store.social); unavailable = false }
          catch { if !Task.isCancelled { information = nil; unavailable = true }; return }
          guard information?.status == "pending" else { return }
          do { try await Task.sleep(for: .seconds(15)) } catch { return }
        }
      }
  }
}
struct OnlineGameView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  let sessionID: String
  @State private var service = GameService()
  @State private var resign = false
  @State private var rematch = false
  private var config: [String: Any] {
    guard let game = service.game else { return [:] }
    var config = game.configuration
    config["interactive"] = game.yourTurn && !service.busy
    return config
  }
  var body: some View {
    VStack(spacing: 0) {
      if let game = service.game {
        if game.status == "pending" {
          VStack(spacing: 18) {
            Image(systemName: "gamecontroller.fill").font(.system(size: 70)).foregroundStyle(Color(red: 0.35, green: 0.10, blue: 0.16))
            Text(game.title).font(.largeTitle.bold())
            Text(game.detail).multilineTextAlignment(.center)
            Text("Accept to start. You can return to this match anytime.").font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if game.canAccept {
              Button("Accept & play") { Task { await service.act("accept", using: store.social) } }.buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent)
              Button("Decline invitation", role: .destructive) { Task { await service.act("decline", using: store.social) } }
            } else { Button("Cancel invitation", role: .destructive) { Task { await service.act("cancel", using: store.social) } } }
          }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).disabled(service.busy)
        } else if game.status == "declined" || game.status == "expired" {
          ContentUnavailableView(game.status == "expired" ? "Invitation expired" : "Invitation closed", systemImage: "gamecontroller", description: Text("Send another invitation when you’re both ready."))
        } else if game.usesHostedPool {
          WebPoolView(sessionID: game.id)
        } else {
          PhysicsTableView(configuration: config) { input in Task { await service.turn(input, using: store.social) } }
          if game.status == "finished" { Button("Invite to a rematch") { rematch = true }.buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent).padding(.bottom, 10) }
        }
      } else { ProgressView("Opening match…").frame(maxWidth: .infinity, maxHeight: .infinity) }
      if let error = service.error { HStack { Text(error).font(.caption); Spacer(); Button("Retry") { Task { service.error = nil; await service.fetch(sessionID, using: store.social) } } }.padding(10).background(Color.orange.opacity(0.15)) }
    }.background(Palette.paper).tint(Palette.accentText)
      .navigationTitle(service.game?.title ?? "Match").navigationBarTitleDisplayMode(.inline).hidesTabBarWhenPushed()
      .toolbar { if service.game?.status == "active" && service.game?.usesHostedPool != true { ToolbarItem(placement: .topBarTrailing) { Button("Resign") { resign = true }.font(.caption) } } }
      .confirmationDialog("Resign this match?", isPresented: $resign, titleVisibility: .visible) { Button("Resign", role: .destructive) { Task { await service.act("forfeit", using: store.social) } } } message: { Text("Your opponent will win. Leaving this screen keeps the match active.") }
      .sheet(isPresented: $rematch) { if let game = service.game { GameInviteSheet(roomID: game.roomID).presentationDetents([.medium, .large]) } }
      .task(id: scenePhase) {
        guard scenePhase == .active else { return }
        await service.fetch(sessionID, using: store.social)
        while !Task.isCancelled {
          if service.game?.usesHostedPool == true && service.game?.status != "pending" { break }
          try? await Task.sleep(for: .seconds(2)); if Task.isCancelled { break }; if !service.busy { await service.fetch(sessionID, using: store.social) } }
      }
  }
}
struct OnlineGamesListView: View {
  @Environment(AppStore.self) private var store
  @State private var service = GameService()
  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        if service.games.isEmpty { ContentUnavailableView("No matches yet", systemImage: "gamecontroller", description: Text("Tap Find a player in a game lobby, or send a game invitation from a direct or group chat.")) }
        ForEach(service.games) { game in NavigationLink { OnlineGameView(sessionID: game.id) } label: { HStack(spacing: 15) { Image(systemName: game.kind == "chess" ? "crown.fill" : "gamecontroller.fill").font(.title2); VStack(alignment: .leading, spacing: 5) { Text(game.title + " · " + game.opponent).font(.headline); Text(game.detail).font(.caption).foregroundStyle(.secondary) }; Spacer(); if game.yourTurn || game.canAccept { Circle().fill(.orange).frame(width: 9, height: 9) }; Image(systemName: "chevron.right").font(.caption) }.padding(18).background(Palette.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 18)) }.buttonStyle(.plain) }
        if let error = service.error { Text(error).foregroundStyle(.red).font(.callout) }
      }.padding()
    }.background(Palette.paper).navigationTitle("My matches").task { await service.list(using: store.social) }.maroonRefreshable(scope: "games") { await service.list(using: store.social) }
  }
}
