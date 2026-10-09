import CryptoKit
import MaroonCore
import SwiftUI

/// Names in an anonymous thread. The server projects a per-post alias ("Aggie 1a2b") for every
/// anonymous reply that is neither the post author's nor the reader's own: the same person keeps it
/// within a post and gets a different one in another post. Each alias has a dot in a stable colour.
enum ReplyAlias {
  /// Eight readable hues on `paper` and `surface` (Tailwind-style 300 tones, ≥ 9:1 on paper).
  static let hexes = ["#93C5FD", "#FDA4AF", "#5EEAD4", "#FDBA74", "#C4B5FD", "#F9A8D4", "#BEF264", "#FDE047"]
  static let palette: [Color] = hexes.map { Color(hex: $0) ?? Palette.secondary }
  /// FNV-1a over the alias's UTF-8 bytes, finished with the MurmurHash3 64-bit mix (FNV's low bits
  /// depend only on the low bits of each byte). Swift's `Hasher` is seeded per launch, so it cannot be
  /// used: the same alias must get the same colour on every device and every launch.
  static func colorIndex(_ alias: String) -> Int {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in alias.utf8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3 }
    hash ^= hash >> 33; hash = hash &* 0xff51_afd7_ed55_8ccd; hash ^= hash >> 33
    return Int(hash % UInt64(hexes.count))
  }
  static func color(_ alias: String) -> Color { palette[colorIndex(alias)] }
  /// The server's alias format.
  static func isAlias(_ value: String) -> Bool {
    value.hasPrefix("Aggie ") && value.count == 10 && value.dropFirst(6).allSatisfy(\.isHexDigit)
  }
  /// The alias a reply shows. A reply that already carries one keeps it; fixture data (and any copy
  /// that still names its author) derives the same shape from the post and the author, the way the
  /// server does, so a username never shows on an anonymous reply.
  static func alias(author: String, postID: String) -> String {
    if isAlias(author) { return author }
    let digest = Insecure.MD5.hash(data: Data((postID + author).utf8))
    return "Aggie " + digest.map { String(format: "%02x", $0) }.joined().prefix(4)
  }
  enum Display: Equatable {
    case deleted
    /// Your own reply (shown with "You").
    case mine(String)
    /// The post's author replying anonymously (shown with the OP capsule).
    case op
    /// Another member's anonymous reply: their alias in this post.
    case alias(String)
    /// A reply published by name.
    case named(String)
  }
  static func display(_ comment: Comment, postID: String, mine: Bool) -> Display {
    if comment.deleted == true { return .deleted }
    if mine { return .mine(comment.anonymous ? "Anonymous" : "@\(comment.author)") }
    guard comment.anonymous else { return .named("@\(comment.author)") }
    if comment.isOP == true { return .op }
    return .alias(alias(author: comment.author, postID: postID))
  }
  /// "Replying to …" in the reply bar.
  static func target(_ comment: Comment?, postID: String, mine: Bool) -> String {
    guard let comment else { return "a reply" }
    switch display(comment, postID: postID, mine: mine) {
    case .deleted: return "a deleted reply"
    case .mine: return "your reply"
    case .op: return "OP"
    case .alias(let name): return name
    case .named(let name): return name
    }
  }
}

/// The 8 pt dot beside an alias.
struct AliasDot: View {
  let alias: String
  var body: some View {
    Circle().fill(ReplyAlias.color(alias)).frame(width: 8, height: 8).accessibilityHidden(true)
  }
}

/// The verified seal beside an organization's name.
struct VerifiedSeal: View {
  @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 12
  var body: some View {
    Image(systemName: "checkmark.seal.fill").font(.system(size: size, weight: .semibold)).foregroundStyle(Palette.maroonBright)
      .accessibilityLabel("Verified organization").accessibilityIdentifier("verifiedSeal")
  }
}

/// Under a Sports post while a game is live or within three hours (the Campus game-day card's window):
/// a link into that game's chat. Before the chat opens it says when.
struct GameDayChatLink: View {
  @Environment(AppStore.self) private var store
  let event: CampusEvent
  let onOpen: (String) -> Void
  @State private var joining = false
  var body: some View {
    let open = event.canOpenSportsChat(at: .now)
    Button {
      guard open, !joining else { return }
      AppHaptics.shared.play(.impact); joining = true
      Task {
        let result = await store.perform("join_sports", ["event_id": event.id])
        joining = false
        if let room = result?.resourceID { onOpen(room) } else { AppHaptics.shared.play(.error) }
      }
    } label: {
      HStack(spacing: 6) {
        if joining { ProgressView().controlSize(.mini) } else { Image(systemName: "bubble.left.and.bubble.right.fill") }
        Text(open ? "Game-day chat" : "Game-day chat opens \(event.chatOpenDate.formatted(date: .omitted, time: .shortened))")
        if open { Image(systemName: "chevron.right").font(.caption2.weight(.bold)) }
      }
      .font(.caption.weight(.semibold)).foregroundStyle(open ? TopicCatalog.display("sports", in: store.topics).textColor : Palette.secondary)
      .frame(minHeight: 44).contentShape(Rectangle())
    }
    .buttonStyle(.plain).disabled(!open || joining)
    .accessibilityLabel(open ? "Game-day chat" : "Game-day chat opens \(event.chatOpenDate.formatted(date: .omitted, time: .shortened))")
    .accessibilityHint("Opens the chat for \(event.title)")
    .accessibilityIdentifier("postGameDayChat")
  }
}

