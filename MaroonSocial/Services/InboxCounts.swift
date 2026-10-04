import Foundation
import MaroonCore

enum InboxCategory: String, CaseIterable, Identifiable {
  case messages = "Messages", requests = "Requests", groups = "Groups"
  var id: String { rawValue }
  var accessibilityID: String { "inbox" + rawValue }
}

/// One room belongs to exactly one category. An actionable invitation counts
/// once, regardless of unread messages inside that pending conversation.
struct InboxCounts: Equatable {
  struct Entry: Equatable {
    let category: InboxCategory
    let badge: Int
    let incomingRequest: Bool
  }
  private(set) var entries: [String: Entry] = [:]
  var messages: Int { count(.messages) }
  var requests: Int { count(.requests) }
  var groups: Int { count(.groups) }
  var total: Int { messages + requests + groups }

  init(conversations: [Conversation], metadata: [String: SocialConversationMeta], fixtureMode: Bool = false) {
    for chat in conversations where entries[chat.id] == nil {
      let meta = metadata[chat.id]
      let pending = chat.request || meta?.pendingOutgoing == true || meta?.status == "pending"
      if pending && meta?.status == "closed" { continue }
      let incoming = pending && chat.request && meta?.pendingOutgoing != true
      let category: InboxCategory = pending ? .requests : meta?.kind == "group" ? .groups : .messages
      let count: Int
      if let meta {
        if meta.status == "closed" { count = 0 }
        else if pending { count = incoming ? 1 : 0 }
        else { count = meta.status == "active" ? max(0, meta.unread) : 0 }
      } else { count = fixtureMode && incoming ? 1 : 0 }
      entries[chat.id] = Entry(category: category, badge: count, incomingRequest: incoming)
    }
  }
  func count(_ category: InboxCategory) -> Int {
    entries.values.filter { $0.category == category }.reduce(0) { $0 + $1.badge }
  }
}

extension AppStore {
  var inboxCounts: InboxCounts {
    InboxCounts(conversations: state.conversations.filter { canAccessConversation($0.id) }, metadata: conversationMeta, fixtureMode: fixtureMode)
  }
}
