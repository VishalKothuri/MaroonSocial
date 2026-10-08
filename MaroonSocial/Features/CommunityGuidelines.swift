import SwiftUI

/// The community guidelines version this build shows. The server's config row holds the version it
/// requires; a member accepts it once before their first post, reply, message request or chat message.
let GuidelinesVersion = 1

/// One support address, used everywhere the app offers contact.
enum SupportContact {
  static let email = "support@maroonsocial.chat"
  static var mailURL: URL { URL(string: "mailto:\(email)")! }
}

/// The guidelines summary (version `GuidelinesVersion`). The full text is on the web site.
enum CommunityGuidelines {
  static let version = GuidelinesVersion
  static let fullTextURL = URL(string: "https://maroonsocial.chat/guidelines.html")!
  static let crisisLine = "988"
  struct Point: Identifiable {
    let symbol: String
    let title: String
    let detail: String
    var id: String { title }
  }
  static let points: [Point] = [
    Point(symbol: "hand.thumbsup", title: "Be an Aggie", detail: "Treat people the way you’d want to be treated in the MSC: honest, respectful, and willing to help."),
    Point(symbol: "person.crop.circle.badge.xmark", title: "Leave other students out of it", detail: "Don’t name, initial or picture other students to mock or expose them."),
    Point(symbol: "exclamationmark.bubble", title: "No harassment, hate or threats", detail: "No bullying, slurs, threats of violence, or encouraging anyone to hurt themselves."),
    Point(symbol: "eye.slash", title: "Keep sexual content in its place", detail: "Nothing sexual outside the 18+ NSFW community, and never anything involving minors."),
    Point(symbol: "lock.shield", title: "No doxxing, spam or scams", detail: "Don’t share private information, flood the feed, run scams or sell anything illegal."),
    Point(symbol: "person.badge.shield.checkmark", title: "Anonymity is not immunity", detail: "We act on reports, remove content and suspend accounts, and respond to valid law-enforcement requests."),
    Point(symbol: "flag", title: "Report and block", detail: "Use Report or Block on any post, reply or message. Moderators review every report."),
    Point(symbol: "heart.text.square", title: "In crisis? Call or text 988", detail: "The Suicide & Crisis Lifeline answers 24/7. In an emergency, call 911."),
  ]
}

/// One send screen's link to the guidelines sheet. Before a send it presents the sheet when the
/// member still has to accept (as far as the snapshot says); a `guidelines:` answer from the server
/// presents it too. "I agree" accepts and then runs the send again, once.
@Observable @MainActor final class GuidelinesGate {
  var presented = false
  private var retry: (() -> Void)?
  private var accepted = false
  /// The send running now is the retry that follows an acceptance (a second refusal shows an alert).
  private var retrying = false
  /// Call first in a send action: true means the sheet is up and the send waits for "I agree".
  func intercept(_ store: AppStore, retry: @escaping () -> Void) -> Bool {
    guard store.guidelinesRequired else { return false }
    present(retry)
    return true
  }
  /// Runs the send itself. Returns true when the server refused it for the guidelines: the sheet is
  /// up (or, after a retry, an alert explains it) and the caller keeps its draft without an error.
  func run(_ store: AppStore, retry: @escaping () -> Void, _ send: () async -> Void) async -> Bool {
    store.beginGatedSend()
    await send()
    let refusal = store.endGatedSend()
    defer { retrying = false }
    guard let refusal else { return false }
    if retrying { store.notice = refusal } else { present(retry) }
    return true
  }
  private func present(_ retry: @escaping () -> Void) {
    self.retry = retry; accepted = false; presented = true
  }
  /// "I agree" succeeded: the sheet closes and the send runs again when it is gone.
  func agreed() { accepted = true; presented = false }
  /// "Not now": the sheet closes and the draft stays.
  func declined() { accepted = false; presented = false }
  /// The sheet's `onDismiss`.
  func dismissed() {
    let next = accepted ? retry : nil
    retry = nil; accepted = false
    guard let next else { return }
    retrying = true
    next()
  }
}

extension View {
  /// Presents the guidelines sheet for `gate`.
  func guidelinesSheet(_ gate: GuidelinesGate) -> some View {
    modifier(GuidelinesSheetModifier(gate: gate))
  }
}
private struct GuidelinesSheetModifier: ViewModifier {
  @Bindable var gate: GuidelinesGate
  func body(content: Content) -> some View {
    content.sheet(isPresented: $gate.presented, onDismiss: gate.dismissed) {
      GuidelinesSheet(onAgree: gate.agreed, onDecline: gate.declined)
    }
  }
}

