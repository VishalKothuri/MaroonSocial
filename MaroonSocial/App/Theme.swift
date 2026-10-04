import SwiftUI
import UIKit

enum Palette {
  // Semantic roles keep cards, sheets, text and controls legible in the dark theme.
  static let paper = Color(red: 0.055, green: 0.059, blue: 0.071)
  static let surface = Color(red: 0.105, green: 0.110, blue: 0.129)
  static let elevated = Color(red: 0.153, green: 0.153, blue: 0.176)
  static let hero = Color(red: 0.20, green: 0.025, blue: 0.025)
  static let ink = Color(red: 0.957, green: 0.937, blue: 0.902)
  static let secondary = Color(red: 0.714, green: 0.690, blue: 0.710)
  static let border = Color(red: 0.235, green: 0.224, blue: 0.251)
  // Texas A&M brand maroon (#500000) is a fill, not a text color on dark surfaces.
  static let maroon = Color(red: 80.0 / 255.0, green: 0, blue: 0)
  static let onAccent = ink
  static let accentText = ink
  static let lime = Color(red: 0.741, green: 0.824, blue: 0.506)

  @MainActor static func configureUIKit() {
    let navigation = UINavigationBarAppearance()
    navigation.configureWithOpaqueBackground()
    navigation.backgroundColor = UIColor(paper)
    navigation.shadowColor = UIColor.clear
    navigation.titleTextAttributes = [.foregroundColor: UIColor(ink)]
    navigation.largeTitleTextAttributes = [.foregroundColor: UIColor(ink)]
    let bar = UINavigationBar.appearance()
    bar.standardAppearance = navigation; bar.scrollEdgeAppearance = navigation
    bar.compactAppearance = navigation; bar.compactScrollEdgeAppearance = navigation
    bar.tintColor = UIColor(accentText)
    let tabs = UITabBarAppearance()
    tabs.configureWithOpaqueBackground(); tabs.backgroundColor = UIColor(paper)
    tabs.shadowColor = UIColor(border.opacity(0.5))
    tabs.selectionIndicatorTintColor = UIColor(maroon)
    for item in [tabs.stackedLayoutAppearance, tabs.inlineLayoutAppearance, tabs.compactInlineLayoutAppearance] {
      item.normal.iconColor = UIColor(ink)
      item.normal.titleTextAttributes = [.foregroundColor: UIColor(secondary)]
      item.selected.iconColor = UIColor(accentText)
      item.selected.titleTextAttributes = [.foregroundColor: UIColor(accentText)]
      item.normal.badgeBackgroundColor = UIColor(maroon)
      item.selected.badgeBackgroundColor = UIColor(maroon)
      item.normal.badgeTextAttributes = [.foregroundColor: UIColor(onAccent)]
      item.selected.badgeTextAttributes = [.foregroundColor: UIColor(onAccent)]
    }
    UITabBar.appearance().standardAppearance = tabs
    UITabBar.appearance().scrollEdgeAppearance = tabs
    UITableView.appearance().backgroundColor = UIColor(paper)
    UITableView.appearance().separatorColor = UIColor(border)
    UITextField.appearance().tintColor = UIColor(accentText)
    UITextView.appearance().tintColor = UIColor(accentText)
    UISwitch.appearance().onTintColor = UIColor(maroon)
    UIWindow.appearance().backgroundColor = UIColor(paper)
  }
}
struct Wordmark: View {
  var small = false
  var size: CGFloat? = nil
  private var pointSize: CGFloat { size ?? (small ? 25 : 36) }
  var body: some View {
    HStack(spacing: 2) {
      Text("maroon").font(.system(size: pointSize, weight: .black, design: .rounded)).tracking(-1.6)
      Text("social").font(.system(size: pointSize, weight: .regular, design: .serif)).italic().tracking(-1.5)
    }.fixedSize().accessibilityElement(children: .ignore).accessibilityLabel("Maroon Social")
  }
}

enum LoadingWordmarkTiming {
  static let leadIn = 0.12
  static let fill = 0.56
  static let fullHold = 0.16
  static let settle = 0.18
  static let minimumFill = leadIn + fill + fullHold
}

