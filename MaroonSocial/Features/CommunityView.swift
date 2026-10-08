import MaroonCore
import PhotosUI
import SwiftUI

struct CommunityView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var community = Community.campus
  @State private var sort = "New"
  @State private var sortMovesForward = true
  @State private var feedWidth: CGFloat = 0
  @State private var compose = false
  /// Scroll tracking lives in a reference the view does not observe, so only a change of
  /// `chromeCollapsed` re-renders the feed. Writing every offset sample into @State re-ran the
  /// body on each lazy-layout correction, which could keep the feed relayouting indefinitely.
  @State private var chrome = FeedChromeTracker()
  @State private var chromeCollapsed = false
  @State private var headerHeight: CGFloat = 104
  @State private var tabBarHeight: CGFloat = 90
  @State private var interacting = false
  @State private var published = 0
  @State private var settings = false
  @State private var adultGate = false
  @State private var savedOnly = false
  @State private var search = ""
  @State private var showSearch = false
  @State private var conversationID: String?
  @State private var refreshPresentation = RefreshPresentation.idle
  /// Bumped to scroll the feed to the top without animation (a re-tapped tab, a tapped pill).
  @State private var scrollToTop = 0
  /// As a row appears, warm the media cache for the next ~10 posts (their own and quoted media).
  private func prefetchMedia(after post: Post) {
    guard !store.fixtureMode else { return }
    let list = posts
    guard let index = list.firstIndex(where: { $0.id == post.id }) else { return }
    let upcoming = list[(index + 1)..<min(list.count, index + 11)]
    let ids = upcoming.flatMap { [$0.attachmentID, $0.quote?.unavailable == true ? nil : $0.quote?.attachmentID].compactMap { $0 } }
    if !ids.isEmpty { store.social.prefetchAttachments(ids) }
  }
  /// The selected topic (nil = All). The store owns it so catalog drift can reset it.
  private var topic: String? { store.topicsAvailable ? store.feedTopic : nil }
  private var feedKey: FeedKey { FeedKey(community: community, topic: topic) }
  private var posts: [Post] {
    let ids = store.feedIDs(for: feedKey)
    // Client guard: a stale cached post never shows under the wrong topic.
    let feed = store.state.posts.filter { (ids?.contains($0.id) ?? true) && $0.community == community && (topic == nil || $0.topic == topic) }
      .sorted { $0.created > $1.created }
    // Hot ranks a fixed window of the newest posts, so pages loaded in New never re-rank older
    // posts above the reader (the store fills that window when Hot is chosen).
    let window = sort == "Hot" ? Array(feed.prefix(AppStore.hotWindow)) : feed
    let posts = window.filter {
      $0.deleted != true && !store.state.hiddenPosts.contains($0.id) && (!savedOnly || $0.saved)
        && (search.isEmpty || $0.text.localizedCaseInsensitiveContains(search))
    }
    return sort == "Hot" ? posts.sorted { rank($0) > rank($1) } : posts
  }
  private func rank(_ post: Post) -> Double {
    Double(post.score) / pow(max(1, Date.now.timeIntervalSince(post.created) / 3600) + 2, 1.4)
  }
  private var chromeInteractionLocked: Bool { compose || showSearch || settings || adultGate || dynamicTypeSize.isAccessibilitySize }
  private var collapsed: Bool { chromeCollapsed && !chromeInteractionLocked }
  var body: some View {
    VStack(spacing: 0) {
      SlidingFeedHeader(collapsed: collapsed, onHeightChange: { headerHeight = $0 }) {
        HStack(spacing: 4) {
          Button { AppHaptics.shared.play(.impact); withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { showSearch.toggle() }; if !showSearch { search = "" } } label: {
            Image(systemName: "magnifyingglass").font(.system(size: 19, weight: .semibold)).frame(width: 44, height: 44)
          }.accessibilityLabel("Search posts")
          // Mirror the bell + profile pair on the trailing side so the flexible
          // wordmark frame, and therefore the artwork, is centered on the screen.
          Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
          ViewThatFits(in: .horizontal) {
            LoadingWordmark(animating: false, size: 23)
            LoadingWordmark(animating: false, size: 19)
          }.offset(y: -44 * refreshPresentation.progress)
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44).clipped()
            .accessibilityIdentifier("communityHeaderWordmark").allowsHitTesting(false)
          NotificationsBell()
          Button { AppHaptics.shared.play(.impact); settings = true } label: {
            Image(systemName: "person.crop.circle").font(.system(size: 22, weight: .semibold)).frame(width: 44, height: 44)
          }.accessibilityLabel("Profile and settings")
        }.padding(.horizontal, 16).padding(.top, 2)
      (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
        Menu {
          ForEach(Community.campusCommunities) { value in
            Button(value.rawValue) { chooseCommunity(value) }
          }
          Button("NSFW · 18+ discussions") {
            if store.nsfwEnabled { chooseCommunity(.nsfw) } else { AppHaptics.shared.play(.impact); adultGate = true }
          }
          if community == .nsfw {
            Button("Leave NSFW", role: .destructive) {
              Task { if await store.mutate("community.leave", ["community": Community.nsfw.rawValue]) { chooseCommunity(.campus) } }
            }
          }
        } label: {
          HStack(spacing: 6) {
            Text(community.rawValue).fixedSize(horizontal: true, vertical: false)
            Image(systemName: "chevron.down").font(.caption.bold())
          }.font(.subheadline.bold()).frame(minWidth: dynamicTypeSize.isAccessibilitySize ? 0 : 138, minHeight: 44, alignment: .leading)
        }.id(community).transaction { $0.animation = nil }.accessibilityIdentifier("communityPicker").disabled(compose)
        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
        HStack(spacing: 8) {
          CompactSelector(options: ["New", "Hot"], selection: Binding(get: { sort }, set: chooseSort), compact: true)
          if dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
          Button { AppHaptics.shared.play(.impact); savedOnly.toggle() } label: {
          Image(systemName: savedOnly ? "bookmark.fill" : "bookmark").frame(width: 44, height: 44)
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
        }.buttonStyle(ControlPressStyle()).accessibilityLabel("Saved posts").accessibilityIdentifier("savedPostsFilter")
          .accessibilityAddTraits(savedOnly ? .isSelected : [])
          .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: savedOnly)
        }
      }.padding(.horizontal, 16).padding(.vertical, 6)
      if showSearch {
        HStack {
          Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
          TextField("Search posts", text: $search).autocorrectionDisabled().accessibilityIdentifier("postSearch")
          if !search.isEmpty { Button { AppHaptics.shared.play(.impact); search = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }.accessibilityLabel("Clear search") }
        }.frame(minHeight: 44).padding(11).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16).padding(.bottom, 10)
      }
      if store.topicsAvailable {
        // The strip draws the header's hairline itself; its underline sits on it.
        let folded = TopicCatalog.fold(store.topics, selected: topic)
        // The Dynamic Type cap is applied here, outside the strip, so it also reaches the strip's own
        // @ScaledMetric sizes (emoji, gaps, underline, fades), not only its child views.
        TopicTabStrip(topics: folded.shown, more: folded.more, selection: Binding(get: { topic }, set: chooseTopic), onReselect: scrollFeedToTop)
          .dynamicTypeSize(...DynamicTypeSize.accessibility2)
      } else {
        Divider()
      }
      }
      ScrollViewReader { proxy in
      // A sort or topic change replaces the whole scroll view, and the ZStack overlaps the outgoing
      // and incoming pages while they slide or cross-fade. The lazy stack stays the scroll view's
      // direct content: nested in another stack, SwiftUI sized it from estimates of whichever rows
      // were placed last, and a header collapse could flip that size on every pass (a layout loop).
      ZStack(alignment: .top) {
        feedPage(proxy)
          .id(topic ?? "all").transition(reduceMotion ? .identity : .opacity)
          .id(sort).transition(feedSortTransition)
          .task(id: sort == "Hot" ? "\(community.rawValue)#\(topic ?? "")#\(store.feedGeneration)" : nil) { if sort == "Hot" { await store.fillFeedForHot() } }
      }
      // Outside the pages, so the New/Hot swipe survives a page change (it re-attaches to the new page).
      .background(CommunitySortSwipeNavigation(selection: Binding(get: { sort }, set: chooseSort),
        enabled: !chromeInteractionLocked, page: "\(sort)#\(topic ?? "")").frame(width: 0, height: 0))
      }
    }.appBackground().navigationBarTitleDisplayMode(.inline)
      .toolbar(.hidden, for: .navigationBar)
      .background(SlidingFeedTabBar(hidden: collapsed && store.tab == 0, animated: !reduceMotion, onHeightChange: { tabBarHeight = $0 }).frame(width: 0, height: 0))
      .safeAreaInset(edge: .bottom, spacing: 0) {
        InlinePostComposer(community: community, expanded: $compose, browsedTopic: topic, onPublishedTopic: { posted in
          // A post that would not show under the current tab switches the feed to All.
          if let topic, posted != topic { chooseTopic(nil) }
        }) {
          resetChrome(); sort = "New"; savedOnly = false; search = ""; published += 1
        }
      }
      .onChange(of: chromeInteractionLocked) { _, locked in if locked { resetChrome() } }
      .onChange(of: store.tab) { _, _ in resetChrome() }
      // A topic change (a tab, a pill, or catalog drift back to All) opens a new page at the top.
      .onChange(of: topic) { _, _ in resetChrome() }
      .onDisappear { resetChrome(); interacting = false }
      .sheet(isPresented: $settings) { SettingsView() }
      .navigationDestination(item: $conversationID) { ChatView(id: $0).toolbar(.visible, for: .navigationBar) }
      .alert("18+ discussions", isPresented: $adultGate) {
        Button("Join community") {
          Task { if await store.mutate("community.join", ["community": Community.nsfw.rawValue]) { chooseCommunity(.nsfw) } }
        }
        Button("Cancel", role: .cancel) {}
      } message: { Text("Mature discussion is welcome. Nudity and explicit sexual media are not allowed. Your membership is private.") }
  }
  private var feedSortTransition: AnyTransition {
    guard !reduceMotion else { return .identity }
    return .asymmetric(
      insertion: .modifier(active: FeedPageSlide(distance: feedWidth, forward: $sortMovesForward, entering: true),
        identity: FeedPageSlide(distance: 0, forward: $sortMovesForward, entering: true)),
      removal: .modifier(active: FeedPageSlide(distance: feedWidth, forward: $sortMovesForward, entering: false),
        identity: FeedPageSlide(distance: 0, forward: $sortMovesForward, entering: false)))
  }
  /// One page of the feed (a sort and topic). Its lazy stack is the scroll view's direct content.
  private func feedPage(_ proxy: ScrollViewProxy) -> some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        Color.clear.frame(height: 0).id("feedTop")
        if community == .nsfw {
          Text("18+ discussion only. No explicit media.").font(.caption).foregroundStyle(.secondary).padding(12)
        }
        if posts.isEmpty && (topic == nil ? store.loadingCommunity : topicFeedLoading) {
          LoadingWordmark(size: 25).padding(.top, 24).accessibilityLabel("Loading \(topic.map { store.topicDisplay($0).title } ?? community.rawValue)")
        } else if posts.isEmpty, let topic, let error = store.feedState(for: feedKey).error {
          EmptyCard(icon: "wifi.exclamationmark", title: "Posts couldn’t load", detail: error)
          Button("Retry") { Task { await store.loadTopicFeed(FeedKey(community: community, topic: topic), reset: true) } }
            .buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent).accessibilityIdentifier("topicRetry")
        } else if posts.isEmpty, let topic, !savedOnly, search.isEmpty {
          TopicEmptyState(topic: store.topicDisplay(topic)) { store.topicComposeRequest = topic; compose = true }
        } else if posts.isEmpty {
          EmptyCard(icon: savedOnly ? "bookmark" : "bubble.left.and.bubble.right",
            title: savedOnly ? "No saved posts" : search.isEmpty ? "Start a conversation" : "No matching posts",
            detail: savedOnly ? "Save a post from its menu to keep it here." : "Share a question, a thought, or a campus moment.")
          if !savedOnly && search.isEmpty { Button("Create a post") { compose = true }.buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent) }
        } else {
          ForEach(posts) { post in
            PostCard(post: post, onConversationCreated: { conversationID = $0 }, onRepost: { store.quoteRequest = $0 }, onTopicSelect: selectTopicFromPill)
              .onAppear { prefetchMedia(after: post) }
          }
          if sort == "Hot" {
            if store.fillingFeed { ProgressView().controlSize(.small).frame(maxWidth: .infinity, minHeight: 56).accessibilityLabel("Loading more posts") }
          } else if store.feedHasMore && community == store.feedCommunity {
            // Search and Saved filter the loaded pages; older pages load on request so a
            // filter that matches nothing does not walk the whole feed.
            FeedLoadMoreRow(manual: savedOnly || !search.isEmpty)
          }
        }
      }.padding(.bottom, 12)
    }.accessibilityIdentifier("communityFeed")
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { feedWidth = $0 }
      .maroonRefreshable(onProgressChanged: { refreshPresentation = $0 }) { await store.refreshFeed() }.scrollDismissesKeyboard(.interactively)
      .onScrollPhaseChange { _, phase in interacting = phase == .interacting }
      .onScrollGeometryChange(for: FeedScrollMetrics.self) { geometry in
        let maximumOffset = max(0, geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom - geometry.containerSize.height)
        // Rubber-banding a short feed or its bottom edge isn't navigation
        // intent. Clamping also stops a bounce from reversing the header.
        return FeedScrollMetrics(offset: Double(min(maximumOffset, max(0, geometry.contentOffset.y + geometry.contentInsets.top))), viewport: Double(geometry.containerSize.height), scrollRange: Double(maximumOffset))
      } action: { _, value in
        // Keyboard and sheet layout changes are not scrolling intent. The
        // lock transition resets tracking once; feeding every fractional
        // viewport correction back into @State can perpetuate lazy layout.
        guard !chromeInteractionLocked else { return }
        var next = chrome.state
        // Collapsing a barely-scrollable list can make it fit the expanded
        // viewport, snap its offset to zero and immediately reopen the bars.
        let insufficientTravel = !collapsed && value.scrollRange < Double(headerHeight + tabBarHeight + 32)
        next.observe(offset: value.offset, viewport: value.viewport, interacting: interacting, locked: insufficientTravel)
        chrome.state = next
        if next.collapsed != chromeCollapsed { withAnimation(reduceMotion ? nil : .smooth(duration: 0.34)) { chromeCollapsed = next.collapsed } }
      }
      .onChange(of: published) { _, _ in withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo("feedTop", anchor: .top) } }
      .onChange(of: community) { _, _ in resetChrome(); proxy.scrollTo("feedTop", anchor: .top) }
      // A sort or topic change starts a new page at the top. A re-tapped tab or pill scrolls this
      // page to the top with no animation.
      .onChange(of: scrollToTop) { _, _ in
        var transaction = Transaction(animation: nil); transaction.disablesAnimations = true
        withTransaction(transaction) { proxy.scrollTo("feedTop", anchor: .top) }
      }
      .onChange(of: showSearch) { _, visible in if visible { resetSearchPosition(using: proxy) } }
      .onChange(of: search) { _, _ in resetSearchPosition(using: proxy) }
      .onChange(of: savedOnly) { _, _ in resetSearchPosition(using: proxy) }
  }
  private func chooseSort(_ value: String) {
    guard value != sort, ["New", "Hot"].contains(value) else { return }
    sortMovesForward = value == "Hot"
    AppHaptics.shared.play(.selection)
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { sort = value; resetChrome() }
  }
  private var topicFeedLoading: Bool {
    // A first page that failed shows its error and Retry, not an endless loading state.
    store.feedState(for: feedKey).showsLoading
  }
  private func chooseTopic(_ value: String?) {
    guard value != topic else { return }
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { _ = store.selectTopic(value) }
  }
  /// A pill in the home feed selects its tab (or, already selected, scrolls to the top).
  private func selectTopicFromPill(_ slug: String) {
    if slug == topic { scrollFeedToTop() } else { chooseTopic(slug) }
  }
  private func resetChrome() {
    chrome.state.reset()
    if chromeCollapsed { chromeCollapsed = false }
  }
  private func scrollFeedToTop() { resetChrome(); scrollToTop += 1 }
  private func chooseCommunity(_ value: Community) {
    guard value != community else { return }
    AppHaptics.shared.play(.selection)
    community = value
    Task { await store.selectCommunity(value) }
  }
  private func resetSearchPosition(using proxy: ScrollViewProxy) {
    // Search starts with its first result even when opened from a collapsed,
    // scrolled feed. Avoid combining offset restoration with keyboard motion.
    var transaction = Transaction(animation: nil)
    transaction.disablesAnimations = true
    withTransaction(transaction) {
      resetChrome()
      proxy.scrollTo("feedTop", anchor: .top)
    }
  }
}

