import SwiftUI

/// The anonymity switch for posts and replies. Turning anonymity off the first
/// time asks the member to confirm the username that every named post and reply
/// will carry; after that the switch flips directly.
struct PublicIdentityToggle: View {
  @Environment(AppStore.self) private var store
  let title: String
  @Binding var anonymous: Bool
  var identifier: String
  @State private var confirming = false
  var body: some View {
    Toggle(title, isOn: Binding(
      get: { anonymous },
      set: { value in
        if value || store.publicNameConfirmed { anonymous = value }
        else { AppHaptics.shared.play(.impact); confirming = true }
      }
    )).accessibilityIdentifier(identifier)
      .sheet(isPresented: $confirming) {
        PublicUsernameSheet { anonymous = false }
          .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
      }
  }
}

/// "Choose the name you post under." The current username is offered first; a
/// new one saves to the account before named posting is unlocked.
struct PublicUsernameSheet: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let onConfirmed: () -> Void
  @State private var username = ""
  @State private var saving = false
  @State private var error: String?
  @FocusState private var focused: Bool
  private var normalized: String { AccountUsernameRules.normalized(username) }
  private var changed: Bool { normalized != store.state.username }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Post as yourself").font(.title2.bold())
            Text("Named posts and replies show this username to everyone. It is tied to your account: anonymous posts stay anonymous, and you can change the name later in your profile.")
              .font(.subheadline).foregroundStyle(Palette.secondary)
          }
          VStack(alignment: .leading, spacing: 8) {
            Text("Username").font(.caption.weight(.semibold)).foregroundStyle(Palette.secondary)
            HStack(spacing: 6) {
              Text("@").foregroundStyle(Palette.secondary)
              TextField("username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focused).submitLabel(.done).onSubmit { Task { await confirm() } }
                .accessibilityIdentifier("publicUsername").accessibilityLabel("Public username")
            }.padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
            Text("3–20 letters, numbers, or underscores.").font(.caption).foregroundStyle(Palette.secondary)
          }
          if let error { Text(error).font(.caption).foregroundStyle(Palette.accentText).accessibilityIdentifier("publicUsernameError") }
          Button { Task { await confirm() } } label: {
            HStack { if saving { ProgressView().tint(Palette.onAccent) }; Text(changed ? "Save and post as @\(normalized)" : "Post as @\(normalized)") }.frame(maxWidth: .infinity)
          }.buttonStyle(PrimaryButton()).disabled(!AccountUsernameRules.valid(username) || saving || store.busy)
            .accessibilityIdentifier("confirmPublicUsername")
        }.padding(20)
      }.scrollDismissesKeyboard(.interactively).appBackground()
        .navigationTitle("Your name").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() }.disabled(saving).accessibilityIdentifier("cancelPublicUsername") } }
        .onAppear { if username.isEmpty { username = store.state.username }; focused = store.state.username.isEmpty }
        .interactiveDismissDisabled(saving)
    }
  }
  private func confirm() async {
    guard !saving, AccountUsernameRules.valid(username) else { return }
    saving = true; error = nil
    defer { saving = false }
    if await store.updateUsername(normalized) {
      store.confirmPublicName()
      AppHaptics.shared.play(.success)
      onConfirmed()
      dismiss()
    } else {
      AppHaptics.shared.play(.error)
      error = store.notice ?? "That username could not be saved. Try another one."
    }
  }
}
