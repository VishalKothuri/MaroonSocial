import SwiftUI

struct VerificationView: View {
  @State private var service: VerificationService
  @State private var email = ""
  @State private var code = ""
  @FocusState private var codeFocused: Bool
  init(social: SocialService) { _service = State(initialValue: VerificationService(social: social)) }
  private var validEmail: Bool {
    email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      .range(of: "^[a-z0-9](?:[a-z0-9._-]{0,62}[a-z0-9])?@tamu\\.edu$", options: .regularExpression) != nil
  }
  var body: some View {
    Form {
      Section {
        Label(service.status?.verified == true ? "TAMU mailbox verified" : "Verify your TAMU mailbox", systemImage: service.status?.verified == true ? "checkmark.seal.fill" : "envelope.badge")
          .font(.headline).foregroundStyle(Palette.accentText)
        Text("Confirm that you can receive mail at an @tamu.edu address. This does not prove current student enrollment.").font(.subheadline)
        if let expires = service.status?.expiresAt, service.status?.verified == true {
          Text("Valid until \(expires.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
        }
      }
      if service.status == nil && service.error == nil { ProgressView("Checking availability…") }
      else if service.status?.enabled == false {
        Section {
          Label("Email delivery is being configured", systemImage: "clock")
          Text("The owner must verify a sending address before this app can deliver codes. Your account stays available for development testing.").font(.subheadline).foregroundStyle(.secondary)
          Button("Check again") { Task { await service.refresh() } }.disabled(service.busy)
        }
      } else if service.status?.verified != true {
        if service.challengeID == nil {
          Section("University mailbox") {
            TextField("you@tamu.edu", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.emailAddress)
            Button("Send verification code") { Task { if await service.request(email: email.trimmingCharacters(in: .whitespacesAndNewlines)) { email = ""; codeFocused = true } } }.disabled(!validEmail || service.busy)
          }
        } else {
          Section {
            TextField("6-digit code", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode).focused($codeFocused)
              .onChange(of: code) { _, value in code = String(value.filter(\.isNumber).prefix(6)) }
            Button("Verify mailbox") { Task { if await service.confirm(code: code) { code = ""; codeFocused = false } } }.disabled(code.count != 6 || service.busy)
            Button("Use another address or request a new code") { Task { await service.cancel(); code = "" } }.disabled(service.busy)
          } header: { Text("Check your TAMU inbox") } footer: { Text("Codes expire after 10 minutes. Check your spam folder before requesting another.") }
        }
      }
      if service.busy { ProgressView("Working…") }
      if let message = service.notice { Section { Text(message).font(.subheadline) } }
      if let error = service.error { Section { Text(error).font(.subheadline).foregroundStyle(.red); Button("Retry") { Task { await service.refresh() } } } }
      Section("Your privacy") {
        Text("Your mailbox is sent to the email delivery provider only to deliver the code. The app does not add it to your public profile. Verification records use a protected identifier for duplicate and abuse checks; this is not a promise of anonymity from the service operator.").font(.caption).foregroundStyle(.secondary)
      }
    }.scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden).appBackground().navigationTitle("TAMU verification").navigationBarTitleDisplayMode(.inline)
      .task { await service.refresh() }
      .toolbar { ToolbarItem(placement: .topBarTrailing) { if codeFocused { KeyboardDismissButton { codeFocused = false } } } }
  }
}
