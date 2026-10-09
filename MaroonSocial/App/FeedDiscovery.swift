import Foundation
import MaroonCore

/// What a server search asks for: the trimmed query in one community (and topic).
struct PostSearchKey: Hashable {
  var community: Community
  var topic: String?
  var query: String
}
/// The Community search field's server results, newest-relevant first as the server ranked them.
struct PostSearchState: Equatable {
  var key: PostSearchKey? = nil
  var ids: [String] = []
  var cursor: JSONValue? = nil
  var more = false
  /// The first page is on its way (including the 300 ms debounce).
  var loading = false
  var loadingMore = false
  var loaded = false
  var error: String? = nil
  var moreFailed = false
  /// The first page failed before any server confirmed `posts.search` (offline, unavailable): this
  /// query filters the loaded posts as before; the next query asks the server again.
  var localFallback = false
}
/// One Top list: a community, a topic (nil is All) and a window.
struct TopFeedKey: Hashable {
  var community: Community
  var topic: String?
  var window: TopWindow
}
struct TopFeedState: Equatable {
  /// In the server's order (score, then newest). Offset pages can repeat a post whose score moved
  /// between pages; it keeps its first place.
  var ids: [String] = []
  var cursor: JSONValue? = nil
  var more = false
  var loading = false
  var loadingMore = false
  var loaded = false
  var error: String? = nil
  var moreFailed = false
  var showsLoading: Bool { loading || (!loaded && error == nil) }
  /// Appends a page's ids, skipping ones already listed.
  mutating func append(_ page: [String]) {
    var seen = Set(ids)
    for id in page where seen.insert(id).inserted { ids.append(id) }
  }
}

// MARK: Server search, Top sort and post links
extension AppStore {
  /// Server search is tried until a server answers that it has no `posts.search`.
  var serverSearchAvailable: Bool { searchSupported != false }
  /// The Top sort shows only once the server answered `feed.top`.
  var topSortAvailable: Bool { state.topSupported == true }
  /// The sorts the home feed offers.
  var feedSorts: [String] { topSortAvailable ? ["New", "Hot", "Top"] : ["New", "Hot"] }
  static let searchDebounce: Duration = .milliseconds(300)

  /// Posts that search results and Top pages hold in the canonical list.
  var discoveryPostIDs: Set<String> {
    var ids = Set(search.ids)
    for entry in topFeeds.values { ids.formUnion(entry.ids) }
    return ids
  }
  /// Shows server results for this query (not the loaded-post filter after a failed first page).
  var searchShowsServerResults: Bool { !search.localFallback }
  /// Gone from the feed (deleted, hidden, blocked): gone from results and Top too.
  func removeFromDiscovery(_ removed: Set<String>) {
    guard !removed.isEmpty else { return }
    if search.ids.contains(where: removed.contains) { search.ids.removeAll { removed.contains($0) } }
    for key in topFeeds.keys where topFeeds[key]?.ids.contains(where: removed.contains) == true {
      topFeeds[key]?.ids.removeAll { removed.contains($0) }
    }
  }
  /// Sign-out, account deletion or a new identity.
  func resetDiscovery() {
    searchTask?.cancel(); searchTask = nil; searchGeneration += 1; search = PostSearchState()
    topFeeds = [:]; topWindow = .week; topProbed = false; topProbeAt = .distantPast
    discoveryRefreshRunning = false; lastDiscoveryRefresh = .distantPast
    if fixtureMode { state.topSupported = searchSupported == false ? nil : true } else { searchSupported = nil }
  }

