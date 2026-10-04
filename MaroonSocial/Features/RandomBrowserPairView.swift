import SwiftUI

struct RandomBrowserPairView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var code: String?
  @State private var expires: Date?
  @State private var busy = false
  @State private var error: String?
  private struct Pair: Decodable { let code: String; let expiresAt: Double; enum CodingKeys: String, CodingKey { case code; case expiresAt = "expires_at" } }
  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 22) {
        Text("Use interest discovery in your browser").font(.title2.bold())
        Text("Open the Maroon Social web app below, then enter this one-time code. It grants only interest discovery for one hour; it does not share your account password or let the browser read your Inbox.").foregroundStyle(Palette.secondary)
        if let code, let expires {
          TimelineView(.periodic(from: .now, by: 1)) { context in
            if context.date < expires {
              Text(code).font(.system(.title, design: .monospaced).bold()).textSelection(.enabled).accessibilityIdentifier("browserPairCode")
              Text("Expires in \(max(0, Int(expires.timeIntervalSince(context.date)))) seconds").font(.caption).foregroundStyle(Palette.secondary)
              Button("Copy code") { UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: code]], options: [.expirationDate: expires, .localOnly: true]) }
            } else { Text("This code expired. Create a new one when your browser is ready.").foregroundStyle(Palette.secondary) }
          }
        }
        Button(busy ? "Creating code…" : "Create one-time code") { Task { await create() } }.buttonStyle(PrimaryButton()).disabled(busy)
        Link("Open Maroon Social", destination: URL(string: "https://maroon-social-web.vercel.app")!)
        if let error { Text(error).font(.callout).foregroundStyle(Palette.accentText) }
        Text("Only enter a code on the site you opened yourself. Do not share it with another person.").font(.caption).foregroundStyle(Palette.secondary)
        Spacer()
      }.padding(24).appBackground().navigationTitle("Pair browser").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }
  private func create() async {
    guard !busy else { return }; busy = true; error = nil; defer { busy = false }
    do {
      guard !store.fixtureMode else { throw SocialServiceError(error: "Browser pairing needs a connected account.", code: "unavailable") }
      let result = try JSONDecoder().decode(Pair.self, from: await store.social.sendData(endpoint: "random-browser", action: "pair.create"))
      code = result.code; expires = Date(timeIntervalSince1970: result.expiresAt)
    } catch { self.error = error.localizedDescription }
  }
}