/// The complete white artwork is always present. A single continuous mask fills
/// both words maroon, then holds until the request has actually finished.
struct LoadingWordmark: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var animating = true
  var size: CGFloat = 43
  @State private var fill: CGFloat = 0
  @State private var maroonOpacity = 0.0
  private var active: Bool { animating && !reduceMotion }
  private var mark: some View {
    Image("LaunchWordmark").resizable().renderingMode(.template)
      .frame(width: 320 * size / 43, height: 56 * size / 43)
  }
  var body: some View {
    mark.foregroundStyle(Palette.ink)
      .overlay(alignment: .leading) {
        mark.foregroundStyle(Palette.maroon)
          // A fine light edge keeps the thin serif letters legible without
          // changing their maroon interior or hiding the initial white mark.
          .shadow(color: Palette.ink.opacity(0.55), radius: 0.5)
          .mask(alignment: .leading) {
            Rectangle().frame(width: 320 * size / 43 * fill)
          }
          .opacity(maroonOpacity)
      }
      .task(id: active) {
        guard active else {
          withAnimation(reduceMotion ? nil : .easeOut(duration: LoadingWordmarkTiming.settle)) { maroonOpacity = 0 }
          return
        }
        // Reset only for a new load, never for a layout update.
        var reset = Transaction(); reset.disablesAnimations = true
        withTransaction(reset) { fill = 0; maroonOpacity = 1 }
        do { try await Task.sleep(for: .seconds(LoadingWordmarkTiming.leadIn)) } catch { return }
        withAnimation(.easeInOut(duration: LoadingWordmarkTiming.fill)) { fill = 1 }
      }
      .accessibilityElement(children: .ignore).accessibilityLabel(animating ? "Maroon Social, loading" : "Maroon Social")
  }
}
struct SectionHeading: View {
  let title: String
  var eyebrow: String? = nil
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let eyebrow {
        Text(eyebrow.uppercased()).font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(Palette.secondary)
      }
      Text(title).font(.system(size: 32, weight: .bold, design: .serif)).tracking(-0.8).foregroundStyle(Palette.ink)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}
struct Pill: View {
  let text: String
  var icon: String? = nil
  var selected = false
  var body: some View {
    HStack(spacing: 5) { if let icon { Image(systemName: icon) }; Text(text) }
      .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 14).padding(.vertical, 9)
      .background(selected ? Palette.maroon : Palette.surface, in: Capsule())
      .foregroundStyle(selected ? Palette.onAccent : Palette.ink)
      .overlay(Capsule().strokeBorder(selected ? .clear : Palette.border, lineWidth: 0.75))
  }
}

/// Motion is contained inside the control so changing filters never animates list reordering.
struct CompactSelector: View {
  let options: [String]
  @Binding var selection: String
  var expands = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Namespace private var highlight
  var body: some View {
    let layout = dynamicTypeSize.isAccessibilitySize && options.count > 2
      ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 2))
    layout {
      ForEach(options, id: \.self) { option in
        Button { selection = option } label: {
          Text(option).font(.subheadline.weight(.semibold))
            .foregroundStyle(selection == option ? Palette.ink : Palette.secondary)
            .padding(.horizontal, 12).padding(.vertical, 4).frame(maxWidth: expands ? .infinity : nil, minHeight: 44)
            .background {
              if selection == option {
                Capsule().fill(Palette.maroon).matchedGeometryEffect(id: "selection", in: highlight)
              }
            }.contentShape(Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(selection == option ? .isSelected : [])
      }
    }.padding(3).background(Palette.surface, in: Capsule())
      .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86), value: selection)
  }
}

struct ControlPressStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.opacity(!enabled ? 0.4 : configuration.isPressed ? 0.74 : 1)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
  }
}
struct PrimaryButton: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(17)
      .background(enabled ? Palette.maroon : Palette.elevated, in: RoundedRectangle(cornerRadius: 16))
      .foregroundStyle(enabled ? Palette.onAccent : Palette.secondary)
      .opacity(configuration.isPressed ? 0.8 : 1)
  }
}
struct Card<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
      .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.border.opacity(0.45), lineWidth: 0.5))
  }
}
struct Avatar: View {
  var symbol = "person.fill"
  var size: CGFloat = 36
  var body: some View {
    Image(systemName: symbol).font(.system(size: size * 0.42, weight: .semibold))
      .foregroundStyle(Palette.onAccent).frame(width: size, height: size)
      .background(Palette.maroon, in: Circle())
  }
}
func shortAge(_ date: Date) -> String {
  let seconds = max(0, Int(Date.now.timeIntervalSince(date)))
  if seconds < 60 { return "now" }
  if seconds < 3600 { return "\(seconds / 60)m" }
  if seconds < 86400 { return "\(seconds / 3600)h" }
  return "\(seconds / 86400)d"
}
struct EmptyCard: View {
  let icon: String
  let title: String
  let detail: String
  var body: some View {
    ContentUnavailableView(title, systemImage: icon, description: Text(detail)).padding(.vertical, 25)
  }
}
extension View {
  func appBackground() -> some View {
    self.background(Palette.paper.ignoresSafeArea())
      .toolbarBackground(Palette.paper, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
  }
}

struct DraftCancelButton: View {
  let hasChanges: Bool
  @Environment(\.dismiss) private var dismiss
  @State private var confirmDiscard = false
  var body: some View {
    Button("Cancel") { if hasChanges { confirmDiscard = true } else { dismiss() } }
      .alert("Discard this draft?", isPresented: $confirmDiscard) {
        Button("Discard draft", role: .destructive) { dismiss() }
        Button("Keep editing", role: .cancel) {}
      } message: { Text("Your unsent changes will be lost.") }
  }
}

/// A compact dismissal control lives in the screen's existing chrome, never in
/// an extra keyboard toolbar that pushes the composer and scroll view upward.
struct KeyboardDismissButton: View {
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: "keyboard.chevron.compact.down")
        .font(.system(size: 18, weight: .medium)).frame(minWidth: 44, minHeight: 44)
    }.buttonStyle(.plain).accessibilityLabel("Hide keyboard")
      .accessibilityIdentifier("hideKeyboard")
  }
}
