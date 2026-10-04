import SwiftUI
import UserNotifications

struct PushSettingsView: View {
  @State private var service = PushService.shared
  var body: some View {
    List {
      Section {
        Label(service.registered ? "This device is registered" : "Device notifications", systemImage: "bell.badge")
        if !service.configured { Text("Push delivery is waiting for the app owner’s Apple signing-key setup. Preferences are saved now.").font(.caption).foregroundStyle(Palette.secondary) }
        if service.authorization == .notDetermined { Button("Allow notifications") { Task { await service.enable() } } }
        else if service.authorization == .denied {
          Button("Open iPhone notification settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
        }
        Text("Lock-screen alerts show only the type of activity. Names and message text stay inside the app.").font(.caption).foregroundStyle(Palette.secondary)
      }
      Section("Notify me about") {
        preference("Notifications", \.enabled)
        preference("Messages and requests", \.messages)
        preference("Game invitations and turns", \.games)
        preference("Calls", \.calls)
        preference("Replies and activity", \.activity)
      }.disabled(service.busy)
      if let error = service.error { Section { Text(error).foregroundStyle(Palette.secondary); Button("Retry") { Task { await service.refresh() } } } }
    }.scrollContentBackground(.hidden).appBackground().navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
      .task { await service.refresh() }
  }
  private func preference(_ label: String, _ key: WritableKeyPath<PushPreferences, Bool>) -> some View {
    Toggle(label, isOn: Binding(get: { service.preferences[keyPath: key] }, set: { value in
      var preferences = service.preferences; preferences[keyPath: key] = value
      Task { await service.update(preferences) }
    })).tint(Palette.maroon)
  }
}
