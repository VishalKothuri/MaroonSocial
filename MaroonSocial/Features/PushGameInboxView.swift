import SwiftUI
import Observation

struct PushGameNotice: Decodable, Identifiable {
  let id: String
  let kind: String
  let title: String
  let roomID: String?
  let gameID: String
  let created: Date
  var read: Bool
}
@Observable @MainActor final class PushGameInbox {
  private(set) var items: [PushGameNotice] = []
  private(set) var busy = false
  var error: String?
  private var generation = 0
  private struct Response: Decodable { let items: [PushGameNotice] }
  func refresh(social: SocialService) async {
    guard !busy else { return }; busy = true; let epoch = generation; defer { if epoch == generation { busy = false } }
    do {
      let data = try await social.sendData(endpoint: "push-devices", action: "inbox")
      let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
      let value = try decoder.decode(Response.self, from: data)
      guard epoch == generation, !Task.isCancelled else { return }; items = value.items; error = nil
    } catch { if epoch == generation, !Task.isCancelled { self.error = error.localizedDescription } }
  }
  func read(_ item: PushGameNotice, social: SocialService) async {
    do { _ = try await social.sendData(endpoint: "push-devices", action: "read", payload: ["id": item.id]); if let i = items.firstIndex(where: { $0.id == item.id }) { items[i].read = true } }
    catch { self.error = error.localizedDescription }
  }
  func reset() { generation += 1; items = []; busy = false; error = nil }
}
struct PushGameInboxView: View {
  @Environment(AppStore.self) private var store
  @State private var inbox: PushGameInbox
  init(inbox: PushGameInbox) { _inbox = State(initialValue: inbox) }
  var body: some View {
    List {
      if inbox.items.isEmpty { ContentUnavailableView("No game activity", systemImage: "gamecontroller", description: Text("New invitations and turns appear here for 24 hours.")) }
      ForEach(inbox.items) { item in
        NavigationLink { OnlineGameView(sessionID: item.gameID).task { await inbox.read(item, social: store.social) } } label: {
          HStack(spacing: 12) {
            Image(systemName: item.kind == "game_turn" ? "arrow.turn.up.right" : "gamecontroller").foregroundStyle(Palette.accentText)
            VStack(alignment: .leading) { Text(item.title).font(.headline); Text(item.created, style: .relative).font(.caption).foregroundStyle(Palette.secondary) }
            Spacer(); if !item.read { Circle().fill(Palette.maroon).frame(width: 9, height: 9).accessibilityLabel("Unread") }
          }
        }
      }
      if let error = inbox.error { Text(error).font(.caption).foregroundStyle(Palette.secondary) }
    }.scrollContentBackground(.hidden).appBackground().navigationTitle("Game activity").navigationBarTitleDisplayMode(.inline)
      .task { if !store.fixtureMode { await inbox.refresh(social: store.social) } }
      .maroonRefreshable(scope: "game-notices") { if !store.fixtureMode { await inbox.refresh(social: store.social) } }

  }
}
