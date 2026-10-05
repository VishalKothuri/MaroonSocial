import MaroonCore
import SwiftUI

struct SettingsView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var deleting = false
  @State private var haptics = AppHaptics.shared
  @State private var mediaCacheCleared = false
  var body: some View {
    @Bindable var haptics = haptics
    NavigationStack {
      List {
        Section {
          NavigationLink { AccountProfileView().appHapticOnOpen() } label: {
          HStack(spacing: 12) {
            Avatar(size: 48)
            VStack(alignment: .leading, spacing: 6) {
              ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 10) { accountName; karmaLabel }
                VStack(alignment: .leading, spacing: 5) { accountName; karmaLabel }
              }
              Text(store.connected ? "Connected account" : "Connecting…").font(.caption).foregroundStyle(.secondary)
            }
          }
          }.accessibilityIdentifier("editAccountProfile")
          if !store.fixtureMode && !store.social.hasDeviceCredential {
            if store.auth.signedIn { Label("Personal email recovery linked", systemImage: "envelope.badge.shield.half.filled").font(.subheadline) }
            else { NavigationLink("Sign in again with personal email") { EmailLoginView(linkExisting: false).appHapticOnOpen() } }
            Button("Sign out on this device") { Task { await store.signOut(); if !store.state.onboarded { dismiss() } } }.disabled(store.busy)
          } else { NavigationLink("Link personal email for recovery") { EmailLoginView(linkExisting: true).appHapticOnOpen() } }
          NavigationLink("TAMU mailbox verification") { VerificationView(social: store.social).appHapticOnOpen() }
          NavigationLink { PushSettingsView().appHapticOnOpen() } label: { Label("Notifications", systemImage: "bell.badge") }
            .accessibilityIdentifier("settingsPushNotifications")
        }
        Section("Your collection") {
          NavigationLink { PersonalLibraryView(kind: .posts).appHapticOnOpen() } label: { Label("My posts", systemImage: "text.bubble") }
            .accessibilityIdentifier("settingsMyPosts")
          NavigationLink { PersonalLibraryView(kind: .comments).appHapticOnOpen() } label: { Label("My comments", systemImage: "bubble.left.and.bubble.right") }
            .accessibilityIdentifier("settingsMyComments")
          NavigationLink { PersonalLibraryView(kind: .saved).appHapticOnOpen() } label: { Label("Saved posts", systemImage: "bookmark") }
            .accessibilityIdentifier("settingsSavedPosts")
          NavigationLink { SavedEventsView().appHapticOnOpen() } label: { Label("Saved events", systemImage: "calendar.badge.checkmark") }
            .accessibilityIdentifier("settingsSavedEvents")
          if !store.state.hiddenPosts.isEmpty { Button("Restore hidden posts") { store.state.hiddenPosts.removeAll(); store.save() } }
        }
        Section {
          Toggle("Haptic feedback", isOn: $haptics.enabled).accessibilityIdentifier("hapticsEnabled")
        } header: { Text("Interaction") } footer: { Text("Subtle feedback for navigation, games, and completed actions.") }
        Section("People & privacy") {
          NavigationLink("Connections and requests") { ConnectionsView(social: store.social).appHapticOnOpen() }
          NavigationLink("Blocked accounts and data export") { PrivacyControlsView(social: store.social).appHapticOnOpen() }
          Button { Task { await store.social.media.wipeAndWait(); mediaCacheCleared = true; AppHaptics.shared.play(.success) } } label: {
            LabeledContent("Clear media cache") { if mediaCacheCleared { Text("Cleared") } }
          }.accessibilityIdentifier("clearMediaCache").accessibilityHint("Removes downloaded photos and videos from this device. They load again when viewed.")
          Text("Anonymous posts, anonymous replies and post-origin conversations do not show your username to other members. Posts and replies you publish by name, named classes and activities use your account username. Each group uses the alias and avatar you choose for that group.").font(.subheadline)
          Text("Messages and reports are stored on the service and are not end-to-end encrypted. Login credentials are stored securely on this device. Personal email recovery becomes available after email delivery is configured and you link your account. Verify your TAMU mailbox from the account section when email delivery is available.").font(.subheadline)
          Text("Reports are saved for review. This development service does not have a staffed emergency response team.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Organizations") { NavigationLink("Your organizations") { OrganizationsView().appHapticOnOpen() }.accessibilityIdentifier("settingsOrganizations") }
        Section("About") {
          Text("Independent project. Not an official Texas A&M University app.").font(.caption)
          NavigationLink("Open-source licenses") { LicensesView() }
        }
        #if DEBUG
        Section("Design preview") {
          NavigationLink("Sponsored card placement") { AdPlacementPreview() }
        }
        #endif
        Section {
          Button("Delete account", role: .destructive) { AppHaptics.shared.play(.warning); deleting = true }.foregroundStyle(.red).disabled(store.busy)
        } footer: { Text("Deletes the account, revokes its credential, removes private media, and replaces authored content with deleted markers where replies depend on it. If you own an organization, transfer ownership first: an organization left without an owner is suspended.") }
      }.scrollContentBackground(.hidden).appBackground().navigationTitle("Your account").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Close settings") } }
        .confirmationDialog("Delete this account?", isPresented: $deleting, titleVisibility: .visible) {
          Button("Delete account permanently", role: .destructive) { Task {
            if await store.deleteAccount() { AppHaptics.shared.play(.success); dismiss() } else { AppHaptics.shared.play(.error) }
          } }
        } message: { Text("This cannot be undone. Your account will immediately lose access to chats, games, and Tag.") }
    }
  }
  private var accountName: some View { Text("@\(store.state.username)").font(.headline) }
  private var karmaLabel: some View {
    Text("\(store.karma) karma").font(.caption.weight(.semibold)).monospacedDigit()
      .padding(.horizontal, 9).padding(.vertical, 5).foregroundStyle(Palette.onAccent)
      .background(Palette.maroon, in: Capsule()).accessibilityIdentifier("profileKarma")
  }
}
struct AccountProfileView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var username = ""
  @State private var saving = false
  @State private var error: String?
  @FocusState private var focused: Bool
  private var normalized: String { AccountUsernameRules.normalized(username) }
  var body: some View {
    Form {
      Section {
        HStack { Spacer(); Avatar(size: 72); Spacer() }.listRowBackground(Color.clear).padding(.vertical, 12)
      }
      Section {
        TextField("Username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
          .focused($focused).submitLabel(.done).onSubmit { Task { await save() } }.accessibilityIdentifier("profileUsername")
        Button { Task { await save() } } label: {
          HStack { Text("Save username"); Spacer(); if saving { ProgressView() } }
        }.disabled(!AccountUsernameRules.valid(username) || normalized == store.state.username || saving || store.busy)
          .accessibilityIdentifier("saveProfileUsername")
      } header: { Text("Username") } footer: { Text("Use 3–20 letters, numbers, or underscores. Your anonymous posts keep their anonymous identity.") }
      if let error { Section { Text(error).font(.subheadline).foregroundStyle(.red) } }
    }.scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden).appBackground()
      .navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
      .onAppear { if username.isEmpty { username = store.state.username } }
  }
  private func save() async {
    guard !saving, !store.busy, AccountUsernameRules.valid(username), normalized != store.state.username else { return }
    saving = true; error = nil
    defer { saving = false }
    if await store.updateUsername(normalized) { AppHaptics.shared.play(.success); focused = false; dismiss() }
    else { AppHaptics.shared.play(.error); error = store.notice ?? "Your username could not save. Please try again." }
  }
}
struct MyPostsView: View {
  var body: some View { PersonalLibraryView(kind: .posts).appHapticOnOpen() }
}
struct LicensesView: View {
  var body: some View {
    List {
      Section("Game engines") {
        Link("Matter.js · MIT", destination: URL(string: "https://github.com/liabru/matter-js/blob/master/LICENSE")!)
        Link("cannon-es · MIT", destination: URL(string: "https://github.com/pmndrs/cannon-es/blob/master/LICENSE")!)
        Link("Three.js · MIT", destination: URL(string: "https://github.com/mrdoob/three.js/blob/dev/LICENSE")!)
        Link("chess.js · BSD-2-Clause", destination: URL(string: "https://github.com/jhlywa/chess.js/blob/v1.4.0/LICENSE")!)
        Link("Swift beer-pong cup physics · MIT", destination: URL(string: "https://github.com/JBallin/beer-pong/blob/8f1e420ffce5bc396105e49450651e306d4089b9/LICENSE.md")!)
      }
      Section("Campus photograph") {
        Text("Laura McKenzie / Texas A&M University. Uploaded by Kailynn.Nelson on Wikimedia Commons. CC BY-SA 4.0. Cropped for display.").font(.caption)
        Link("Photo and attribution", destination: URL(string: "https://commons.wikimedia.org/wiki/File:Texas_A%26M_Academic_Building.jpg")!)
      }
    }.scrollContentBackground(.hidden).appBackground().navigationTitle("Licenses")
  }
}

