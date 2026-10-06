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
  typealias KindResolver = @MainActor (SocialService) async throws -> [String: String]
  private(set) var items: [PushGameNotice] = []
  /// Game id → kind, so notices for hidden kinds (8 Ball, Cup Pong) can be left out.
  private(set) var kinds: [String: String] = [:]
  private let resolveKinds: KindResolver
  init(resolveKinds: KindResolver? = nil) {
    self.resolveKinds = resolveKinds ?? { social in try await GameService().kinds(using: social) }
  }
  /// Notices whose game is of a hidden kind are not shown. A notice whose kind could not be
  /// resolved stays; opening it shows the unavailable state if the game turns out to be hidden.
  var visibleItems: [PushGameNotice] { Self.visible(items, kinds: kinds) }
  static func visible(_ items: [PushGameNotice], kinds: [String: String], arguments: [String] = ProcessInfo.processInfo.arguments) -> [PushGameNotice] {
    items.filter { item in kinds[item.gameID].map { FeatureAvailability.isGameAvailable(kind: $0, arguments: arguments) } ?? true }
  }
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
      guard epoch == generation, !Task.isCancelled else { return }
      // Resolve kinds only while some game kind is hidden; a failed lookup keeps the previous map.
      if FeatureAvailability.availableGameKinds().count < FeatureAvailability.allGameKinds.count,
         value.items.contains(where: { kinds[$0.gameID] == nil }),
         let resolved = try? await resolveKinds(social) {
        guard epoch == generation, !Task.isCancelled else { return }
        kinds.merge(resolved) { _, new in new }
      }
      items = value.items; error = nil
    } catch { if epoch == generation, !Task.isCancelled { self.error = error.localizedDescription } }
  }
  func read(_ item: PushGameNotice, social: SocialService) async {
    do { _ = try await social.sendData(endpoint: "push-devices", action: "read", payload: ["id": item.id]); if let i = items.firstIndex(where: { $0.id == item.id }) { items[i].read = true } }
    catch { self.error = error.localizedDescription }
  }
  func reset() { generation += 1; items = []; kinds = [:]; busy = false; error = nil }
}
struct PushGameInboxView: View {
  @Environment(AppStore.self) private var store
  @State private var inbox: PushGameInbox
  init(inbox: PushGameInbox) { _inbox = State(initialValue: inbox) }
  var body: some View {
    List {
      if inbox.visibleItems.isEmpty { ContentUnavailableView("No game activity", systemImage: "gamecontroller", description: Text("New invitations and turns appear here for 24 hours.")) }
      ForEach(inbox.visibleItems) { item in
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
