import MaroonCore
import SwiftUI

struct PersonalLibraryView: View {
  @Environment(AppStore.self) private var store
  let kind: SocialLibraryQuery.Kind
  @State private var leases: [LibraryPostLease] = []
  @State private var loading = false
  @State private var conversationID: String?
  private var queries: [SocialLibraryQuery] { leases.map(\.query) }
  private var title: String { kind == .comments ? "My comments" : kind == .saved ? "Saved posts" : "My posts" }
  private var icon: String { kind == .comments ? "bubble.left.and.bubble.right" : kind == .saved ? "bookmark" : "text.bubble" }
  private var error: String? { queries.compactMap { store.libraryPages[$0]?.error }.first }
  private var posts: [Post] {
    if !store.fixtureMode { return store.libraryPosts(queries) }
    return store.state.posts.filter { $0.deleted != true && !store.state.hiddenPosts.contains($0.id) && (kind == .saved ? $0.saved : store.owns($0)) }.sorted { $0.created > $1.created }
  }
  private var comments: [PersonalComment] {
    if store.fixtureMode {
      return store.state.posts.filter { $0.deleted != true && !store.state.hiddenPosts.contains($0.id) }.flatMap { post in
        post.comments.filter { store.owns($0) && $0.deleted != true }.map {
          PersonalComment(id: $0.id, postID: post.id, text: $0.text, created: $0.created, score: $0.score, anonymous: $0.anonymous, postText: post.text)
        }
      }.sorted { $0.created > $1.created }
    }
    let entries = queries.flatMap { store.libraryPages[$0]?.comments ?? [] }
    return Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest }).values.sorted { $0.created > $1.created }
  }
  var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        if kind == .comments {
          ForEach(comments) { comment in
            NavigationLink { PostDetailView(id: comment.postID) } label: {
              VStack(alignment: .leading, spacing: 10) {
                HStack {
                  Text(comment.anonymous ? "You · Anonymous" : "@\(store.state.username)").font(.caption.weight(.semibold))
                  Spacer()
                  Text(comment.created, style: .relative).font(.caption).foregroundStyle(.secondary)
                }
                Text(comment.text).font(.body).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                  Image(systemName: "arrow.turn.down.right")
                  Text(comment.postText).lineLimit(2)
                }.font(.caption).foregroundStyle(.secondary)
                HStack { Label("\(comment.score)", systemImage: "arrow.up").font(.caption); Spacer(); Text("View conversation").font(.caption); Image(systemName: "chevron.right").font(.caption) }
              }.padding(16).foregroundStyle(Palette.ink)
            }.buttonStyle(.plain).accessibilityIdentifier("myComment_\(comment.id)")
            Divider()
          }
        } else {
          ForEach(posts) { PostCard(post: $0, onConversationCreated: { conversationID = $0 }) }
        }
        if let error {
          VStack(spacing: 12) {
            Text(error).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Try again") { Task { await reload() } }.buttonStyle(.bordered)
          }.padding(24)
        } else if !loading && (kind == .comments ? comments.isEmpty : posts.isEmpty) {
          EmptyCard(icon: icon, title: kind == .comments ? "No comments yet" : kind == .saved ? "No saved posts" : "No posts yet", detail: kind == .comments ? "Your comments and replies appear here privately." : kind == .saved ? "Save a post from its menu to find it here." : "Posts you create appear here privately.")
        }
        if loading { ProgressView().padding(24).accessibilityLabel("Loading your collection") }
        if let last = queries.last, store.libraryPages[last]?.hasMore == true {
          Button("Load more") { Task { await loadPage(offset: last.offset + 50) } }.padding(20).disabled(loading)
        }
      }
    }.maroonRefreshable { await reload() }.appBackground().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
      .accessibilityIdentifier("personalLibrary_\(kind.rawValue)")
      .navigationDestination(item: $conversationID) { ChatView(id: $0).toolbar(.visible, for: .navigationBar) }
      .task { if leases.isEmpty { await loadPage(offset: 0) } }
  }
  private func loadPage(offset: Int) async {
    guard !loading else { return }
    loading = true; defer { loading = false }
    let query = SocialLibraryQuery(kind: kind, offset: offset)
    if !queries.contains(query) { leases.append(store.openLibraryScope(query)) }
    await store.loadLibraryPage(query)
  }
  private func reload() async {
    guard !loading else { return }
    if let first = queries.first {
      loading = true; defer { loading = false }
      await store.loadLibraryPage(first)
    } else { await loadPage(offset: 0) }
  }
}

/// Retains an older post while the live feed refreshes behind a notification.
struct LibraryPostDestination: View {
  @Environment(AppStore.self) private var store
  let id: String
  @State private var lease: LibraryPostLease?
  @State private var loading = true
  private var query: SocialLibraryQuery { SocialLibraryQuery(kind: .post, postID: id) }
  var body: some View {
    Group {
      if loading && !store.state.posts.contains(where: { $0.id == id }) { ProgressView("Loading post…").frame(maxWidth: .infinity, maxHeight: .infinity).appBackground() }
      else if let error = store.libraryPages[query]?.error {
        VStack(spacing: 16) {
          Text(error).multilineTextAlignment(.center)
          Button("Try again") { Task { await load() } }.buttonStyle(.bordered)
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).appBackground()
      } else if let reason = unavailable {
        PostUnavailableView(reason: reason)
      } else { PostDetailView(id: id) }
    }.task { if lease == nil { lease = store.openLibraryScope(query); await load() } }
  }
  /// Why the post can't be shown (a link or notification to a post that is gone, whose author is
  /// blocked, or that sits in a community the member can't see), or nil while it can.
  private var unavailable: PostUnavailableView.Reason? {
    guard !loading else { return nil }
    let held = store.state.posts.first { $0.id == id }
    if store.state.hiddenPosts.contains(id) { return .hidden }
    if store.fixtureMode {
      guard let held else { return .unavailable }
      if held.deleted == true { return .deleted }
      return held.community == .nsfw && !store.nsfwEnabled ? .unavailable : nil
    }
    // The server's answer decides: it lists the post only while this member can read it.
    guard let page = store.libraryPages[query], page.error == nil else { return nil }
    guard let post = page.posts.first(where: { $0.id == id }) else { return held?.deleted == true ? .deleted : .unavailable }
    return post.deleted == true ? .deleted : nil
  }
  private func load() async { loading = true; await store.loadLibraryPage(query); loading = false }
}

/// A post a link or notification pointed at that this member can't open.
struct PostUnavailableView: View {
  enum Reason: Equatable { case deleted, hidden, unavailable }
  let reason: Reason
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: reason == .hidden ? "eye.slash" : "exclamationmark.bubble").font(.system(size: 34, weight: .semibold))
        .foregroundStyle(Palette.secondary).accessibilityHidden(true)
      Text(title).font(.headline).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
      Text(detail).font(.callout).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }.padding(28).frame(maxWidth: 360).frame(maxWidth: .infinity, maxHeight: .infinity).appBackground()
      .accessibilityElement(children: .combine).accessibilityIdentifier("postUnavailable")
  }
  private var title: String {
    switch reason {
    case .deleted: return "This post was deleted"
    case .hidden: return "You hid this post"
    case .unavailable: return "This post isn’t available"
    }
  }
  private var detail: String {
    switch reason {
    case .deleted: return "Its author or a moderator removed it."
    case .hidden: return "You hid it on this device, so it stays out of your feed."
    case .unavailable: return "It may have been deleted, you may have blocked its author, or it’s in a community you haven’t joined."
    }
  }
}
