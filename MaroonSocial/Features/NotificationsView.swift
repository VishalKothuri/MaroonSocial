import SwiftUI

struct NotificationsBell: View {
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  @State private var model = NotificationsModel()
  @State private var presented = false
  @State private var selectedPost: NotificationPost?
  private struct NotificationPost: Identifiable { let id: String }
  var body: some View {
    Button { AppHaptics.shared.play(.selection); presented.toggle() } label: {
      Image(systemName: presented ? "bell.fill" : "bell")
        .font(.system(size: 20, weight: .semibold)).frame(width: 44, height: 44)
        .overlay(alignment: .topTrailing) {
          if model.unreadCount > 0 {
            Text(model.unreadCount > 99 ? "99+" : "\(model.unreadCount)").font(.system(size: 10, weight: .bold)).monospacedDigit()
              .foregroundStyle(Palette.onAccent).padding(.horizontal, 4).frame(minWidth: 16, minHeight: 16)
              .background(Palette.maroon, in: Capsule()).offset(x: 2, y: 1).accessibilityHidden(true)
          }
        }
    }.accessibilityLabel("Notifications").accessibilityValue(model.unreadCount == 0 ? "No unread notifications" : "\(model.unreadCount) unread")
      .accessibilityIdentifier("notificationsBell")
      .popover(isPresented: $presented, arrowEdge: .top) {
        NotificationsPanel(model: model) { group in
          Task { _ = await model.markRead(group, using: store.social, fixture: store.fixtureMode) }
          if let postID = group.postID { presented = false; selectedPost = NotificationPost(id: postID) }
        }
        .frame(idealWidth: 340, maxWidth: 360, idealHeight: 440, maxHeight: 520)
        .presentationCompactAdaptation(.popover)
        .task { if !store.fixtureMode { await model.refresh(using: store.social) } }
      }
      .sheet(item: $selectedPost) { post in
        NavigationStack {
          LibraryPostDestination(id: post.id)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { selectedPost = nil } label: { Image(systemName: "xmark") }.accessibilityLabel("Close post") } }
        }
      }
      .task(id: store.state.username) {
        model.reset()
        if store.fixtureMode {
          if ProcessInfo.processInfo.arguments.contains("--uitesting-notifications") { model.loadFixture(postID: "demo-coffee-post") }
          return
        }
        while !Task.isCancelled {
          if scenePhase == .active && store.connected { await model.refresh(using: store.social) }
          do { try await Task.sleep(for: .seconds(15)) } catch { break }
        }
      }
  }
}

private struct NotificationsPanel: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let model: NotificationsModel
  let select: (NotificationGroup) -> Void
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Notifications").font(.headline)
        Spacer()
        Button { dismiss() } label: { Image(systemName: "xmark").font(.subheadline.weight(.semibold)).frame(width: 36, height: 36) }.accessibilityLabel("Close notifications")
      }.padding(.leading, 16).padding(.trailing, 6).padding(.top, 6)
      if model.items.contains(where: { !$0.read }) {
        Button("Mark as read") { Task {
          if store.fixtureMode { for group in model.groups { await model.markRead(group, using: store.social, fixture: true) }; return }
          if await model.markAllRead(using: store.social) { AppHaptics.shared.play(.success) }
          else if model.error != nil { AppHaptics.shared.play(.error) }
        } }
          .font(.caption.weight(.semibold)).frame(maxWidth: .infinity, alignment: .trailing).padding(.horizontal, 16).padding(.bottom, 10).disabled(model.updating)
      }
      Divider()
      ScrollView {
        LazyVStack(spacing: 0) {
          if let error = model.error {
            VStack(spacing: 10) {
              Text(error).font(.caption).foregroundStyle(.secondary)
              Button("Try again") { Task { await model.refresh(using: store.social) } }.font(.subheadline)
            }.padding(16)
          }
          if model.loading && model.items.isEmpty { ProgressView().padding(32) }
          else if model.items.isEmpty && model.error == nil {
            VStack(spacing: 12) {
              Image(systemName: "bell.badge").font(.system(size: 30)).foregroundStyle(.secondary)
              Text("You’re all caught up").font(.headline)
              Text("Comments, upvote milestones, and announcements will appear here.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(.horizontal, 22).padding(.vertical, 38)
          }
          ForEach(model.groups) { group in
            Button { AppHaptics.shared.play(.selection); select(group) } label: { NotificationRow(group: group, snippet: snippet(group)) }
              .buttonStyle(.plain).accessibilityIdentifier("notification_\(group.id)")
            Divider().padding(.leading, 52)
          }
        }
      }.refreshable { if !store.fixtureMode { await model.refresh(using: store.social) } }
    }.background(Palette.paper).accessibilityIdentifier("notificationsPanel")
  }
  /// One line of the post the notification is about, when this device holds it.
  private func snippet(_ group: NotificationGroup) -> String? {
    guard let id = group.postID, let post = store.state.posts.first(where: { $0.id == id }), post.deleted != true else { return nil }
    let text = post.text.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
  }
}

/// A notification row: the kind's glyph, the (grouped) title, the newest comment, a line of your post,
/// and an unread tint.
struct NotificationRow: View {
  let group: NotificationGroup
  let snippet: String?
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  private var tint: Color {
    switch group.kind {
    case .comment: return Color(hex: "#93C5FD") ?? Palette.ink
    case .reply: return Color(hex: "#5EEAD4") ?? Palette.ink
    case .upvotes: return Palette.maroonBright
    case .announcement: return Color(hex: "#FDE047") ?? Palette.ink
    }
  }
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: group.newest.symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(tint)
        .frame(width: 30, height: 30).background(tint.opacity(0.14), in: Circle()).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(group.title).font(.subheadline.weight(group.read ? .medium : .bold)).fixedSize(horizontal: false, vertical: true)
        if !group.body.isEmpty {
          // The whole comment, as before grouping: a line limit leaves a few words at accessibility sizes.
          Text(group.body).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        if let snippet {
          Text("\(group.kind == .reply ? "In" : "On") “\(snippet)”").font(.caption).foregroundStyle(Palette.secondary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            .accessibilityIdentifier("notificationSnippet")
        }
        Text(group.created, style: .relative).font(.caption).foregroundStyle(.secondary)
      }.frame(maxWidth: .infinity, alignment: .leading)
      if !group.read { Circle().fill(Palette.maroonBright).frame(width: 8, height: 8).padding(.top, 6).accessibilityHidden(true) }
    }.foregroundStyle(Palette.ink).padding(16)
      .background(group.read ? Color.clear : Palette.maroon.opacity(0.22))
      .contentShape(Rectangle())
      .accessibilityElement(children: .combine)
      .accessibilityValue(group.read ? "" : "Unread")
  }
}
