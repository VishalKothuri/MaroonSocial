import SwiftUI

struct EmailLoginView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let linkExisting: Bool
  @State private var email = ""
  @State private var code = ""
  @State private var username = ""
  @State private var adult = false
  @State private var agreedToLink = false
  @State private var verificationWork: Task<Void, Never>?
  @FocusState private var field: Field?
  private enum Field { case email, code, username }
  private var auth: EmailAuthService { store.auth }
  private var validUsername: Bool { username.range(of: "^[a-zA-Z0-9_]{3,20}$", options: .regularExpression) != nil }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text(linkExisting ? "Keep your account" : "Email login").font(.title2.bold())
        Text(linkExisting
          ? "Link this account to a personal email you control. Your posts, chats, username and privacy settings stay with this account."
          : "Use your personal email to sign in or recover your Maroon Social account on another device.")
          .foregroundStyle(Palette.secondary)
        Text("Personal email is private login information. It does not verify a TAMU mailbox or current enrollment.")
          .font(.caption).foregroundStyle(Palette.secondary)
        if !auth.checkedAvailability { ProgressView("Checking availability…") }
        else if !auth.enabled {
          Card { VStack(alignment: .leading, spacing: 10) {
            Label("Email login is not available yet", systemImage: "envelope.badge.shield.half.filled").font(.headline)
            Text("The app owner still needs to configure a verified sender for maroonsocial.chat and test email delivery. Existing device accounts continue to work.").font(.subheadline)
            Button("Check again") { Task { await auth.checkAvailability() } }.buttonStyle(.bordered)
          } }
        } else if auth.signedIn {
          if !linkExisting {
            Text("If this is your first visit, choose your community username.").font(.subheadline)
            TextField("Username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
              .focused($field, equals: .username).padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
            Toggle("I’m 18 or older", isOn: $adult)
          }
          Button(store.busy ? "Connecting…" : linkExisting ? "Link this account" : "Continue") {
            field = nil
            Task { if await store.finishEmailLogin(username: username, adult: adult, linkExisting: linkExisting) { dismiss() } }
          }.buttonStyle(PrimaryButton()).disabled(store.busy || (!linkExisting && !validUsername && !username.isEmpty))
          Text("For an existing email account, leave the username blank to restore it.").font(.caption).foregroundStyle(Palette.secondary).opacity(linkExisting ? 0 : 1)
          Button("Use another email") { Task { do { try await auth.signOutLocally() } catch { auth.error = error.localizedDescription } } }.disabled(store.busy || auth.busy)
        } else if auth.codeSent {
          Text("Enter the code sent to \(auth.email).").font(.subheadline)
          TextField("6-digit code", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
            .focused($field, equals: .code).padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("emailOTP")
          Button(auth.busy ? "Checking…" : "Verify code") {
            field = nil
            verificationWork = Task {
              if await auth.verifyCode(code), !Task.isCancelled, linkExisting {
                if await store.finishEmailLogin(username: store.state.username, adult: true, linkExisting: true) { dismiss() }
              }
            }
          }.buttonStyle(PrimaryButton()).disabled(auth.busy || code.count != 6)
          TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = max(0, Int(ceil(auth.resendAfter.timeIntervalSince(context.date))))
            Button(seconds > 0 ? "Resend in \(seconds)s" : "Send another code") { Task { _ = await auth.requestCode(auth.email) } }
              .disabled(auth.busy || seconds > 0)
          }
          Button("Change email") { auth.changeEmail(); code = ""; field = .email }.disabled(auth.busy)
        } else {
          TextField("Personal email", text: $email).keyboardType(.emailAddress).textContentType(.emailAddress)
            .textInputAutocapitalization(.never).autocorrectionDisabled().focused($field, equals: .email)
            .padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("loginEmail")
          if linkExisting {
            Toggle("Link the current @\(store.state.username) account to this email", isOn: $agreedToLink).font(.subheadline)
          }
          Button(auth.busy ? "Sending…" : "Send login code") {
            field = nil
            Task { if await auth.requestCode(email) { field = .code } }
          }.buttonStyle(PrimaryButton()).disabled(auth.busy || email.isEmpty || (linkExisting && !agreedToLink))
        }
        if let error = auth.error { Text(error).font(.subheadline).foregroundStyle(Palette.accentText) }
      }.padding(22)
    }.scrollDismissesKeyboard(.interactively).appBackground().navigationTitle(linkExisting ? "Email recovery" : "Sign in")
      .navigationBarTitleDisplayMode(.inline).task { await auth.checkAvailability() }
      .onAppear { username = linkExisting ? store.state.username : "" }
      .onDisappear { verificationWork?.cancel() }
      .interactiveDismissDisabled(auth.busy || store.busy)
      .navigationBarBackButtonHidden(auth.busy || store.busy)
  }
}
