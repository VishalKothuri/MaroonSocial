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
  @State private var chrome = FeedChromeState()
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
  private var posts: [Post] {
    let feed = store.state.posts.filter { (store.feedPostIDs?.contains($0.id) ?? true) && $0.community == community }
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
  private var collapsed: Bool { chrome.collapsed && !chromeInteractionLocked }
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
      Divider()
      }
      ScrollViewReader { proxy in
      ScrollView {
        ZStack(alignment: .top) {
        VStack(spacing: 0) {
          Color.clear.frame(height: 0).id("feedTop")
          if community == .nsfw {
            Text("18+ discussion only. No explicit media.").font(.caption).foregroundStyle(.secondary).padding(12)
          }
          if posts.isEmpty && store.loadingCommunity {
            LoadingWordmark(size: 25).padding(.top, 24).accessibilityLabel("Loading \(community.rawValue)")
          } else if posts.isEmpty {
            EmptyCard(icon: savedOnly ? "bookmark" : "bubble.left.and.bubble.right",
              title: savedOnly ? "No saved posts" : search.isEmpty ? "Start a conversation" : "No matching posts",
              detail: savedOnly ? "Save a post from its menu to keep it here." : "Share a question, a thought, or a campus moment.")
            if !savedOnly && search.isEmpty { Button("Create a post") { compose = true }.buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent) }
          } else {
            // Keep the flexible empty state outside the lazy row cache. A
            // filter can remove every row while the feed is scrolled down.
            LazyVStack(spacing: 0) {
              ForEach(posts) { PostCard(post: $0, onConversationCreated: { conversationID = $0 }, onRepost: { store.quoteRequest = $0 }) }
              if sort == "Hot" {
                if store.fillingFeed { ProgressView().controlSize(.small).frame(maxWidth: .infinity, minHeight: 56).accessibilityLabel("Loading more posts") }
              } else if store.feedHasMore && community == store.feedCommunity {
                // Search and Saved filter the loaded pages; older pages load on request so a
                // filter that matches nothing does not walk the whole feed.
                FeedLoadMoreRow(manual: savedOnly || !search.isEmpty)
              }
            }
          }
        }.padding(.bottom, 12).id(sort).transition(feedSortTransition)
          .task(id: sort == "Hot" ? "\(community.rawValue)#\(store.feedGeneration)" : nil) { if sort == "Hot" { await store.fillFeedForHot() } }
        }
      }.accessibilityIdentifier("communityFeed")
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { feedWidth = $0 }
        .background(CommunitySortSwipeNavigation(selection: Binding(get: { sort }, set: chooseSort),
          enabled: !chromeInteractionLocked).frame(width: 0, height: 0))
        .maroonRefreshable(onProgressChanged: { refreshPresentation = $0 }) { await store.refreshAndWait() }.scrollDismissesKeyboard(.interactively)
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
          var next = chrome
          // Collapsing a barely-scrollable list can make it fit the expanded
          // viewport, snap its offset to zero and immediately reopen the bars.
          let insufficientTravel = !collapsed && value.scrollRange < Double(headerHeight + tabBarHeight + 32)
          next.observe(offset: value.offset, viewport: value.viewport, interacting: interacting, locked: insufficientTravel)
          if next.collapsed != chrome.collapsed { withAnimation(reduceMotion ? nil : .smooth(duration: 0.34)) { chrome = next } }
          else { chrome = next }
        }
        .onChange(of: published) { _, _ in withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo("feedTop", anchor: .top) } }
        .onChange(of: community) { _, _ in chrome.reset(); proxy.scrollTo("feedTop", anchor: .top) }
        .onChange(of: sort) { _, _ in
          var transaction = Transaction(animation: nil); transaction.disablesAnimations = true
          withTransaction(transaction) { proxy.scrollTo("feedTop", anchor: .top) }
        }
        .onChange(of: showSearch) { _, visible in if visible { resetSearchPosition(using: proxy) } }
        .onChange(of: search) { _, _ in resetSearchPosition(using: proxy) }
        .onChange(of: savedOnly) { _, _ in resetSearchPosition(using: proxy) }
      }
    }.appBackground().navigationBarTitleDisplayMode(.inline)
      .toolbar(.hidden, for: .navigationBar)
      .background(SlidingFeedTabBar(hidden: collapsed && store.tab == 0, animated: !reduceMotion, onHeightChange: { tabBarHeight = $0 }).frame(width: 0, height: 0))
      .safeAreaInset(edge: .bottom, spacing: 0) {
        InlinePostComposer(community: community, expanded: $compose) {
          chrome.reset(); sort = "New"; savedOnly = false; search = ""; published += 1
        }
      }
      .onChange(of: chromeInteractionLocked) { _, locked in if locked { chrome.reset() } }
      .onChange(of: store.tab) { _, _ in chrome.reset() }
      .onDisappear { chrome.reset(); interacting = false }
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
  private func chooseSort(_ value: String) {
    guard value != sort, ["New", "Hot"].contains(value) else { return }
    sortMovesForward = value == "Hot"
    AppHaptics.shared.play(.selection)
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { sort = value; chrome.reset() }
  }
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
      chrome.reset()
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
  let post: Post
  var navigates = true
  var onConversationCreated: ((String) -> Void)? = nil
  /// The feed hands a repost to its inline composer; without a handler the card
  /// presents the composer as a sheet (threads, library and tag results).
  var onRepost: ((String) -> Void)? = nil
  /// Every reply the server holds; a feed post carries only its newest replies.
  private var replyCount: Int { max(post.commentCount ?? 0, post.comments.count) }
  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 7) {
        Avatar(symbol: post.anonymous ? "bubble.left.fill" : "person.fill", size: navigates ? 26 : 34)
        Text(post.displayName).font(.caption.bold())
        Text("· \(shortAge(post.created))").font(.caption).foregroundStyle(.secondary)
        Spacer()
        Menu {
          Button(post.saved ? "Unsave" : "Save", systemImage: "bookmark") { AppHaptics.shared.play(.impact); store.toggleSave(post.id) }
          if store.owns(post) {
            Button("Delete post", systemImage: "trash", role: .destructive) { Task { _ = await store.mutate("post.delete", ["post_id": post.id]) } }
          }
          Button("Report post", systemImage: "flag", role: .destructive) { store.report(post.id, reason: "Community report") }
          Button("Block author", systemImage: "hand.raised", role: .destructive) { Task { _ = await store.mutate("block", ["post_id": post.id]) } }
          Button("Hide post", systemImage: "eye.slash") { store.state.hiddenPosts.insert(post.id); store.save() }
        } label: { Image(systemName: "ellipsis").font(.title3.weight(.semibold)).foregroundStyle(Palette.accentText).frame(width: 44, height: 44) }.accessibilityLabel("Post options")
      }
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
        if store.feedLoadFailed && !store.loadingMoreFeed {
          Button("Load more posts") { Task { await store.loadMoreFeed() } }.font(.subheadline.bold()).frame(minHeight: 44)
        } else {
          ProgressView().controlSize(.small).accessibilityLabel("Loading more posts")
        }
      }.frame(maxWidth: .infinity, minHeight: 56).accessibilityIdentifier("feedLoadMore")
        .task(id: store.state.feedCursor) { if !store.feedLoadFailed { await store.loadMoreFeed() } }
    }
  }
}
