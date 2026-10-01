import SwiftUI

enum Palette {
  static let maroon = Color(red: 0.36, green: 0.055, blue: 0.11)
  static let paper = Color(red: 0.96, green: 0.95, blue: 0.92)
  static let ink = Color(red: 0.12, green: 0.14, blue: 0.13)
  static let lime = Color(red: 0.82, green: 0.96, blue: 0.44)
}
struct Wordmark: View {
  var small = false
  var body: some View {
    HStack(spacing: 2) {
      Text("maroon").font(.system(size: small ? 25 : 36, weight: .black, design: .rounded))
        .tracking(-1.6)
      Text("social").font(.system(size: small ? 25 : 36, weight: .regular, design: .serif)).italic()
        .tracking(-1.5)
    }.accessibilityElement(children: .combine)
  }
}
struct SectionHeading: View {
  let title: String
  var eyebrow: String? = nil
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let eyebrow {
        Text(eyebrow.uppercased()).font(.system(size: 10, weight: .bold)).tracking(2)
          .foregroundStyle(.secondary)
      }
      Text(title).font(.system(size: 32, weight: .bold, design: .serif)).tracking(-0.8)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}
struct Pill: View {
  let text: String
  var icon: String? = nil
  var selected = false
  var body: some View {
    HStack(spacing: 5) {
      if let icon { Image(systemName: icon) }
      Text(text)
    }.font(.system(size: 12, weight: .semibold)).padding(.horizontal, 14).padding(.vertical, 9)
      .background(selected ? Palette.ink : Color.white, in: Capsule()).foregroundStyle(
        selected ? .white : Palette.ink
      ).overlay(Capsule().strokeBorder(Palette.ink.opacity(selected ? 0 : 0.1)))
  }
}
struct PrimaryButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(
      17
    ).background(Palette.maroon, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.white)
      .opacity(configuration.isPressed ? 0.75 : 1)
  }
}
struct Card<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(
      .white, in: RoundedRectangle(cornerRadius: 22))
  }
}
struct EmptyCard: View {
  let icon: String
  let title: String
  let detail: String
  var body: some View {
    ContentUnavailableView(title, systemImage: icon, description: Text(detail)).padding(
      .vertical, 25)
  }
}
struct PreviewLabel: View {
  var body: some View {
    HStack(spacing: 5) {
      Circle().fill(Color.orange).frame(width: 5, height: 5)
      Text("LOCAL PREVIEW").tracking(1.5)
      Spacer()
      Text("Social activity stays on this iPhone")
    }.font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).padding(.horizontal, 20)
      .padding(.vertical, 7).background(Palette.paper)
  }
}
extension View {
  func appBackground() -> some View { self.background(Palette.paper).foregroundStyle(Palette.ink) }
}
