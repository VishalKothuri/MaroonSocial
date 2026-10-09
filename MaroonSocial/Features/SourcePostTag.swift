import SwiftUI

/// Pure display rules for the "From this post" tag, so tests can cover them.
enum SourcePostTagText {
  struct Display: Equatable {
    let title: String
    let excerpt: String
    let identifier: String
    let tappable: Bool
    let accessibilityLabel: String
  }
  static let liveTitle = "From this post"
  static let deletedTitle = "From a post that was deleted"
  static func display(_ context: SourcePostContext) -> Display {
    if context.deleted { return Display(title: deletedTitle, excerpt: "…", identifier: "sourcePostTagDeleted", tappable: false, accessibilityLabel: deletedTitle) }
    let excerpt = oneLine(context.excerpt)
    return Display(title: liveTitle, excerpt: excerpt, identifier: "sourcePostTag", tappable: true,
      accessibilityLabel: (context.fromReply ? "\(liveTitle), via a reply: " : "\(liveTitle): ") + excerpt)
  }
  /// One line per row: newlines and runs of spaces collapse; nothing to show becomes an ellipsis.
  static func oneLine(_ text: String?) -> String {
    let collapsed = (text ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
    return collapsed.isEmpty ? "…" : collapsed
  }
}

/// Where a direct message came from. Tappable only while the post still exists; the
/// server never includes the author, so neither does this view.
struct SourcePostTag: View {
  let context: SourcePostContext
  var fullWidth = false
  var identifierSuffix = ""
  var onOpen: ((String) -> Void)? = nil
  var body: some View {
    let display = SourcePostTagText.display(context)
    if display.tappable, let onOpen {
      Button { AppHaptics.shared.play(.selection); onOpen(context.postID) } label: { content(display) }
        .buttonStyle(.plain).accessibilityLabel(display.accessibilityLabel).accessibilityHint("Opens the post")
        .accessibilityIdentifier(display.identifier + identifierSuffix)
    } else {
      content(display).accessibilityElement(children: .combine).accessibilityLabel(display.accessibilityLabel)
        .accessibilityIdentifier(display.identifier + identifierSuffix)
    }
  }
  private func content(_ display: SourcePostTagText.Display) -> some View {
    HStack(spacing: 5) {
      Image(systemName: "quote.opening").font(.caption2.weight(.bold))
      Text(display.title).font(.caption.weight(.semibold)).lineLimit(1).layoutPriority(1)
      Text(display.excerpt).font(.caption).lineLimit(1).truncationMode(.tail)
      if display.tappable { Image(systemName: "chevron.right").font(.caption2.weight(.semibold)) }
    }.foregroundStyle(context.deleted ? Palette.secondary : Palette.accentText)
      .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading).contentShape(Rectangle())
  }
}

struct SourcePostDestination: Hashable, Identifiable { let id: String }
