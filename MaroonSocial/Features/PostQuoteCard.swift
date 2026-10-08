import MaroonCore
import SwiftUI

/// The bordered card a repost carries: the one quoted level, or a placeholder once the
/// source is gone. The server already applied the anonymity rule to `author`.
struct PostQuoteCard: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let quote: PostQuote
  var navigates = true
  var body: some View {
    if quote.unavailable {
      HStack(spacing: 8) {
        Image(systemName: "nosign").font(.subheadline.weight(.semibold))
        Text("This post is unavailable").font(.subheadline)
      }.foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.border, lineWidth: 0.75))
        .accessibilityElement(children: .combine).accessibilityIdentifier("quoteUnavailable")
    } else if navigates {
      // The quoted post may be older than the loaded feed window, so the destination
      // fetches it by id (read access and reports still apply) before showing the thread.
      NavigationLink { LibraryPostDestination(id: quote.id).appHapticOnOpen().toolbar(.visible, for: .navigationBar) } label: { card }
        .buttonStyle(.plain).accessibilityIdentifier("postQuote-\(quote.id)").accessibilityHint("Opens the quoted post")
    } else {
      card.accessibilityIdentifier("postQuote-\(quote.id)")
    }
  }
  private var card: some View {
    VStack(alignment: .leading, spacing: 7) {
      // Accessibility sizes stack the header so the handle wraps instead of truncating.
      (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(spacing: 6))) {
        HStack(spacing: 6) {
          Avatar(symbol: quote.anonymous == true ? "bubble.left.fill" : "person.fill", size: 20)
          Text(quote.displayName).font(.caption.bold()).foregroundStyle(Palette.ink)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        }
        if let created = quote.created { Text("· \(shortAge(created))").font(.caption).foregroundStyle(.secondary) }
        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
      }
      if let text = quote.text, !text.isEmpty {
        Text(text).font(.subheadline).lineLimit(4).multilineTextAlignment(.leading).foregroundStyle(Palette.ink)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else if quote.attachmentID == nil {
        // A quote-only, poll-only or link-only post has no body to preview.
        Label(quote.quotes == true ? "Quoted another post" : "Open the post to see it", systemImage: quote.quotes == true ? "arrow.2.squarepath" : "arrow.up.forward")
          .font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("quoteEmptyBody")
      }
      if let attachmentID = quote.attachmentID { RemoteMedia(attachmentID: attachmentID, layout: .feed, maxWidth: 220) }
    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
      .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.border, lineWidth: 0.75))
      .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

/// Reposting from a pushed screen (thread, library, tag results) has no inline feed
/// composer underneath it, so the same composer is presented as a sheet with its own
/// draft key; the Community feed keeps the inline path through `AppStore.quoteRequest`.
struct QuotePostComposerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AppStore.self) private var store
  let post: Post
  /// Like the inline composer, a quote starts in the topic the home feed is browsing.
  private var browsedTopic: String? { store.topicsAvailable && store.feedCommunity == post.community ? store.feedTopic : nil }
  var body: some View {
    VStack(spacing: 0) {
      Text("Quote post").font(.headline).padding(.top, 16).padding(.bottom, 4)
      // One draft per quoted post, so text written for one quote never reappears on another.
      InlinePostComposer(community: post.community, expanded: Binding(get: { true }, set: { if !$0 { dismiss() } }),
        draftKey: "post:quote:" + post.id, quoting: post.id, browsedTopic: browsedTopic) { dismiss() }
      Spacer(minLength: 0)
    }.appBackground().presentationDetents([.large]).presentationDragIndicator(.visible)
  }
}