struct PostCard: View {
  @Environment(AppStore.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var requestMessage = false
  @State private var quoteSheet = false
  @State private var reporting: Post?
  let post: Post
  var navigates = true
  var onConversationCreated: ((String) -> Void)? = nil
  /// The feed hands a repost to its inline composer; without a handler the card
  /// presents the composer as a sheet (threads, library and tag results).
  var onRepost: ((String) -> Void)? = nil
  /// The home feed selects a tapped topic pill's tab; without a handler the pill pushes that topic's feed.
  var onTopicSelect: ((String) -> Void)? = nil
  /// false draws the pill as a plain tag (inside that topic's own feed).
  var topicPillInteractive = true
  /// The pill shows only while topics are available (never for a deleted post).
  private var topic: Topic? {
    guard store.topicsAvailable, post.deleted != true, let slug = post.topic else { return nil }
    return store.topicDisplay(slug)
  }
  /// Every reply the server holds; a feed post carries only its newest replies.
  private var replyCount: Int { max(post.commentCount ?? 0, post.comments.count) }
  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      header
      if !post.text.isEmpty {
        if navigates {
          NavigationLink { PostDetailView(id: post.id).appHapticOnOpen().toolbar(.visible, for: .navigationBar) } label: { bodyText }.buttonStyle(.plain)
        } else { bodyText }
      }
      if let attachmentID = post.attachmentID { RemoteMedia(attachmentID: attachmentID, layout: .feed) }
      else if let media = post.media { AttachmentPreview(media: media).postMedia(ratio: media.aspectRatio) }
      PostExtrasView(post: post)
      if let quote = post.quote, post.deleted != true { PostQuoteCard(quote: quote) }
      (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 8))) {
        HStack(spacing: 12) {
        if navigates {
          NavigationLink { PostDetailView(id: post.id).appHapticOnOpen().toolbar(.visible, for: .navigationBar) } label: { Label("\(replyCount)", systemImage: "bubble.right").font(.subheadline.weight(.semibold)).frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("\(replyCount) replies")
        } else { Label("\(replyCount)", systemImage: "bubble.right").font(.subheadline.weight(.semibold)) }
        Button { AppHaptics.shared.play(.impact); requestMessage = true } label: { Image(systemName: "envelope").font(.subheadline.weight(.semibold)).frame(width: 44, height: 44) }
          .buttonStyle(ControlPressStyle()).foregroundStyle(Palette.accentText).accessibilityLabel("Message the author")
          .accessibilityIdentifier("messageAuthor-\(post.id)")
          .disabled(!post.acceptsDM || store.owns(post) || post.deleted == true)
          .accessibilityHint(store.owns(post) ? "This is your post" : post.acceptsDM ? "Send an anonymous message request" : "This author is not accepting message requests")
        Button { AppHaptics.shared.play(.impact); if let onRepost { onRepost(post.id) } else { quoteSheet = true } } label: {
          Group {
            if post.repostCount > 0 { Label("\(post.repostCount)", systemImage: "arrow.2.squarepath").labelStyle(.titleAndIcon) }
            else { Image(systemName: "arrow.2.squarepath") }
          }.font(.subheadline.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
        }.buttonStyle(ControlPressStyle()).foregroundStyle(Palette.accentText).disabled(post.deleted == true)
          .accessibilityLabel(post.repostCount == 0 ? "Repost" : post.repostCount == 1 ? "Repost, 1 repost" : "Repost, \(post.repostCount) reposts").accessibilityIdentifier("repostPost-\(post.id)")
          .accessibilityHint("Quote this post in a new post")
        }
        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
        HStack(spacing: 8) {
        if dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
        Button { AppHaptics.shared.play(.impact); store.toggleSave(post.id) } label: {
          Image(systemName: post.saved ? "bookmark.fill" : "bookmark").font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Palette.accentText).frame(width: 44, height: 44)
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
        }.buttonStyle(ControlPressStyle()).accessibilityLabel(post.saved ? "Unsave post" : "Save post")
          .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: post.saved)
        HStack(spacing: 3) {
          voteButton(1, symbol: "arrow.up", label: "Upvote")
          Text("\(post.score)").font(.subheadline.bold()).monospacedDigit().foregroundStyle(Palette.ink)
            .frame(minWidth: 20).contentTransition(reduceMotion ? .identity : .numericText(value: Double(post.score)))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: post.score)
            .accessibilityLabel("Score \(post.score)")
          voteButton(-1, symbol: "arrow.down", label: "Downvote")
        }
        }
      }.foregroundStyle(Palette.accentText)
    }.padding(.horizontal, 16).padding(.vertical, 12).background(Palette.surface)
      .overlay(alignment: .bottom) { Divider() }
      .sheet(isPresented: $requestMessage) {
        NewMessageView(postID: post.id, anonymous: true) { onConversationCreated?($0) }
      }
      .sheet(isPresented: $quoteSheet) { QuotePostComposerSheet(post: post) }
      .modifier(PostReportDialog(post: $reporting))
  }
  /// `Avatar · name · 3h  🏈 Sports … ⋯`. The pill adds no height (the options menu already makes the
  /// row 44 pt); when it does not fit, and always at accessibility sizes, it drops to its own row.
  @ViewBuilder private var header: some View {
    if let topic {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 2) { headerRow(nil); topicPill(topic) }
      } else {
        ViewThatFits(in: .horizontal) {
          headerRow(topic)
          VStack(alignment: .leading, spacing: 2) { headerRow(nil); topicPill(topic) }
        }
      }
    } else { headerRow(nil) }
  }
  /// `sharedPill` is the topic pill when it shares this row; only then is the name kept to one line
  /// (stacked and accessibility layouts put the pill on its own row and let the name wrap).
  private func headerRow(_ sharedPill: Topic?) -> some View {
    HStack(spacing: 7) {
      Avatar(symbol: post.anonymous ? "bubble.left.fill" : "person.fill", size: navigates ? 26 : 34)
      Text(post.displayName).font(.caption.bold()).lineLimit(sharedPill == nil ? nil : 1)
      Text("· \(shortAge(post.created))").font(.caption).foregroundStyle(.secondary)
      if let sharedPill { topicPill(sharedPill).padding(.leading, 2) }
      Spacer()
      optionsMenu
    }
  }
  private func topicPill(_ topic: Topic) -> some View {
    // A topic the catalog no longer lists (disabled) stays readable but opens nothing: its feed
    // would be refused.
    TopicTagButton(topic: topic, community: post.community, onSelect: onTopicSelect,
      interactive: topicPillInteractive && store.topics.contains { $0.slug == topic.slug }).fixedSize()
  }
  private var optionsMenu: some View {
    Menu {
      Button(post.saved ? "Unsave" : "Save", systemImage: "bookmark") { AppHaptics.shared.play(.impact); store.toggleSave(post.id) }
      if store.owns(post) {
        Button("Delete post", systemImage: "trash", role: .destructive) { Task { _ = await store.mutate("post.delete", ["post_id": post.id]) } }
      }
      Button("Report post", systemImage: "flag", role: .destructive) {
        // Topic builds ask for a reason; without topics the menu reports in one tap, as before.
        if store.topicsAvailable { AppHaptics.shared.play(.impact); reporting = post } else { store.report(post.id, reason: "Community report") }
      }
      Button("Block author", systemImage: "hand.raised", role: .destructive) { Task { _ = await store.mutate("block", ["post_id": post.id]) } }
      Button("Hide post", systemImage: "eye.slash") { store.state.hiddenPosts.insert(post.id); store.save() }
    } label: { Image(systemName: "ellipsis").font(.title3.weight(.semibold)).foregroundStyle(Palette.accentText).frame(width: 44, height: 44) }.accessibilityLabel("Post options")
  }
  private func voteButton(_ value: Int, symbol: String, label: String) -> some View {
    Button { AppHaptics.shared.play(.selection); store.vote(post.id, value) } label: {
      Image(systemName: symbol).font(.system(size: 18, weight: .bold)).frame(width: 44, height: 44)
        .foregroundStyle(Palette.onAccent)
        .background(post.vote == value ? Palette.maroon : Palette.elevated.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .scaleEffect(post.vote == value && !reduceMotion ? 1.06 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.58), value: post.vote)
    }.buttonStyle(ControlPressStyle()).accessibilityLabel(label).accessibilityAddTraits(post.vote == value ? .isSelected : [])
      .disabled(post.deleted == true)
  }
  private var bodyText: some View {
    Text(post.text).font(navigates ? .body : .title3.weight(.medium)).lineSpacing(navigates ? 3 : 5).multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(post.deleted == true ? .secondary : Palette.ink)
  }
}


