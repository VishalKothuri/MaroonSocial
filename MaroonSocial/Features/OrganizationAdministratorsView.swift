import SwiftUI

/// Private administrator access for one organization. The owner sees and manages
/// the administrator list and invitations; other administrators only see their own role.
struct OrganizationAdministratorsView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let organizationID: String
  @State private var access: OrganizationAccess?
  @State private var loading = true
  @State private var error: String?
  @State private var notice: String?
  @State private var busy = false
  @State private var inviteUsername = ""
  @State private var inviteKind = OrganizationInvitationKind.admin
  @State private var inviteError: String?
  /// One draft, one nonce: retrying after a failure reuses it so the server returns the same invitation.
  @State private var nonce = UUID().uuidString
  @State private var removing: OrganizationAccess.Administrator?
  @State private var leaving = false
  @FocusState private var usernameFocused: Bool
  private var service: OrganizationAccessService { OrganizationAccessService(social: store.social, fixtureMode: store.fixtureMode) }
  private var inviteValid: Bool { OrganizationAccessService.validUsername(inviteUsername) }
  var body: some View {
    ScrollView { VStack(alignment: .leading, spacing: 16) {
      if let access {
        Card { VStack(alignment: .leading, spacing: 8) {
          Label(access.organizationName, systemImage: access.status == "verified" ? "checkmark.seal.fill" : "clock").font(.title3.bold())
          Text(access.isOwner ? "You are the owner" : "You are an administrator").font(.subheadline.bold()).accessibilityIdentifier("organizationMyRole")
          Text(access.isOwner
            ? "Administrators publish events, edit the profile and answer organization messages. Only the owner invites or removes administrators and hands over ownership."
            : "You can publish events, edit the profile and answer organization messages. Only the owner manages administrator access; the administrator list is private to the owner.")
            .font(.caption).foregroundStyle(Palette.secondary)
          if !access.hasOwner { Text("This organization has no owner. Contact a reviewer to restore it.").font(.caption).foregroundStyle(Palette.secondary) }
          // Outcome of the latest change stays near the top, where it is visible after any card's action.
          if let notice { Text(notice).font(.caption.weight(.semibold)).accessibilityIdentifier("organizationAccessNotice") }
          if let error { Text(error).font(.caption).foregroundStyle(Palette.secondary).accessibilityIdentifier("organizationAccessError") }
        } }
        if access.isOwner {
          Card { VStack(alignment: .leading, spacing: 12) {
            Text("Administrators").font(.headline)
            ForEach(access.administrators) { administrator in
              HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                  Text("@" + administrator.username + (administrator.isMe ? " (you)" : "")).font(.subheadline.bold())
                  Text(administrator.role == "owner" ? "Owner" : "Administrator").font(.caption).foregroundStyle(Palette.secondary)
                }.accessibilityElement(children: .combine).accessibilityIdentifier("organizationAdministrator")
                Spacer()
                if administrator.role == "admin" && !administrator.isMe {
                  Button("Remove", role: .destructive) { removing = administrator }.buttonStyle(.bordered).disabled(busy).accessibilityIdentifier("organizationAdministratorRemove")
                }
              }
            }
            Text("\(access.administrators.count) of 10 administrator seats used.").font(.caption).foregroundStyle(Palette.secondary)
          } }
          Card { VStack(alignment: .leading, spacing: 12) {
            Text("Pending invitations").font(.headline)
            if access.pending.isEmpty { Text("No pending invitations.").font(.caption).foregroundStyle(Palette.secondary) }
            ForEach(access.pending) { invitation in
              HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                  Text("@" + invitation.username).font(.subheadline.bold())
                  Text(OrganizationInvitationKind.label(for: invitation.kind) + " · expires " + invitation.expiresAt.formatted(.dateTime.month().day())).font(.caption).foregroundStyle(Palette.secondary)
                }.accessibilityElement(children: .combine).accessibilityIdentifier("organizationPendingInvitation")
                Spacer()
                Button("Revoke") { Task { await revoke(invitation) } }.buttonStyle(.bordered).disabled(busy).accessibilityIdentifier("organizationInvitationRevoke")
              }
            }
          } }
          Card { VStack(alignment: .leading, spacing: 12) {
            Text("Invite an administrator").font(.headline)
            TextField("Account username", text: $inviteUsername).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable)
              .padding(12).background(Palette.elevated, in: RoundedRectangle(cornerRadius: 12)).focused($usernameFocused).submitLabel(.send)
              .onSubmit { Task { await sendInvitation() } }.accessibilityIdentifier("organizationInviteUsername")
            Picker("Invitation type", selection: $inviteKind) { ForEach(OrganizationInvitationKind.allCases) { Text($0.title).tag($0) } }
              .pickerStyle(.segmented).accessibilityIdentifier("organizationInviteKind")
            Text(inviteKind == .admin
              ? "They accept or decline from Settings › Your organizations. Accepting shows their account username here. Invitations expire after seven days."
              : "Ownership can only be offered to an administrator who already accepted. After they accept, you stay on as an administrator and only they manage this list.")
              .font(.caption).foregroundStyle(Palette.secondary)
            if !inviteUsername.isEmpty && !inviteValid { Text("Usernames are 3–20 lowercase letters, numbers or underscores.").font(.caption).foregroundStyle(Palette.secondary) }
            if let inviteError { Text(inviteError).font(.caption).foregroundStyle(Palette.secondary).accessibilityIdentifier("organizationInviteError") }
            Button(busy ? "Sending…" : "Send invitation") { Task { await sendInvitation() } }.buttonStyle(PrimaryButton()).disabled(busy || !inviteValid).accessibilityIdentifier("organizationInviteSend")
          } }
        } else {
          Card { VStack(alignment: .leading, spacing: 12) {
            Text("Your access").font(.headline)
            Text("Leaving closes your private organization conversations and removes these tools. The owner can invite you again.").font(.caption).foregroundStyle(Palette.secondary)
            Button("Leave administrator role", role: .destructive) { leaving = true }.buttonStyle(.bordered).disabled(busy).accessibilityIdentifier("organizationLeaveRole")
          } }
        }
      } else if loading { ProgressView("Loading administrator access…").frame(maxWidth: .infinity).padding(.top, 40) }
      else {
        EmptyCard(icon: "person.badge.shield.checkmark", title: "Administrator tools unavailable", detail: error ?? "This organization could not be loaded.")
        Button("Try again") { Task { loading = true; await load() } }.buttonStyle(.bordered).accessibilityIdentifier("organizationAccessRetry")
      }
    }.padding(16) }
    .maroonRefreshable(scope: "organization-access") { await load() }
    .task { await load() }
    .appBackground().navigationTitle("Administrators").navigationBarTitleDisplayMode(.inline)
    .confirmationDialog("Remove this administrator?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible, presenting: removing) { administrator in
      Button("Remove @\(administrator.username)", role: .destructive) { Task { await remove(administrator) } }.accessibilityIdentifier("organizationAdministratorRemoveConfirm")
    } message: { administrator in
      Text("@\(administrator.username) loses publishing and private conversation access. Their open organization conversations are closed, not handed to you.")
    }
    .confirmationDialog("Leave administrator role?", isPresented: $leaving, titleVisibility: .visible) {
      Button("Leave administrator role", role: .destructive) { Task { await leave() } }.accessibilityIdentifier("organizationLeaveConfirm")
    } message: { Text("You lose publishing access and your private organization conversations are closed.") }
  }
  @MainActor private func load() async {
    do { access = try await service.access(organization: organizationID); error = nil }
    catch { if !(error is CancellationError) { self.error = error.localizedDescription } }
    loading = false
  }
  /// Runs one administrator change, then reloads this screen and the snapshot so canManage stays truthful.
  @MainActor private func perform(_ work: () async throws -> Void) async -> String? {
    guard !busy else { return "Please wait for the current change to finish." }
    busy = true; defer { busy = false }
    do { try await work() } catch { AppHaptics.shared.play(.error); return error.localizedDescription }
    await load(); await store.refreshAndWait(); AppHaptics.shared.play(.success); return nil
  }
  @MainActor private func sendInvitation() async {
    usernameFocused = false
    let username = OrganizationAccessService.normalizedUsername(inviteUsername), kind = inviteKind, draftNonce = nonce
    guard OrganizationAccessService.validUsername(username) else { inviteError = "Enter the account username first."; return }
    if let failure = await perform({ _ = try await service.invite(organization: organizationID, username: username, kind: kind, nonce: draftNonce) }) { inviteError = failure; return }
    inviteError = nil; inviteUsername = ""; inviteKind = .admin; nonce = UUID().uuidString
    notice = kind == .admin ? "Invitation sent to @\(username)." : "Ownership offered to @\(username). You remain the owner until they accept."
  }
  @MainActor private func remove(_ administrator: OrganizationAccess.Administrator) async {
    error = await perform { try await service.remove(organization: organizationID, administratorKey: administrator.id) }
    if error == nil { notice = "@\(administrator.username) is no longer an administrator." }
  }
  @MainActor private func revoke(_ invitation: OrganizationAccess.Pending) async {
    error = await perform { try await service.revoke(organization: organizationID, invitation: invitation.id) }
    if error == nil { notice = "Invitation to @\(invitation.username) revoked." }
  }
  @MainActor private func leave() async {
    guard !busy else { return }
    busy = true; defer { busy = false }
    do { try await service.leave(organization: organizationID) } catch { self.error = error.localizedDescription; AppHaptics.shared.play(.error); return }
    await store.refreshAndWait(); AppHaptics.shared.play(.success); dismiss()
  }
}
