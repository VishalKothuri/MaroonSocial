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
        NotificationsPanel(model: model) { notification in
          Task { _ = await model.markRead(notification, using: store.social) }
          if let postID = notification.postID { presented = false; selectedPost = NotificationPost(id: postID) }
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
        guard !store.fixtureMode else { return }
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
  let select: (SocialNotification) -> Void
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Notifications").font(.headline)
        Spacer()
        Button { dismiss() } label: { Image(systemName: "xmark").font(.subheadline.weight(.semibold)).frame(width: 36, height: 36) }.accessibilityLabel("Close notifications")
      }.padding(.leading, 16).padding(.trailing, 6).padding(.top, 6)
      if model.items.contains(where: { !$0.read }) {
        Button("Mark as read") { Task {
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
          ForEach(model.items) { notification in
            Button { AppHaptics.shared.play(.selection); select(notification) } label: {
              HStack(alignment: .top, spacing: 12) {
                Image(systemName: notification.symbol).font(.system(size: 18)).frame(width: 24).padding(.top, 3)
                VStack(alignment: .leading, spacing: 6) {
                  Text(notification.title).font(.subheadline.weight(notification.read ? .medium : .bold))
                  Text(notification.body).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                  Text(notification.created, style: .relative).font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if !notification.read { Circle().fill(Palette.maroon).frame(width: 7, height: 7).padding(.top, 6) }
              }.foregroundStyle(Palette.ink).padding(16).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("notification_\(notification.id)")
            Divider().padding(.leading, 52)
          }
        }
      }.refreshable { if !store.fixtureMode { await model.refresh(using: store.social) } }
    }.background(Palette.paper).accessibilityIdentifier("notificationsPanel")
  }
}
