import SwiftUI

struct PendingMessagesView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let roomID: String?
  private var messages: [QueuedMessage] { store.compositions.queue.filter { roomID == nil || $0.roomID == roomID } }
  var body: some View {
    NavigationStack {
      List {
        Section {
          Text("Queued messages send when this app is open and connected. You can cancel a message before sending begins.").font(.caption).foregroundStyle(Palette.secondary)
        }
        if messages.isEmpty { Text("No unsent messages").foregroundStyle(Palette.secondary).accessibilityIdentifier("outboxEmpty") }
        ForEach(messages) { message in
          Section {
            if roomID == nil { Text(store.state.conversations.first { $0.id == message.roomID }?.title ?? "Conversation unavailable").font(.headline) }
            if !message.text.isEmpty { Text(message.text).lineLimit(5) }
            if let media = message.media { Label(media.kind == .video ? "Video" : media.kind == .gif ? "GIF" : "Photo", systemImage: media.kind == .video ? "video" : "photo").font(.caption) }
            if store.sendingQueuedID == message.id { Label("Sending…", systemImage: "arrow.up.circle").font(.caption) }
            else if let failure = message.failure { Text(failure).font(.caption).foregroundStyle(Palette.secondary) }
            else { Label("Waiting to send", systemImage: "clock").font(.caption) }
            HStack {
              Button("Retry now") { Task { await store.retryQueuedMessage(message.id) } }.disabled(!store.connected || store.connectionError != nil)
              Spacer()
              Button("Cancel send", role: .destructive) { Task { await store.cancelQueuedMessage(message.id) } }
            }.disabled(store.sendingQueuedID == message.id)
          }.accessibilityIdentifier("outboxMessage-" + message.id)
        }
        if let error = store.compositions.error { Text(error).font(.caption).foregroundStyle(Palette.secondary) }
      }.scrollContentBackground(.hidden).appBackground().navigationTitle("Unsent messages").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }
}