struct OrganizationsView: View {
  @Environment(AppStore.self) private var store
  @State private var search = ""
  @State private var application = false
  @State private var invitations: [OrganizationInvitation] = []
  @State private var invitationNotice: String?
  @State private var respondingTo: String?
  private var service: OrganizationAccessService { OrganizationAccessService(social: store.social, fixtureMode: store.fixtureMode) }
  var body: some View {
    ScrollView { LazyVStack(spacing: 10) {
      TextField("Search organizations", text: $search).padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
      if !invitations.isEmpty {
        Text("Administrator invitations").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
        ForEach(invitations) { invitation in
          Card { VStack(alignment: .leading, spacing: 10) {
            Label(invitation.organizationName, systemImage: "person.badge.key").font(.subheadline.bold())
            Text(OrganizationInvitationKind.label(for: invitation.kind) + " · expires " + invitation.expiresAt.formatted(.dateTime.month().day())).font(.caption).foregroundStyle(Palette.secondary)
            Text("Accepting shows your account username, @\(store.state.username), to this organization’s owner. Nobody else sees it.").font(.caption).foregroundStyle(Palette.secondary)
            HStack(spacing: 10) {
              Button("Accept") { Task { await respond(invitation, accept: true) } }.buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent).accessibilityIdentifier("organizationInvitationAccept")
              Button("Decline") { Task { await respond(invitation, accept: false) } }.buttonStyle(.bordered).accessibilityIdentifier("organizationInvitationDecline")
            }.disabled(respondingTo != nil)
          } }
        }
      }
      if let invitationNotice { Text(invitationNotice).font(.caption).foregroundStyle(Palette.secondary).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("organizationInvitationNotice") }
      ForEach(store.organizations.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { organization in
        NavigationLink { OrganizationDetailView(id: organization.id) } label: {
          Card { HStack(spacing: 12) {
            Avatar(symbol: "person.3.fill")
            VStack(alignment: .leading, spacing: 4) {
              Label(organization.name, systemImage: organization.status == "verified" ? "checkmark.seal.fill" : "clock")
                .font(.subheadline.bold())
              Text(organization.status == "verified" ? organization.about : "Application under review").font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(); Image(systemName: "chevron.right").font(.caption)
          } }
        }.buttonStyle(.plain)
      }
      if store.organizations.isEmpty { EmptyCard(icon: "person.3", title: "No verified organizations yet", detail: "Apply to publish events under your organization’s name.") }
      Button("Register an organization") { application = true }.buttonStyle(.bordered)
    }.padding(16) }.maroonRefreshable { await store.refreshAndWait(); await loadInvitations() }.task { await loadInvitations() }
      .appBackground().navigationTitle("Organizations").navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $application) { OrganizationApplicationView() }
  }
  @MainActor private func loadInvitations() async {
    do { invitations = try await service.incoming() } catch { if !(error is CancellationError) { invitationNotice = error.localizedDescription } }
  }
  /// Accepting is the only moment the account username reaches an organization owner, so the snapshot is refreshed afterwards.
  @MainActor private func respond(_ invitation: OrganizationInvitation, accept: Bool) async {
    guard respondingTo == nil else { return }
    respondingTo = invitation.id; defer { respondingTo = nil }
    do {
      if accept { try await service.accept(invitation: invitation.id) } else { try await service.decline(invitation: invitation.id) }
      invitations.removeAll { $0.id == invitation.id }
      invitationNotice = accept ? (invitation.kind == "ownership" ? "You now own \(invitation.organizationName)." : "You now administer \(invitation.organizationName).") : "Invitation from \(invitation.organizationName) declined."
      AppHaptics.shared.play(.success)
      if accept { await store.refreshAndWait() }
    } catch { invitationNotice = error.localizedDescription; AppHaptics.shared.play(.error) }
    await loadInvitations()
  }
}
struct OrganizationApplicationView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var about = ""
  @State private var contact = ""
  @State private var evidence = ""
  var body: some View {
    NavigationStack { Form {
      Section("Public profile") { TextField("Organization name", text: $name); TextField("About the organization", text: $about, axis: .vertical).lineLimit(3...6) }
      Section {
        TextField("Contact email", text: $contact).textInputAutocapitalization(.never).keyboardType(.emailAddress)
        TextField("Official organization page or evidence", text: $evidence, axis: .vertical).lineLimit(2...5).textInputAutocapitalization(.never)
      } header: { Text("Private verification application") } footer: { Text("Only reviewers see your application and administrator account. Publishing is disabled until the organization is approved.") }
    }.scrollContentBackground(.hidden).appBackground().navigationTitle("Organization application").navigationBarTitleDisplayMode(.inline).toolbar {
      ToolbarItem(placement: .cancellationAction) { DraftCancelButton(hasChanges: !name.isEmpty || !about.isEmpty || !contact.isEmpty || !evidence.isEmpty) }
      ToolbarItem(placement: .confirmationAction) { Button("Submit") { Task {
        if await store.mutate("organization.apply", ["name": name, "about": about, "contact": contact, "evidence": evidence]) { dismiss() }
      } }.disabled(name.count < 3 || contact.isEmpty || evidence.isEmpty || about.count > 2000 || store.busy) }
    } }
  }
}
struct OrganizationDetailView: View {
  @Environment(AppStore.self) private var store
  let id: String
  @State private var publish = false
  @State private var editing = false
  @State private var messaging = false
  @State private var destination: String?
  private var organization: SocialOrganization? { store.organizations.first { $0.id == id } }
  var body: some View {
    ScrollView { VStack(alignment: .leading, spacing: 16) {
      if let organization {
        Card { VStack(alignment: .leading, spacing: 12) {
          Label(organization.name, systemImage: organization.status == "verified" ? "checkmark.seal.fill" : "clock").font(.title3.bold())
          Text(organization.about).font(.subheadline)
          if organization.status == "verified" {
            Button(organization.followed ? "Following" : "Follow") { Task { _ = await store.mutate("organization.follow", ["organization_id": id, "followed": !organization.followed]) } }.buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent)
          Button("Message organization", systemImage: "envelope") { messaging = true }.buttonStyle(.bordered)
          } else { Text("Verification pending. Promotions cannot be published yet.").font(.caption).foregroundStyle(.secondary) }
        } }
        if organization.canManage {
          Card { VStack(alignment: .leading, spacing: 12) {
            Text("Private administrator tools").font(.headline)
            Button("Edit organization profile") { editing = true }.buttonStyle(.bordered)
            NavigationLink { OrganizationAdministratorsView(organizationID: id).appHapticOnOpen() } label: { Label("Administrators", systemImage: "person.badge.key") }
              .buttonStyle(.bordered).accessibilityIdentifier("organizationAdministrators")
            Button("Create event or promotion") { publish = true }.buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent).disabled(organization.status != "verified")
          } }
        }
        Text("Events").font(.headline)
        ForEach(store.state.activities.filter { $0.kind == .organization && $0.host == organization.name }) { activity in
          NavigationLink { ActivityDetailView(id: activity.id) } label: { ActivityCard(activity: activity) }.buttonStyle(.plain)
        }
      }
    }.padding(16) }.appBackground().navigationTitle("Organization").navigationBarTitleDisplayMode(.inline)
      .navigationDestination(item: $destination) { ChatView(id: $0) }
      .sheet(isPresented: $messaging) { NewMessageView(organizationID: id) { destination = $0 } }
      .sheet(isPresented: $publish) { OrganizationPromotionView(organizationID: id) }
      .sheet(isPresented: $editing) { if let organization { EditOrganizationView(organization: organization) } }
  }
}
struct EditOrganizationView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let organization: SocialOrganization
  @State private var about = ""
  var body: some View {
    NavigationStack { Form { TextEditor(text: $about).frame(minHeight: 180) }
      .scrollContentBackground(.hidden).appBackground().navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
      .onAppear { about = organization.about }.toolbar {
        ToolbarItem(placement: .cancellationAction) { DraftCancelButton(hasChanges: about != organization.about) }
        ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { if await store.mutate("organization.update", ["organization_id": organization.id, "about": about]) { dismiss() } } }.disabled(about.count > 2000 || store.busy) }
      }
    }
  }
}
