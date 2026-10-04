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
      } else { PostDetailView(id: id) }
    }.task { if lease == nil { lease = store.openLibraryScope(query); await load() } }
  }
  private func load() async { loading = true; await store.loadLibraryPage(query); loading = false }
}
