import MaroonCore
import SwiftUI

/// The home feed's topic row: underline text tabs ("All", the shown topics, then "More", which opens
/// the topic sheet with the sort and every topic).
/// It draws the header's hairline along its bottom edge; the selected tab's underline sits on it.
/// Callers cap Dynamic Type at the call site (`.dynamicTypeSize(...DynamicTypeSize.accessibility2)`):
/// the strip's own @ScaledMetric sizes read the environment it is created in, so a cap inside its
/// body would stop the labels but not the emoji, gaps, underline and fades.
struct TopicTabStrip: View {
  /// Shown tabs, in catalog order.
  let topics: [Topic]
  /// Quiet topics folded into "More".
  let more: [Topic]
  /// nil = All.
  @Binding var selection: String?
  /// A tap on the selected tab: scroll the feed to the top.
  var onReselect: () -> Void
  /// Every active topic (with counts) for the topic sheet; the shown and folded tabs when empty.
  var allTopics: [Topic] = []
  /// The feed's New/Hot, which the topic sheet also sets.
  var sort: Binding<String> = .constant("New")
  @State private var sheet = false
  @Namespace private var underline
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.displayScale) private var displayScale
  @ScaledMetric(relativeTo: .callout) private var emojiSize: CGFloat = 15
  @ScaledMetric(relativeTo: .callout) private var gap: CGFloat = TopicMetrics.tabGap
  @ScaledMetric(relativeTo: .callout) private var underlineHeight: CGFloat = TopicMetrics.underline
  @ScaledMetric(relativeTo: .callout) private var fade: CGFloat = TopicMetrics.edgeFade
  /// How far the content extends past each side, capped at `fade`.
  @State private var edges = Edges()
  struct Edges: Equatable { var leading: CGFloat = 0; var trailing: CGFloat = 0 }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        // Bottom-aligned, so every tab's underline lands on the hairline whatever its height.
        HStack(alignment: .bottom, spacing: gap) {
          tab(nil, emoji: nil, title: "All", tint: Palette.maroonBright)
          ForEach(topics) { topic in tab(topic.slug, emoji: topic.emoji, title: topic.title, tint: topic.textColor) }
          moreButton
        }.padding(.horizontal, 16)
      }
      .scrollIndicators(.hidden)
      // Always bounces, so the root-tab and New/Hot swipes leave drags on the strip alone.
      .scrollBounceBehavior(.always, axes: .horizontal)
      .onScrollGeometryChange(for: Edges.self) { geometry in
        Edges(leading: min(fade, max(0, geometry.contentOffset.x)),
          trailing: min(fade, max(0, geometry.contentSize.width - geometry.containerSize.width - geometry.contentOffset.x)))
      } action: { _, value in edges = value }
      .mask(HStack(spacing: 0) {
        LinearGradient(colors: [.black.opacity(1 - edges.leading / max(1, fade)), .black], startPoint: .leading, endPoint: .trailing).frame(width: fade)
        Color.black
        LinearGradient(colors: [.black, .black.opacity(1 - edges.trailing / max(1, fade))], startPoint: .leading, endPoint: .trailing).frame(width: fade)
      })
      .background(alignment: .bottom) { Rectangle().fill(Palette.border).frame(height: 1 / displayScale).accessibilityHidden(true) }
      .onAppear {
        var transaction = Transaction(animation: nil); transaction.disablesAnimations = true
        withTransaction(transaction) { proxy.scrollTo(selection ?? "all", anchor: .center) }
      }
      .onChange(of: selection) { _, value in
        withAnimation(reduceMotion ? nil : .snappy) { proxy.scrollTo(value ?? "all", anchor: .center) }
      }
      // A topic picked from More is inserted into the strip in the same update that selects it, and
      // the strip's width grows with the insertion animation; a scroll issued then stops short of the
      // new tab. Scroll again once the insertion has settled.
      .onChange(of: topics.map(\.slug)) { _, _ in
        guard let value = selection else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.05 : 0.35)) {
          withAnimation(reduceMotion ? nil : .snappy) { proxy.scrollTo(value, anchor: .center) }
        }
      }
    }
    .frame(minHeight: 44)
    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86), value: selection)
    .accessibilityElement(children: .contain).accessibilityIdentifier("topicStrip")
  }
  private func tab(_ slug: String?, emoji: String?, title: String, tint: Color) -> some View {
    let on = selection == slug
    return Button {
      AppHaptics.shared.play(.selection)
      if on { onReselect() } else { selection = slug }
    } label: {
      HStack(spacing: 5) {
        if let emoji { Text(emoji).font(.system(size: emojiSize)) }
        Text(title)
      }
      .font(.callout.weight(.semibold)).foregroundStyle(on ? Palette.ink : Palette.secondary)
      .lineLimit(1).fixedSize()
      .padding(.vertical, 6).frame(minHeight: 44)
      // Bottom edge = row bottom = the hairline.
      .overlay(alignment: .bottom) {
        if on {
          Capsule().fill(tint).frame(height: underlineHeight).padding(.horizontal, -8)
            .matchedGeometryEffect(id: "underline", in: underline)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain).id(slug ?? "all")
    .accessibilityLabel(slug == nil ? "All topics" : "\(title) topic")
    .accessibilityAddTraits(on ? .isSelected : [])
    .accessibilityIdentifier("topicTab-\(slug ?? "all")")
  }
  private var moreButton: some View {
    Button { AppHaptics.shared.play(.impact); sheet = true } label: {
      HStack(spacing: 4) { Text("More"); Image(systemName: "chevron.down").font(.caption.bold()) }
        .font(.callout.weight(.semibold)).foregroundStyle(Palette.secondary).fixedSize().frame(minHeight: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain).id("more")
    .accessibilityLabel("More topics").accessibilityHint("Shows the sort and every topic")
    .accessibilityIdentifier("topicTab-more")
    .sheet(isPresented: $sheet) {
      TopicSheet(topics: allTopics.isEmpty ? TopicCatalog.active(topics + more) : allTopics, selection: $selection, sort: sort)
    }
  }
}

/// A post's topic pill: emoji and title-case label in the topic's text tone on its fill.
struct TopicTag: View {
  let topic: Topic
  @ScaledMetric(relativeTo: .caption) private var emojiSize: CGFloat = 11
  @ScaledMetric(relativeTo: .caption) private var height: CGFloat = TopicMetrics.tagHeight
  var body: some View {
    HStack(spacing: 4) {
      Text(topic.emoji).font(.system(size: emojiSize))
      Text(topic.title).font(.caption.weight(.semibold))
    }
    .lineLimit(1).padding(.horizontal, 8).frame(minHeight: height)
    .foregroundStyle(topic.textColor).background(topic.fillColor, in: Capsule())
    .fixedSize()
  }
}

/// A pill that does something: in the home feed it selects that tab (`onSelect`); anywhere else it
/// pushes the topic's feed. The 44 pt hit area does not change the header's layout.
/// `interactive: false` draws a plain tag: a topic the catalog no longer lists (its feed would be
/// refused) or the topic of the feed the post is shown in.
struct TopicTagButton: View {
  let topic: Topic
  let community: Community
  var onSelect: ((String) -> Void)? = nil
  var interactive = true
  var body: some View {
    if interactive { button } else {
      TopicTag(topic: topic)
        .accessibilityElement(children: .ignore).accessibilityLabel("\(topic.title) topic").accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("topicTag-\(topic.slug)")
    }
  }
  private var button: some View {
    Group {
      if let onSelect {
        Button { AppHaptics.shared.play(.selection); onSelect(topic.slug) } label: { label }
      } else {
        NavigationLink { TopicFeedView(topic: topic.slug, community: community).appHapticOnOpen().toolbar(.visible, for: .navigationBar) } label: { label }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(topic.title) topic")
    .accessibilityHint(onSelect == nil ? "Opens \(topic.title) posts" : "Shows \(topic.title) posts")
    .accessibilityIdentifier("topicTag-\(topic.slug)")
  }
  private var label: some View {
    TopicTag(topic: topic).padding(.vertical, 11).contentShape(Rectangle()).padding(.vertical, -11)
  }
}

/// A composer chip: 32 pt visual inside a 44 pt tap target.
struct TopicChip: View {
  let topic: Topic
  let selected: Bool
  let action: () -> Void
  @ScaledMetric(relativeTo: .caption) private var height: CGFloat = TopicMetrics.chipHeight
  @ScaledMetric(relativeTo: .caption) private var emojiSize: CGFloat = 15
  var body: some View {
    Button(action: action) {
      HStack(spacing: 5) {
        Text(topic.emoji).font(.system(size: emojiSize))
        Text(topic.title).font(.caption.weight(.semibold))
      }
      .lineLimit(1).fixedSize()
      .padding(.horizontal, 12).frame(minHeight: height)
      .foregroundStyle(Palette.ink)
      .background(selected ? topic.fillColor : Palette.elevated, in: Capsule())
      .overlay(Capsule().strokeBorder(selected ? topic.textColor : Palette.border, lineWidth: selected ? 1 : 0.75))
      .frame(minHeight: 44).contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(topic.title) topic")
    .accessibilityAddTraits(selected ? .isSelected : [])
    .accessibilityIdentifier("postTopic-\(topic.slug)")
  }
}

/// The composer's topic row (one topic per post; tapping the selected chip clears it).
/// A topic chosen outside the row (the browsed tab, "Post in <topic>", a quote, a restored draft) is
/// scrolled into view, so the member always sees the topic Send will use.
struct TopicChipRow: View {
  let topics: [Topic]
  @Binding var selection: String?
  /// The last selection made by tapping a chip (already in view, so not scrolled).
  @State private var tapped: String??
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ScrollViewReader { proxy in
        ScrollView(.horizontal) {
          HStack(spacing: 8) {
            ForEach(topics) { topic in
              TopicChip(topic: topic, selected: selection == topic.slug) {
                AppHaptics.shared.play(.selection)
                let next = selection == topic.slug ? nil : topic.slug
                tapped = .some(next); selection = next
              }.id(topic.slug)
            }
          }
        }.scrollIndicators(.hidden).scrollBounceBehavior(.always, axes: .horizontal)
          .accessibilityIdentifier("postTopics")
          .onAppear { reveal(selection, proxy) }
          .onChange(of: selection) { _, value in
            if tapped == .some(value) { tapped = nil } else { reveal(value, proxy) }
          }
      }
      if selection == nil {
        Text("Pick a topic").font(.caption).foregroundStyle(Palette.secondary).accessibilityIdentifier("postTopicHint")
      } else if TopicCatalog.needsGuardrail(selection) {
        Label(TopicCatalog.guardrailCopy, systemImage: "hand.raised").font(.caption).foregroundStyle(Palette.secondary)
          .accessibilityIdentifier("postTopicGuardrail")
      }
    }
  }
  /// Centres the chosen chip without animation, once the row has been laid out.
  private func reveal(_ slug: String?, _ proxy: ScrollViewProxy) {
    guard let slug else { return }
    DispatchQueue.main.async {
      var transaction = Transaction(animation: nil); transaction.disablesAnimations = true
      withTransaction(transaction) { proxy.scrollTo(slug, anchor: .center) }
    }
  }
}

/// A topic with nothing to show yet, with a way to start it.
struct TopicEmptyState: View {
  let topic: Topic
  let onPost: () -> Void
  var body: some View {
    VStack(spacing: 0) {
      EmptyCard(icon: "bubble.left.and.bubble.right", title: "No \(topic.emoji) \(topic.title) posts yet",
        detail: "Start the first \(topic.title) conversation in this community.")
      Button("Post in \(topic.title)") { AppHaptics.shared.play(.impact); onPost() }
        .buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent)
        .accessibilityIdentifier("postInTopic")
    }
  }
}

/// One topic's feed, pushed from a pill outside the home feed (threads, library, tag results).
struct TopicFeedView: View {
  @Environment(AppStore.self) private var store
  let topic: String
  let community: Community
  @State private var conversationID: String?
  private var key: FeedKey { FeedKey(community: community, topic: topic) }
  private var display: Topic { store.topicDisplay(topic) }
  private var entry: FeedKeyState { store.feedState(for: key) }
  private var posts: [Post] {
    let ids = store.feedIDs(for: key)
    return store.state.posts.filter {
      (ids?.contains($0.id) ?? true) && $0.community == community && $0.topic == topic
        && $0.deleted != true && !store.state.hiddenPosts.contains($0.id)
    }.sorted { $0.created > $1.created }
  }
  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 8) { TopicTag(topic: display); Text(community.rawValue).font(.caption).foregroundStyle(Palette.secondary) }
          .padding(16).accessibilityElement(children: .combine).accessibilityIdentifier("topicFeedHeader")
        // Every post here has this feed's topic, so its pill is a plain tag.
        ForEach(posts) { post in PostCard(post: post, onConversationCreated: { conversationID = $0 }, topicPillInteractive: false) }
        if posts.isEmpty, let error = entry.error {
          EmptyCard(icon: "wifi.exclamationmark", title: "Posts couldn’t load", detail: error)
          Button("Retry") { Task { await store.loadTopicFeed(key, reset: true) } }.buttonStyle(.borderedProminent).tint(Palette.maroon)
            .foregroundStyle(Palette.onAccent).padding(16).frame(maxWidth: .infinity).accessibilityIdentifier("topicRetry")
        } else if posts.isEmpty && entry.showsLoading {
          LoadingWordmark(size: 24).frame(maxWidth: .infinity).padding(24).accessibilityLabel("Loading \(display.title)")
        } else if posts.isEmpty {
          EmptyCard(icon: "bubble.left.and.bubble.right", title: "No \(display.emoji) \(display.title) posts yet", detail: "Nothing here in \(community.rawValue) yet.")
        } else if entry.cursor != nil {
          Button { Task { await store.loadMoreFeed(for: key) } } label: {
            HStack(spacing: 8) {
              if store.loadingMoreFeed { ProgressView().controlSize(.small) }
              Text("Load more posts").font(.subheadline.bold())
            }.frame(maxWidth: .infinity, minHeight: 44)
          }.buttonStyle(ControlPressStyle()).foregroundStyle(Palette.accentText).disabled(store.loadingMoreFeed)
            .frame(maxWidth: .infinity, minHeight: 56).accessibilityIdentifier("topicLoadMore")
        }
      }
    }.maroonRefreshable { await store.loadTopicFeed(key, reset: true) }
      .appBackground().navigationTitle(display.title).navigationBarTitleDisplayMode(.inline)
      .navigationDestination(item: $conversationID) { ChatView(id: $0).toolbar(.visible, for: .navigationBar) }
      .task(id: key) { await store.loadTopicFeed(key) }
  }
}

/// The feed's report menu: one tap picks the reason that is sent.
struct PostReportDialog: ViewModifier {
  @Environment(AppStore.self) private var store
  @Binding var post: Post?
  func body(content: Content) -> some View {
    content.confirmationDialog("Why are you reporting this post?", isPresented: Binding(get: { post != nil }, set: { if !$0 { post = nil } }), titleVisibility: .visible, presenting: post) { target in
      ForEach(PostReportReason.options(topicsAvailable: store.topicsAvailable, postHasTopic: target.topic != nil), id: \.self) { reason in
        Button(reason, role: .destructive) { AppHaptics.shared.play(.warning); store.report(target.id, reason: reason) }
          .accessibilityIdentifier("reportReason-\(reason)")
      }
      Button("Cancel", role: .cancel) {}
    } message: { _ in Text("Moderators review every report.") }
  }
}