/// Lays children out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8
  var lineSpacing: CGFloat = 8
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
    let width = rows.map { $0.width }.max() ?? 0
    let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
    return CGSize(width: proposal.width ?? width, height: height)
  }
  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for row in arrange(width: bounds.width, subviews: subviews) {
      var x = bounds.minX
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.init(width: bounds.width, height: nil))
        subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .init(width: min(size.width, bounds.width), height: size.height))
        x += min(size.width, bounds.width) + spacing
      }
      y += row.height + lineSpacing
    }
  }
  private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }
  private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = [], current = Row()
    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(.init(width: width, height: nil))
      let itemWidth = min(size.width, width)
      let next = current.indices.isEmpty ? itemWidth : current.width + spacing + itemWidth
      if !current.indices.isEmpty && next > width { rows.append(current); current = Row() }
      current.width = current.indices.isEmpty ? itemWidth : current.width + spacing + itemWidth
      current.indices.append(index); current.height = max(current.height, size.height)
    }
    if !current.indices.isEmpty { rows.append(current) }
    return rows
  }
}

/// The topic strip's "More": sort (New, Hot) and every active topic with its 7-day count. Picking one
/// closes the sheet and selects it.
struct TopicSheet: View {
  @Environment(\.dismiss) private var dismiss
  let topics: [Topic]
  @Binding var selection: String?
  @Binding var sort: String
  var sortOptions = ["New", "Hot"]
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  /// The sort rows' icon column grows with the text, so large symbols stay inside the card.
  @ScaledMetric(relativeTo: .body) private var iconColumn: CGFloat = 24
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Sort").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondary).accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
              sortRow("New", symbol: "clock", detail: "Newest first")
              Divider().padding(.leading, iconColumn + 24)
              sortRow("Hot", symbol: "flame", detail: "Most upvoted lately")
              if sortOptions.contains("Top") {
                Divider().padding(.leading, iconColumn + 24)
                sortRow("Top", symbol: "arrow.up.circle", detail: "Highest score today, this week or all time")
              }
            }.background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
          }
          VStack(alignment: .leading, spacing: 10) {
            Text("Topics").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondary).accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: 8, lineSpacing: 8) {
              topicItem(nil, emoji: nil, title: "All", count: nil, tint: Palette.maroonBright, fill: Palette.elevated)
              ForEach(topics) { topic in topicItem(topic.slug, emoji: topic.emoji, title: topic.title, count: topic.recentCount, tint: topic.textColor, fill: topic.fillColor) }
            }
            Text("Counts are posts in this community over the last 7 days.").font(.caption).foregroundStyle(Palette.secondary)
          }
        }.padding(20)
          .accessibilityElement(children: .contain).accessibilityIdentifier("topicSheet")
      }
      .appBackground().navigationTitle("Browse").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Close") } }
    }
    .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
  }
  private func sortRow(_ value: String, symbol: String, detail: String) -> some View {
    Button {
      AppHaptics.shared.play(.selection); sort = value; dismiss()
    } label: {
      HStack(spacing: 12) {
        Image(systemName: symbol).font(.body.weight(.semibold)).frame(width: iconColumn).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text(value).font(.body.weight(.semibold))
          Text(detail).font(.caption).foregroundStyle(Palette.secondary)
        }
        Spacer(minLength: 0)
        if sort == value { Image(systemName: "checkmark").font(.body.weight(.bold)).foregroundStyle(Palette.maroonBright) }
      }.foregroundStyle(Palette.ink).padding(.horizontal, 12).frame(minHeight: 52).contentShape(Rectangle())
    }.buttonStyle(.plain)
      .accessibilityAddTraits(sort == value ? .isSelected : [])
      .accessibilityIdentifier("topicSheetSort-\(value)")
  }
  private func topicItem(_ slug: String?, emoji: String?, title: String, count: Int?, tint: Color, fill: Color) -> some View {
    let on = selection == slug
    return Button {
      AppHaptics.shared.play(.selection); selection = slug; dismiss()
    } label: {
      HStack(spacing: 6) {
        if let emoji { Text(emoji) }
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
        if let count { Text("\(count)").font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(tint) }
      }
      // A topic name wraps at accessibility sizes (the flow layout gives an item the whole row).
      .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
      .padding(.horizontal, 12).padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 6 : 0).frame(minHeight: 36)
      .background(on ? fill : Palette.surface, in: Capsule())
      .overlay(Capsule().strokeBorder(on ? tint : Palette.border, lineWidth: on ? 1.5 : 0.75))
      .frame(minHeight: 44).contentShape(Rectangle())
    }.buttonStyle(.plain)
      .accessibilityLabel(slug == nil ? "All topics" : count.map { "\(title), \($0) \($0 == 1 ? "post" : "posts") this week" } ?? title)
      .accessibilityAddTraits(on ? .isSelected : [])
      .accessibilityIdentifier("topicSheetItem-\(slug ?? "all")")
  }
}