  // MARK: Search
  /// The search field changed (or its community or topic did). A valid query (2–80 characters)
  /// asks the server after a 300 ms pause, cancelling the request for earlier input; anything else
  /// clears the results and the field filters the loaded posts as before.
  func updateSearch(_ text: String, community: Community, topic: String?) {
    guard serverSearchAvailable, let query = PostSearchRules.query(text) else { clearSearch(); return }
    let key = PostSearchKey(community: community, topic: topic, query: query)
    if search.key == key, search.loading || (search.loaded && search.error == nil) { return }
    startSearch(key, delay: Self.searchDebounce)
  }
  /// "Try again" after a failed first page.
  func retrySearch() {
    guard let key = search.key else { return }
    startSearch(key, delay: .zero)
  }
  func clearSearch() {
    searchTask?.cancel(); searchTask = nil; searchGeneration += 1
    if search != PostSearchState() { search = PostSearchState() }
  }
  private func startSearch(_ key: PostSearchKey, delay: Duration) {
    searchTask?.cancel(); searchGeneration += 1
    let generation = searchGeneration
    search = PostSearchState(key: key, loading: true)
    searchTask = Task { [weak self] in
      if delay > .zero { try? await Task.sleep(for: delay) }
      guard !Task.isCancelled else { return }
      await self?.runSearch(key, cursor: nil, generation: generation)
    }
  }
  /// The next page of results (the end of the list appeared).
  func loadMoreSearch() async {
    guard let key = search.key, search.loaded, search.more, !search.loadingMore, !search.loading, let cursor = search.cursor else { return }
    search.loadingMore = true; search.moreFailed = false
    await runSearch(key, cursor: cursor, generation: searchGeneration)
  }
  /// Posts of the current results the member can still see, in the server's order.
  func searchResults() -> [Post] {
    guard let key = search.key else { return [] }
    let canonical = Dictionary(state.posts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    return search.ids.compactMap { canonical[$0] }.filter {
      $0.deleted != true && !state.hiddenPosts.contains($0.id) && $0.community == key.community && (key.topic == nil || $0.topic == key.topic)
    }
  }
  private func runSearch(_ key: PostSearchKey, cursor: JSONValue?, generation: Int) async {
    let owner = compositions.owner
    do {
      let page = fixtureMode ? try await fixtureSearchPage(key, cursor: cursor)
        : try await social.searchPosts(community: key.community, query: key.query, topic: key.topic, cursor: cursor)
      guard generation == searchGeneration, owner == compositions.owner, search.key == key else { return }
      searchSupported = true
      state.posts = Self.mergePosts(state.posts, with: page.posts)
      var next = search
      if cursor == nil { next.ids = [] }
      var seen = Set(next.ids)
      for post in page.posts where seen.insert(post.id).inserted { next.ids.append(post.id) }
      next.cursor = page.cursor; next.more = page.hasNext
      next.loading = false; next.loadingMore = false; next.loaded = true; next.error = nil; next.moreFailed = false
      search = next
      save()
    } catch {
      guard generation == searchGeneration, owner == compositions.owner, search.key == key else { return }
      // A next page cancelled with the row that asked for it (scrolled away, a pushed thread, another
      // tab): the row asks again when it reappears.
      if error.isCancellation { search.loadingMore = false; return }
      // A server without `posts.search`: the field filters the loaded posts from now on.
      if error.isUnknownSocialAction { searchSupported = false; search = PostSearchState(); return }
      // No answer from a server that has not confirmed search yet (offline, unavailable): this query
      // filters the loaded posts, as an old server's would.
      if cursor == nil, searchSupported != true, error.isTransportFailure {
        search = PostSearchState(key: key, loaded: true, localFallback: true); return
      }
      search.loading = false; search.loadingMore = false
      if cursor == nil { search.error = error.localizedDescription } else { search.moreFailed = true }
    }
  }

  // MARK: Posts only results and Top hold
  /// Posts that search results or Top lists hold and the running delta does not cover (the held
  /// feed, or the shown topic's posts), grouped by community, at most 300.
  func discoveryOnlyPostIDs() -> [Community: [String]] {
    let covered: Set<String> = topicFeedKey.map { topicFeeds[$0]?.ids ?? [] } ?? Set(deltaCoveredFeedIDs())
    var seen = Set<String>(), count = 0
    var result: [Community: [String]] = [:]
    var sources: [(Community, [String])] = []
    if let key = search.key { sources.append((key.community, search.ids)) }
    for (key, entry) in topFeeds.sorted(by: { $0.key.window.rawValue < $1.key.window.rawValue }) { sources.append((key.community, entry.ids)) }
    for (community, ids) in sources {
      for id in ids where count < 300 && !covered.contains(id) && seen.insert(id).inserted {
        result[community, default: []].append(id); count += 1
      }
    }
    return result
  }
  /// No feed delta reports a change to a post only search or Top holds, so after a post mutation
  /// (a vote, a poll vote, a reply, a delete, a block or a report) and on the 60 s reconciliation
  /// those posts are read again with `feed.posts`: current copies replace the held ones and the ids
  /// it reports missing (deleted, hidden, blocked or no longer readable) leave the lists.
  func refreshDiscoveryPosts() async {
    guard !fixtureMode, connected, state.onboarded, !discoveryRefreshRunning else { return }
    let groups = discoveryOnlyPostIDs()
    lastDiscoveryRefresh = .now
    guard !groups.isEmpty else { return }
    let owner = compositions.owner
    discoveryRefreshRunning = true
    defer { if compositions.owner == owner { discoveryRefreshRunning = false } }
    for (community, ids) in groups {
      for start in stride(from: 0, to: ids.count, by: 50) {
        guard let page = try? await social.feedPosts(community: community, ids: Array(ids[start..<min(ids.count, start + 50)])),
          compositions.owner == owner else { return }
        let removed = Set(page.removed)
        removeFromDiscovery(removed)
        state.posts = Self.mergePosts(state.posts, with: page.posts.filter { !removed.contains($0.id) })
      }
    }
    save()
  }

  // MARK: Top
  /// Probes `feed.top` once per launch: an answer shows Top, "Unknown social action." keeps
  /// New/Hot, and a network failure tries again a minute later.
  func probeTopSort() async {
    guard !fixtureMode, connected, state.onboarded, !topProbed else { return }
    topProbeAt = .now.addingTimeInterval(60)
    let owner = compositions.owner
    do {
      _ = try await social.topPosts(community: .campus, window: .week, limit: 1)
      guard owner == compositions.owner else { return }
      topProbed = true; setTopSupported(true)
    } catch {
      guard owner == compositions.owner, !error.isCancellation else { return }
      if error.isUnknownSocialAction { topProbed = true; setTopSupported(nil) }
    }
  }
  func setTopSupported(_ value: Bool?) {
    guard state.topSupported != value else { return }
    state.topSupported = value
    if value != true { topFeeds = [:] }
    save()
  }
  func selectTopWindow(_ window: TopWindow) {
    guard window != topWindow else { return }
    topWindow = window
  }
  func topFeedState(_ key: TopFeedKey) -> TopFeedState { topFeeds[key] ?? TopFeedState() }
  /// The Top list's posts the member can still see, in the server's order.
  func topPosts(_ key: TopFeedKey) -> [Post] {
    guard let entry = topFeeds[key] else { return [] }
    let canonical = Dictionary(state.posts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    return entry.ids.compactMap { canonical[$0] }.filter {
      $0.deleted != true && !state.hiddenPosts.contains($0.id) && $0.community == key.community && (key.topic == nil || $0.topic == key.topic)
    }
  }
  /// The first page of a Top list; `reset` reloads one that already loaded (pull to refresh).
  @discardableResult func loadTopFeed(_ key: TopFeedKey, reset: Bool = false) async -> Bool {
    guard topSortAvailable else { return false }
    var entry = topFeeds[key] ?? TopFeedState()
    guard !entry.loading, reset || !entry.loaded || entry.error != nil else { return false }
    entry.loading = true; entry.error = nil; topFeeds[key] = entry
    let owner = compositions.owner
    do {
      let page = fixtureMode ? try await fixtureTopPage(key, cursor: nil)
        : try await social.topPosts(community: key.community, window: key.window, topic: key.topic)
      guard owner == compositions.owner, topFeeds[key] != nil else { return false }
      state.posts = Self.mergePosts(state.posts, with: page.posts)
      var next = TopFeedState(cursor: page.cursor, more: page.hasNext, loaded: true)
      next.append(page.posts.map(\.id))
      topFeeds[key] = next
      save()
      return true
    } catch {
      guard owner == compositions.owner, topFeeds[key] != nil else { return false }
      topFeeds[key]?.loading = false
      if error.isCancellation { return false }
      if error.isUnknownSocialAction { setTopSupported(nil); return false }
      // "Choose an available topic.": the catalog drifted; the refresh resets to All.
      if key.topic != nil, (error as? SocialServiceError)?.code == "invalid" { await refreshTopics() }
      topFeeds[key]?.error = error.localizedDescription
      return false
    }
  }
  /// The next page of a Top list (the end of the list appeared).
  func loadMoreTop(_ key: TopFeedKey) async {
    guard topSortAvailable, let entry = topFeeds[key], entry.loaded, entry.more, !entry.loadingMore, let cursor = entry.cursor else { return }
    let owner = compositions.owner
    topFeeds[key]?.loadingMore = true; topFeeds[key]?.moreFailed = false
    do {
      let page = fixtureMode ? try await fixtureTopPage(key, cursor: cursor)
        : try await social.topPosts(community: key.community, window: key.window, topic: key.topic, cursor: cursor)
      guard owner == compositions.owner, topFeeds[key]?.cursor == cursor else { return }
      state.posts = Self.mergePosts(state.posts, with: page.posts)
      topFeeds[key]?.append(page.posts.map(\.id))
      topFeeds[key]?.cursor = page.cursor; topFeeds[key]?.more = page.hasNext; topFeeds[key]?.loadingMore = false
      save()
    } catch {
      guard owner == compositions.owner, topFeeds[key] != nil else { return }
      topFeeds[key]?.loadingMore = false
      if error.isCancellation { return }
      if error.isUnknownSocialAction { setTopSupported(nil); return }
      topFeeds[key]?.moreFailed = true
    }
  }

  // MARK: Fixture answers
  /// Fixture `posts.search`: body, poll question or hashtag contains the query, newest first.
  private func fixtureSearchPage(_ key: PostSearchKey, cursor: JSONValue?) async throws -> SocialPostsPage {
    try await Task.sleep(for: .milliseconds(250))
    let needle = key.query
    let matches = state.posts.filter {
      $0.community == key.community && $0.deleted != true && (key.topic == nil || $0.topic == key.topic)
        && ($0.text.localizedCaseInsensitiveContains(needle) || ($0.poll?.question.localizedCaseInsensitiveContains(needle) ?? false)
          || ($0.tags ?? []).contains { $0.localizedCaseInsensitiveContains(needle.trimmingCharacters(in: CharacterSet(charactersIn: "#"))) })
    }.sorted { ($0.created, $0.id) > ($1.created, $1.id) }
    return Self.fixturePage(matches, cursor: cursor)
  }
  /// Fixture `feed.top`: the window's posts by score, then newest.
  private func fixtureTopPage(_ key: TopFeedKey, cursor: JSONValue?) async throws -> SocialPostsPage {
    try await Task.sleep(for: .milliseconds(250))
    let start = key.window.span.map { Date.now.addingTimeInterval(-$0) } ?? .distantPast
    let posts = state.posts.filter {
      $0.community == key.community && $0.deleted != true && (key.topic == nil || $0.topic == key.topic) && $0.created >= start
    }.sorted { ($0.score, $0.created, $0.id) > ($1.score, $1.created, $1.id) }
    return Self.fixturePage(posts, cursor: cursor)
  }
  /// Offset pages of 30 with an `{"offset": n}` cursor, as a server may send it.
  static func fixturePage(_ posts: [Post], cursor: JSONValue?, size: Int = 30) -> SocialPostsPage {
    var offset = 0
    if case .object(let value)? = cursor, case .number(let number)? = value["offset"] { offset = max(0, Int(number)) }
    let page = Array(posts.dropFirst(offset).prefix(size))
    let more = posts.count > offset + page.count
    return SocialPostsPage(posts: page, more: more, cursor: more ? .object(["offset": .number(Double(offset + page.count))]) : nil)
  }

  // MARK: Post links
  /// A share link or `maroonsocial://post/<id>` opened the app. The post opens as soon as the
  /// member is signed in (the push-routing path presents it); until then it waits.
  @discardableResult func openLink(_ url: URL) -> Bool {
    guard let id = PostLinks.postID(from: url) else {
      let ours = url.scheme?.lowercased() == PostLinks.scheme || url.host?.lowercased().hasSuffix(PostLinks.host) == true
      if ours { notice = "This link can’t be opened in Maroon Social." }
      return false
    }
    pendingPostLink = id
    return true
  }
}
