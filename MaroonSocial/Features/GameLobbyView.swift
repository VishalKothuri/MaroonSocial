import SwiftUI

struct GameLobbyView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  let title: String
  @State private var matching: GameMatchmakingService
  @State private var destination: String?
  init(kind: String) {
    title = kind
    _matching = State(initialValue: GameMatchmakingService(kind: kind == "8 Ball" ? "pool" : kind == "Cup Pong" ? "pong" : "chess"))
  }
  @ViewBuilder
  var body: some View {
    if title == "8 Ball" && !store.fixtureMode {
      WebPoolView()
    } else {
      classicLobby
    }
  }
  private var classicLobby: some View {
    ScrollView {
      VStack(spacing: 24) {
        Image(systemName: title == "8 Ball" ? "8.circle.fill" : title == "Chess" ? "crown.fill" : "cup.and.saucer.fill")
          .font(.system(size: 64)).foregroundStyle(Palette.accentText).padding(.top, 36)
        VStack(spacing: 10) {
          Text(matching.searching ? "Finding your opponent…" : "Your next campus match")
            .font(.title2.bold()).multilineTextAlignment(.center)
          Text(matching.searching ? "Waiting for another Aggie to join \(title). You’ll each control your own turns." : "Match with another Aggie. Play your turn, watch their replay, and pick up where you left off.")
            .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        if matching.searching {
          LoadingWordmark(animating: true, size: 24).frame(height: 56).accessibilityLabel("Searching for a player")
          Button("Cancel search") {
            AppHaptics.shared.play(.impact)
            Task { await matching.cancel(using: store.social) }
          }
            .buttonStyle(.bordered).accessibilityIdentifier("cancelGameSearch")
        } else {
          Button {
            AppHaptics.shared.play(.impact)
            Task { await matching.find(using: store.social) }
          } label: {
            HStack { if matching.busy { ProgressView().tint(Palette.onAccent) }; Label("Find a player", systemImage: "person.2.fill") }.frame(maxWidth: .infinity)
          }.buttonStyle(PrimaryButton()).disabled(matching.busy || store.fixtureMode).accessibilityIdentifier("findGamePlayer")
          if store.fixtureMode { Text("Online matching uses your signed-in account. This preview can run practice games.").font(.caption).foregroundStyle(.secondary) }
        }
        if let error = matching.error { Text(error).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center) }
        VStack(spacing: 0) {
          NavigationLink { OnlineGamesListView().appHapticOnOpen() } label: {
            HStack { Label("My matches", systemImage: "gamecontroller.fill"); Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(16)
          }
          Divider().padding(.leading, 16)
          NavigationLink { GameView(kind: title).appHapticOnOpen() } label: {
            HStack { VStack(alignment: .leading, spacing: 4) { Label("Practice on this phone", systemImage: "iphone"); Text("Local practice · both turns on one device").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(16)
          }.accessibilityIdentifier("practiceGame")
        }.font(.subheadline.weight(.semibold)).buttonStyle(.plain).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16)).disabled(matching.searching || matching.busy)
        Text("Prefer a friend? Send a game invitation from your chat.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
      }.padding(24)
    }.appBackground().navigationTitle("").navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .tabBar)
      .navigationDestination(item: $destination) { OnlineGameView(sessionID: $0) }
      .onChange(of: matching.game?.id) { _, id in if let id { destination = id; matching.clearMatch() } }
      .task(id: "\(matching.searching)-\(scenePhase)") {
        guard matching.searching, scenePhase == .active else { return }
        while !Task.isCancelled && matching.searching {
          do { try await Task.sleep(for: .seconds(2)) } catch { return }
          guard !Task.isCancelled else { return }; await matching.poll(using: store.social)
        }
      }
      .onChange(of: scenePhase) { _, phase in if phase != .active { Task { await matching.cancel(using: store.social) } } }
      .onDisappear { Task { await matching.cancel(using: store.social) } }
  }
}
