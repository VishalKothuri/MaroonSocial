import MaroonCore
import SwiftUI

struct PostExtrasView: View {
  @Environment(AppStore.self) private var store
  let post: Post
  var body: some View {
    if post.deleted != true {
      VStack(alignment: .leading, spacing: 10) {
        if let poll = post.poll { PostPollView(postID: post.id, poll: poll) }
        if let normalized = try? PostFeatureRules.normalizeLink(post.linkURL), let url = URL(string: normalized) {
          Link(destination: url) {
            HStack(spacing: 10) {
              Image(systemName: "link").font(.title3).frame(width: 32)
              VStack(alignment: .leading, spacing: 3) {
                Text(url.host() ?? normalized).font(.subheadline.bold()).lineLimit(1)
                Text(normalized).font(.caption).foregroundStyle(Palette.secondary).lineLimit(2)
              }
              Spacer(minLength: 0)
              Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
            }.padding(12).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
              .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 12))
          }.foregroundStyle(Palette.ink).accessibilityIdentifier("postLinkCard")
            .accessibilityLabel("Open link, " + normalized)
        }
        if let tags = post.tags, !tags.isEmpty {
          ScrollView(.horizontal) {
            HStack(spacing: 8) {
              ForEach(tags, id: \.self) { tag in
                NavigationLink { TaggedPostsView(tag: tag, community: post.community).toolbar(.visible, for: .navigationBar) } label: {
                  Text("#" + tag).font(.subheadline.weight(.medium)).padding(.horizontal, 10).frame(minHeight: 44)
                    .background(Palette.elevated, in: Capsule())
                }.buttonStyle(.plain).foregroundStyle(Palette.accentText).accessibilityIdentifier("postTag-" + tag)
              }
            }
          }.scrollIndicators(.hidden)
        }
      }
    }
  }
}

private struct PostPollView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let postID: String
  let poll: PostPoll
  @State private var voting = false
  @State private var error: String?
  var body: some View {
    // Schedule the deadline itself so an open card cannot remain voteable for an
    // extra polling interval. The server checks the authoritative deadline too.
    TimelineView(.explicit([Date.now, poll.endsAt])) { context in
      let ended = context.date >= poll.endsAt
      let showResults = ended || poll.myOptionID != nil
      VStack(alignment: .leading, spacing: 8) {
        Text(poll.question).font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("pollQuestionDisplay")
        ForEach(poll.options) { option in
          optionButton(option, ended: ended, showResults: showResults)
        }
        HStack {
          Text("\(poll.totalVotes) \(poll.totalVotes == 1 ? "vote" : "votes")")
          Text("·")
          if ended { Text("Poll ended").accessibilityIdentifier("pollEnded") }
          else { Text("Ends \(poll.endsAt, style: .relative)") }
          Spacer(minLength: 0)
          if voting { ProgressView().controlSize(.mini) }
        }.font(.caption).foregroundStyle(Palette.secondary)
        if poll.myOptionID != nil && !ended { Text("You can change your answer until the poll ends.").font(.caption2).foregroundStyle(Palette.secondary) }
        if let error { Text(error).font(.caption).foregroundStyle(Palette.accentText).accessibilityIdentifier("pollVoteError") }
      }.padding(12).background(Palette.paper, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("postPoll")
    }
  }
  private func optionButton(_ option: PostPollOption, ended: Bool, showResults: Bool) -> some View {
    let selected = poll.myOptionID == option.id
    let fraction = poll.totalVotes > 0 ? max(0, min(1, Double(option.votes) / Double(poll.totalVotes))) : 0
    let percent = Int((fraction * 100).rounded())
    return Button {
      guard !voting else { return }
      voting = true; error = nil
      Task {
        let success = await store.votePoll(postID: postID, optionID: option.id)
        voting = false
        if !success { error = store.notice ?? "Your vote could not be saved. Refresh the post and try again." }
      }
    } label: {
      HStack(spacing: 8) {
        Text(option.text).font(.subheadline).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
        if selected { Image(systemName: "checkmark.circle.fill") }
        if showResults { Text("\(percent)%").font(.subheadline.monospacedDigit().weight(.semibold)) }
      }.padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: 44)
        .background {
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 10).fill(Palette.elevated)
              if showResults { Rectangle().fill(Palette.maroon).frame(width: geometry.size.width * fraction) }
            }.clipShape(RoundedRectangle(cornerRadius: 10))
          }
        }.overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Palette.accentText : Palette.ink.opacity(0.16), lineWidth: selected ? 1.5 : 0.75))
    }.buttonStyle(.plain).foregroundStyle(Palette.ink).disabled(ended || voting)
      .accessibilityLabel(option.text).accessibilityValue(showResults ? "\(option.votes) votes, \(percent) percent" : "")
      .accessibilityAddTraits(selected ? .isSelected : [])
      .accessibilityIdentifier("pollVote-" + option.id)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: option.votes)
  }
}

struct TaggedPostsView: View {
  @Environment(AppStore.self) private var store
  let tag: String
  let community: Community
  @State private var conversationID: String?
  @State private var scope: TaggedPostLease?
  @State private var loading = false
  private var query: SocialTagQuery { SocialTagQuery(tag: tag, community: community) }
  private var posts: [Post] { store.posts(for: query) }
  private var error: String? { store.tagPages[query]?.error }
  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        Text(community.rawValue).font(.caption).foregroundStyle(Palette.secondary).padding(16).accessibilityIdentifier("tagCommunity")
        ForEach(posts) { post in PostCard(post: post, onConversationCreated: { conversationID = $0 }) }
        if let error {
          EmptyCard(icon: "wifi.exclamationmark", title: "Posts couldn’t load", detail: error)
          Button("Retry") { Task { await load() } }.buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent)
            .padding(16).disabled(loading).accessibilityIdentifier("tagRetry")
        } else if loading && posts.isEmpty {
          LoadingWordmark(animating: true, size: 24).frame(maxWidth: .infinity).padding(24).accessibilityLabel("Loading posts")
        } else if posts.isEmpty {
          EmptyCard(icon: "number", title: "No posts with this tag", detail: "Be the first to use #\(tag) in this community.")
        }
      }
    }.maroonRefreshable { await load() }.appBackground().navigationTitle("#" + tag).navigationBarTitleDisplayMode(.inline)
      .navigationDestination(item: $conversationID) { ChatView(id: $0).toolbar(.visible, for: .navigationBar) }
      .task(id: query) {
        if scope?.query != query { scope = store.openTagScope(query) }
        do { try await Task.sleep(for: .milliseconds(150)); try Task.checkCancellation(); await load() } catch {}
      }
  }
  private func load() async {
    guard !loading else { return }; loading = true
    defer { loading = false }
    await store.loadTagPage(query)
  }
}
