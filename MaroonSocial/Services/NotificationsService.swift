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
    case .comment: return "bubble.left.fill"
    case .reply: return "arrowshape.turn.up.left.fill"
    case .upvotes: return "arrow.up.circle.fill"
    case .announcement: return "megaphone.fill"
    }
  }
}
/// Same-kind notifications on the same post, newest first, shown as one row ("3 new comments on
/// your post"). The server writes one notification per reply and sends no author identity (replies
/// may be anonymous), so a group counts replies and never claims how many people wrote them.
struct NotificationGroup: Identifiable, Equatable {
  var items: [SocialNotification]
  var newest: SocialNotification { items[0] }
  var id: String { newest.id }
  var kind: SocialNotification.Kind { newest.kind }
  var postID: String? { newest.postID }
  var read: Bool { items.allSatisfy(\.read) }
  var unreadIDs: [String] { items.filter { !$0.read }.map(\.id) }
  var created: Date { newest.created }
  /// "3 new comments on your post", "2 new replies to you on this post"; a single notification keeps
  /// its own title.
  var title: String {
    guard items.count > 1 else { return newest.title }
    switch kind {
    case .comment: return "\(items.count) new comments on your post"
    case .reply: return "\(items.count) new replies to you on this post"
    case .upvotes: return newest.title
    case .announcement: return newest.title
    }
  }
  /// The newest comment, or the newest milestone ("Your post reached 25 upvotes.").
  var body: String { newest.body }
}
enum NotificationGrouping {
  /// Groups same-kind notifications on the same post, ordered by each group's newest item.
  /// Announcements (no post) stay one per row.
  static func group(_ items: [SocialNotification]) -> [NotificationGroup] {
    var groups: [NotificationGroup] = []
    var index: [String: Int] = [:]
    for item in items.sorted(by: { ($0.created, $0.id) > ($1.created, $1.id) }) {
      guard let post = item.postID, item.kind != .announcement else { groups.append(NotificationGroup(items: [item])); continue }
      let key = item.kind.rawValue + "|" + post
      if let position = index[key] { groups[position].items.append(item) }
      else { index[key] = groups.count; groups.append(NotificationGroup(items: [item])) }
    }
    return groups
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
  var groups: [NotificationGroup] { NotificationGrouping.group(items) }
  /// Fixture journeys (`--uitesting-notifications`): two replies and a comment-pair on one post, an
  /// upvote milestone and an announcement.
  func loadFixture(postID: String) {
    let now = Date.now
    items = [
      SocialNotification(id: "fixture-note-1", kind: .comment, title: "New comment on your post", body: "Count me in for the study room!", postID: postID, created: now.addingTimeInterval(-120), read: false),
      SocialNotification(id: "fixture-note-2", kind: .comment, title: "New comment on your post", body: "Same here, what time?", postID: postID, created: now.addingTimeInterval(-600), read: false),
      SocialNotification(id: "fixture-note-3", kind: .comment, title: "New comment on your post", body: "Bring snacks.", postID: postID, created: now.addingTimeInterval(-900), read: true),
      SocialNotification(id: "fixture-note-4", kind: .upvotes, title: "10 upvotes!", body: "Your post reached 10 upvotes.", postID: postID, created: now.addingTimeInterval(-3_600), read: true),
      SocialNotification(id: "fixture-note-5", kind: .announcement, title: "Announcement · Maroon Social", body: "Finals week: Evans is open 24 hours.", postID: nil, created: now.addingTimeInterval(-7_200), read: false),
    ]
    unreadCount = items.filter { !$0.read }.count
  }
  /// Marks every unread notification of a row read.
  @discardableResult func markRead(_ group: NotificationGroup, using social: SocialService, fixture: Bool = false) async -> Bool {
    let ids = group.unreadIDs
    guard !ids.isEmpty else { return true }
    if fixture {
      for index in items.indices where ids.contains(items[index].id) { items[index].read = true }
      unreadCount = max(0, unreadCount - ids.count); return true
    }
    return await acknowledge(ids: ids, action: ids.count == 1 ? "notification.read" : "notifications.read_all", social: social)
  }
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