struct SavedPostsView: View {
  var body: some View {
    PersonalLibraryView(kind: .saved)
  }
}

/// Holds `FeedChromeState` outside SwiftUI's observation (see `CommunityView.chrome`).
private final class FeedChromeTracker { var state = FeedChromeState() }
private struct FeedScrollMetrics: Equatable { let offset: Double; let viewport: Double; let scrollRange: Double }

/// Both outgoing and incoming pages read the current direction so reversing
/// Hot → New also sends the old page right. Only horizontal position animates.
private struct FeedPageSlide: AnimatableModifier {
  var distance: CGFloat
  @Binding var forward: Bool
  let entering: Bool
  var animatableData: CGFloat { get { distance } set { distance = newValue } }
  func body(content: Content) -> some View {
    content.offset(x: distance * (forward ? 1 : -1) * (entering ? 1 : -1))
  }
}
/// Bottom sentinel: appearing (or a new cursor while it stays visible) asks for the next page.
/// While a search or the Saved filter is on, it is a button instead (`feedLoadOlder`).
private struct FeedLoadMoreRow: View {
  @Environment(AppStore.self) private var store
  var manual = false
  var body: some View {
    if manual {
      Button { Task { await store.loadMoreFeed() } } label: {
        HStack(spacing: 8) {
          if store.loadingMoreFeed { ProgressView().controlSize(.small) }
          Text("Search older posts").font(.subheadline.bold())
        }.frame(maxWidth: .infinity, minHeight: 44)
      }.buttonStyle(ControlPressStyle()).foregroundStyle(Palette.accentText).disabled(store.loadingMoreFeed)
        .frame(maxWidth: .infinity, minHeight: 56).accessibilityIdentifier("feedLoadOlder")
    } else {
      Group {
        if store.currentFeedLoadFailed && !store.loadingMoreFeed {
          Button("Load more posts") { Task { await store.loadMoreFeed() } }.font(.subheadline.bold()).frame(minHeight: 44)
        } else {
          ProgressView().controlSize(.small).accessibilityLabel("Loading more posts")
        }
      }.frame(maxWidth: .infinity, minHeight: 56).accessibilityIdentifier("feedLoadMore")
        .task(id: store.currentFeedCursor) { if !store.currentFeedLoadFailed { await store.loadMoreFeed() } }
    }
  }
}

