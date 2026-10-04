import Foundation
import Observation

struct SocialNotification: Decodable, Identifiable, Equatable {
  enum Kind: String, Decodable { case comment, reply, upvotes, announcement }
  var id: String
  var kind: Kind
  var title: String
  var body: String
  var postID: String?
  var created: Date
  var read: Bool
  var symbol: String {
    switch kind {
    case .comment, .reply: return "bubble.left.and.bubble.right"
    case .upvotes: return "arrow.up.circle"
    case .announcement: return "megaphone"
    }
  }
}
struct NotificationInbox: Decodable {
  var items: [SocialNotification]
  var unreadCount: Int
}
@Observable @MainActor final class NotificationsModel {
  private(set) var items: [SocialNotification] = []
  private(set) var unreadCount = 0
  private(set) var loading = false
  private var pendingWrites = 0
  var updating: Bool { pendingWrites > 0 }
  private var mutationRevision = 0
  var error: String?
  private var generation = 0
  func reset() { generation += 1; items = []; unreadCount = 0; loading = false; pendingWrites = 0; mutationRevision = 0; error = nil }
  func refresh(using social: SocialService) async {
    guard !loading, !updating else { return }
    let epoch = generation
    let revision = mutationRevision
    loading = true
    defer { if epoch == generation { loading = false } }
    do {
      let data = try await social.sendData(endpoint: "social", action: "notifications")
      try Task.checkCancellation()
      guard epoch == generation, revision == mutationRevision else { return }
      let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
      let result = try decoder.decode(NotificationInbox.self, from: data)
      items = result.items; unreadCount = result.unreadCount; error = nil
    } catch {
      if epoch == generation, revision == mutationRevision, !(error is CancellationError), !Task.isCancelled { self.error = error.localizedDescription }
    }
  }
  @discardableResult func markRead(_ notification: SocialNotification, using social: SocialService) async -> Bool {
    guard !notification.read else { return true }
    return await acknowledge(ids: [notification.id], action: "notification.read", social: social)
  }
  @discardableResult func markAllRead(using social: SocialService) async -> Bool {
    let ids = items.filter { !$0.read }.map(\.id)
    guard !ids.isEmpty else { return false }
    return await acknowledge(ids: ids, action: "notifications.read_all", social: social)
  }
  private func acknowledge(ids: [String], action: String, social: SocialService) async -> Bool {
    let epoch = generation
    mutationRevision += 1
    pendingWrites += 1
    defer { if epoch == generation { pendingWrites -= 1 } }
    do {
      let payload: [String: Any] = action == "notification.read" ? ["id": ids[0]] : ["ids": ids]
      _ = try await social.sendData(endpoint: "social", action: action, payload: payload)
      try Task.checkCancellation()
      guard epoch == generation else { return false }
      let acknowledged = Set(ids)
      let count = items.filter { acknowledged.contains($0.id) && !$0.read }.count
      for index in items.indices where acknowledged.contains(items[index].id) { items[index].read = true }
      unreadCount = max(0, unreadCount - count); error = nil
      return true
    } catch {
      if epoch == generation, !(error is CancellationError), !Task.isCancelled { self.error = error.localizedDescription }
      return false
    }
  }
}