/// The summary, a link to the full text, "I agree" and "Not now".
struct GuidelinesSheet: View {
  @Environment(AppStore.self) private var store
  let onAgree: () -> Void
  let onDecline: () -> Void
  @State private var accepting = false
  @State private var error: String?
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Before you post").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text("Maroon Social is for Aggies. Agree to the community guidelines once, then post, reply and message as usual.")
              .font(.subheadline).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
          }
          if store.guidelinesNeedAppUpdate { GuidelinesUpdateNote() }
          GuidelinesSummary()
          Link(destination: CommunityGuidelines.fullTextURL) {
            Label("Read the full guidelines", systemImage: "arrow.up.right.square").font(.subheadline.weight(.semibold)).frame(minHeight: 44)
          }.accessibilityIdentifier("guidelinesFullText")
          if let error { Text(error).font(.subheadline).foregroundStyle(Palette.maroonBright).accessibilityIdentifier("guidelinesError") }
        }.padding(20)
          .accessibilityElement(children: .contain).accessibilityIdentifier("guidelinesSheet")
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        VStack(spacing: 6) {
          Button {
            guard !accepting else { return }
            AppHaptics.shared.play(.impact); accepting = true; error = nil
            Task {
              let failure = await store.acceptGuidelines()
              accepting = false
              if let failure { AppHaptics.shared.play(.error); error = failure } else { AppHaptics.shared.play(.success); onAgree() }
            }
          } label: {
            HStack(spacing: 8) { if accepting { ProgressView().tint(Palette.onAccent) }; Text("I agree") }
          }.buttonStyle(PrimaryButton()).disabled(accepting || store.guidelinesNeedAppUpdate).accessibilityIdentifier("acceptGuidelines")
          Button("Not now") { AppHaptics.shared.play(.impact); onDecline() }
            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44).disabled(accepting)
            .accessibilityIdentifier("declineGuidelines")
        }.padding(.horizontal, 20).padding(.vertical, 12).background(Palette.paper)
      }
      .appBackground().navigationTitle("Community guidelines").navigationBarTitleDisplayMode(.inline)
    }
    .presentationDetents([.large]).presentationDragIndicator(.visible)
    .interactiveDismissDisabled(accepting)
  }
}

/// The server requires guidelines newer than this build shows: agreeing waits for an app update.
struct GuidelinesUpdateNote: View {
  var body: some View {
    Label(AppStore.guidelinesUpdateCopy, systemImage: "arrow.down.app")
      .font(.subheadline).foregroundStyle(Palette.maroonBright).fixedSize(horizontal: false, vertical: true)
      .accessibilityIdentifier("guidelinesUpdateNote")
  }
}

/// The bullet summary shared by the sheet and Settings.
struct GuidelinesSummary: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      ForEach(CommunityGuidelines.points) { point in
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: point.symbol).font(.body.weight(.semibold)).foregroundStyle(Palette.maroonBright).frame(width: 26)
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 3) {
            Text(point.title).font(.subheadline.weight(.semibold))
            Text(point.detail).font(.subheadline).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
          }
        }.accessibilityElement(children: .combine)
      }
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "envelope").font(.body.weight(.semibold)).foregroundStyle(Palette.maroonBright).frame(width: 26).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 3) {
          Text("Questions or appeals").font(.subheadline.weight(.semibold))
          // A visible link with a full-size touch target (the app tint is ink, the same as body text).
          Link(destination: SupportContact.mailURL) {
            Text(SupportContact.email).font(.subheadline.weight(.semibold)).underline().foregroundStyle(Palette.maroonBright)
              .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
          }.accessibilityLabel("Email \(SupportContact.email)").accessibilityIdentifier("guidelinesSupportEmail")
        }
      }
    }
  }
}

/// Settings › Community guidelines: the summary, the full text and the accepted version and date.
struct GuidelinesSettingsView: View {
  @Environment(AppStore.self) private var store
  @State private var accepting = false
  @State private var error: String?
  var body: some View {
    List {
      Section { statusRow } footer: {
        if store.guidelinesRequired { Text("You’ll be asked to agree before your next post, reply or message.") }
      }
      Section("Summary") { GuidelinesSummary().padding(.vertical, 6) }
      Section {
        Link(destination: CommunityGuidelines.fullTextURL) { Label("Read the full guidelines", systemImage: "arrow.up.right.square") }
          .accessibilityIdentifier("settingsGuidelinesFullText")
        Link(destination: SupportContact.mailURL) { Label("Contact \(SupportContact.email)", systemImage: "envelope") }
      }
      if store.guidelinesRequired && store.guidelinesNeedAppUpdate {
        Section { GuidelinesUpdateNote() }
      } else if store.guidelinesRequired {
        Section {
          Button {
            guard !accepting else { return }
            accepting = true; error = nil
            Task {
              let failure = await store.acceptGuidelines()
              accepting = false
              if let failure { AppHaptics.shared.play(.error); error = failure } else { AppHaptics.shared.play(.success) }
            }
          } label: { HStack { Text("I agree"); Spacer(); if accepting { ProgressView() } } }
            .disabled(accepting).accessibilityIdentifier("settingsAcceptGuidelines")
          if let error { Text(error).font(.subheadline).foregroundStyle(Palette.maroonBright) }
        }
      }
    }.scrollContentBackground(.hidden).appBackground().navigationTitle("Community guidelines").navigationBarTitleDisplayMode(.inline)
  }
  private var statusRow: some View {
    LabeledContent("Status") {
      Text(GuidelinesSettingsView.status(store.guidelines)).multilineTextAlignment(.trailing)
    }.accessibilityIdentifier("guidelinesStatus")
  }
  /// "Accepted version 1 on Oct 7, 2026", "Not accepted yet", or the version this build shows when the
  /// server does not report acceptance.
  static func status(_ status: GuidelinesStatus?) -> String {
    guard let status else { return "Version \(GuidelinesVersion)" }
    guard status.satisfied, let accepted = status.accepted else { return "Not accepted yet" }
    guard let date = status.acceptedAt else { return "Accepted version \(accepted)" }
    return "Accepted version \(accepted) on \(date.formatted(date: .abbreviated, time: .omitted))"
  }
}
