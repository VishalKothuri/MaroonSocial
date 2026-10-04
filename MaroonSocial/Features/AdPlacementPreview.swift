import SwiftUI

/// A local layout demonstration. No ad request, impression, click, or revenue is generated.
struct AdPlacementPreview: View {
  private let examples = [
    "Anyone studying at Evans tonight?", "Best coffee between classes?", "That walk across campus counts as cardio.",
    "Looking for a study partner for next week.", "What’s everyone doing this weekend?", "The sunset over campus was unreal today.",
    "Found a quiet corner at the MSC.", "Reminder to bring water on that walk.", "Anyone up for a quick game?", "Good luck on your exams, Ags."
  ]
  var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 6) {
          Label("Layout preview", systemImage: "rectangle.inset.filled").font(.headline)
          Text("Example posts and a sample sponsored card. Scroll past it just like a post. This preview doesn’t serve ads or earn money.")
            .font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Palette.surface)
        ForEach(0..<20, id: \.self) { index in
          if index == 10 { SponsoredPreviewCard().padding(16) }
          VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
              Avatar(symbol: "bubble.left.fill", size: 28)
              Text("Example campus post").font(.caption.weight(.semibold))
              Spacer()
              Text("Preview").font(.caption2).foregroundStyle(.secondary)
            }
            Text(examples[index % examples.count]).font(.body)
          }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
          Divider()
        }
      }
    }.appBackground().navigationTitle("Sponsored card preview").navigationBarTitleDisplayMode(.inline)
      .accessibilityIdentifier("adPlacementPreview")
  }
}

private struct SponsoredPreviewCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Sponsored · Test preview").font(.caption.weight(.semibold))
        Spacer()
        Image(systemName: "info.circle").accessibilityLabel("Sample advertisement")
      }.foregroundStyle(Palette.ink.opacity(0.8))
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "cup.and.saucer.fill").font(.title2).foregroundStyle(Palette.onAccent)
          .frame(width: 48, height: 48).background(Palette.maroon, in: RoundedRectangle(cornerRadius: 12))
        VStack(alignment: .leading, spacing: 4) {
          Text("A little break between classes").font(.headline)
          Text("Your next campus favorite could go here.").font(.subheadline).foregroundStyle(.secondary)
        }
      }
      HStack {
        Text("Example advertiser").font(.caption).foregroundStyle(.secondary)
        Spacer()
        Text("Learn more").font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 10)
          .foregroundStyle(Palette.onAccent).background(Palette.maroon, in: Capsule())
      }
    }.padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.ink.opacity(0.18), lineWidth: 1))
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("sponsoredCardPreview")
  }
}
