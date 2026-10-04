import SwiftUI

struct RoomNotificationSettings: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let roomID: String
  @State private var status: RoomMuteStatus?
  @State private var busy = false
  @State private var error: String?
  var body: some View {
    NavigationStack {
      List {
        Section {
          Label(status?.muted == true ? "Notifications muted" : "Notifications on", systemImage: status?.muted == true ? "bell.slash" : "bell")
          Text("Messages and unread counts stay in your inbox. Muting stops notifications from this conversation.").font(.caption).foregroundStyle(Palette.secondary)
        }
        Section("Mute for") {
          ForEach([(1,"1 hour"),(8,"8 hours"),(24,"1 day"),(168,"1 week"),(-1,"Until I turn them on")],id: \.0) { hours, label in
            Button(label) { Task { await update(hours: hours) } }
          }
          if status?.muted == true { Button("Turn notifications on") { Task { await update(hours: 0) } } }
        }.disabled(busy || status == nil)
        if let error { Section { Text(error).foregroundStyle(Palette.secondary); Button("Retry") { Task { await load() } }.disabled(busy) } }
      }.scrollContentBackground(.hidden).appBackground().navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .task { await load() }
    }
  }
  private func load() async { await request(action: "get", hours: nil) }
  private func update(hours: Int) async { await request(action: "set", hours: hours) }
  private func request(action: String, hours: Int?) async {
    guard !busy else { return }; busy = true; error = nil; defer { busy = false }
    do {
      guard !store.fixtureMode else { throw SocialServiceError(error: "Notification settings require a connected account.", code: "unavailable") }
      var payload: [String: Any] = ["room_id": roomID]; if let hours { payload["hours"] = hours }
      let data = try await store.social.sendData(endpoint: "room-preferences", action: action, payload: payload)
      status = try JSONDecoder().decode(RoomMuteStatus.self, from: data)
    } catch { self.error = error.localizedDescription }
  }
}

struct RoomMuteStatus: Decodable { let muted: Bool; let mutedUntil: Double?
  enum CodingKeys: String, CodingKey { case muted; case mutedUntil = "muted_until" }
}
