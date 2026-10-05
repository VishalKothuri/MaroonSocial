import SwiftUI

struct CommunitiesView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  @State private var service: CommunitiesService
  @State private var search = ""
  @State private var category = "All"
  @State private var joinedOnly = false
  @State private var creating = false
  @State private var joiningCode = false
  @State private var destination: String?
  @FocusState private var typing: Bool
  init(social: SocialService, fixtureMode: Bool = false) { _service = State(initialValue: CommunitiesService(social: social, fixtureMode: fixtureMode)) }
  private var query: String { "\(search)|\(category)|\(joinedOnly)" }
  var body: some View {
    VStack(spacing: 12) {
      Picker("Communities", selection: $joinedOnly) {
        Text("Discover").tag(false); Text("Joined").tag(true)
      }.pickerStyle(.segmented).accessibilityIdentifier("communityScope").padding(.horizontal, 16)
      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
        TextField("Search communities", text: $search).focused($typing).autocorrectionDisabled()
          .accessibilityIdentifier("communitySearch")
        if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search") }
      }.padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
      HStack {
        Menu { Picker("Category", selection: $category) { ForEach(["All"] + CommunitiesService.categories, id: \.self) { Text($0).tag($0) } } } label: {
          Label(category == "All" ? "All categories" : category, systemImage: "line.3.horizontal.decrease")
        }
        Spacer()
        Button("Enter invite code") { AppHaptics.shared.play(.selection); typing = false; joiningCode = true }.accessibilityIdentifier("communityInviteEntry")
      }.font(.caption.bold()).padding(.horizontal, 16)
      ScrollView {
        LazyVStack(spacing: 0) {
          if let error = service.error {
            VStack(alignment: .leading, spacing: 8) { Text(error).font(.callout); Button("Try again") { Task { await reload() } } }
              .frame(maxWidth: .infinity, alignment: .leading).padding(16)
          }
          if service.loaded && service.communities.isEmpty {
            // Same centered empty state as the rest of the app, with the create action beneath it.
            VStack(spacing: 4) {
              EmptyCard(icon: joinedOnly ? "person.2" : "person.3",
                        title: search.isEmpty ? joinedOnly ? "No joined communities" : "No communities yet" : "No matching communities",
                        detail: joinedOnly ? "Join a community from Discover or use an invite code." : "Start a chat for a campus interest, class or club.")
              Button("Create a community") { AppHaptics.shared.play(.selection); typing = false; creating = true }
                .font(.subheadline.bold()).buttonStyle(.bordered).frame(minHeight: 44).accessibilityIdentifier("createCommunityEmpty")
            }
          }
          ForEach(service.communities) { community in
            Button { AppHaptics.shared.play(.selection); typing = false; destination = community.id } label: {
              HStack(alignment: .top, spacing: 12) {
                GroupPhotoAvatar(roomID: community.id, token: community.avatar ?? "maroon", size: 44, publicPreview: community.isPublic)
                VStack(alignment: .leading, spacing: 4) {
                  Text(community.title).font(.subheadline.bold()).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                  Text("\(community.memberCount) members · \(community.category)").font(.caption).foregroundStyle(.secondary)
                  Text(community.description).font(.caption).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text(community.joined ? "Open" : "Join").font(.caption.bold()).foregroundStyle(Palette.accentText)
                  .padding(.horizontal, 11).frame(minHeight: 36).background(Palette.maroon, in: Capsule())
              }.padding(.vertical, 14).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("communityRow-\(community.id)")
            Divider()
          }
          if service.busy { ProgressView().padding(20) }
          if service.hasMore { Button("Load more") { Task { await service.list(search: search, category: category, joinedOnly: joinedOnly, more: true) } }.padding().disabled(service.busy) }
        }.padding(.horizontal, 16)
      }.scrollDismissesKeyboard(.interactively).maroonRefreshable(scope: "communities") { await reload() }
    }.padding(.top, 10).appBackground().navigationTitle("Communities").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button { AppHaptics.shared.play(.selection); typing = false; creating = true } label: { Image(systemName: "plus") }.accessibilityLabel("Create community").accessibilityIdentifier("communityCreate") }
        ToolbarItem(placement: .topBarTrailing) { if typing { KeyboardDismissButton { typing = false } } }
      }
      .task(id: query) {
        do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
        guard !Task.isCancelled else { return }; await reload()
      }
      .task {
        while !Task.isCancelled {
          do { try await Task.sleep(for: .seconds(15)) } catch { return }
          if scenePhase == .active && !creating && !joiningCode { await reload() }
        }
      }
      .sheet(isPresented: $creating, onDismiss: { Task { await reload() } }) {
        CreateCommunityView(social: store.social, fixtureMode: store.fixtureMode) { destination = $0 }
      }
      .sheet(isPresented: $joiningCode, onDismiss: { Task { await reload() } }) {
        JoinCommunityCodeView(social: store.social, fixtureMode: store.fixtureMode) { destination = $0 }
      }
      .navigationDestination(item: $destination) { CommunityDetailView(id: $0, social: store.social, fixtureMode: store.fixtureMode) }
  }
  private func reload() async { await service.list(search: search, category: category, joinedOnly: joinedOnly) }
}

struct CreateCommunityView: View {
  let social: SocialService
  let fixtureMode: Bool
  let onCreated: (String) -> Void
  var body: some View { GroupSetupView(social: social, fixtureMode: fixtureMode, onCreated: onCreated) }
}

struct JoinCommunityCodeView: View {
  let social: SocialService
  let fixtureMode: Bool
  let onJoined: (String) -> Void
  var body: some View { GroupIdentityView(social: social, fixtureMode: fixtureMode, action: .code, onCompleted: onJoined) }
}

struct CommunityDetailView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  let id: String
  let showsOpenChat: Bool
  @State private var service: CommunitiesService
  @State private var chat: String?
  @State private var joinConfirmation = false
  @State private var pendingAction: String?
  @State private var performingAction = false
  @State private var target: CommunityMember?
  @State private var pendingInvitation: CommunityInvitation?
  @State private var reporting = false
  @State private var editing = false
  @State private var editingIdentity = false
  @State private var editingGroupPhoto = false
  @State private var editingMemberPhoto = false
  @State private var inviting = false
  init(id: String, social: SocialService, fixtureMode: Bool = false, showsOpenChat: Bool = true) {
    self.id = id; self.showsOpenChat = showsOpenChat; _service = State(initialValue: CommunitiesService(social: social, fixtureMode: fixtureMode))
  }
  var body: some View {
    List {
      if let community = service.community {
        Section {
          HStack(spacing: 12) { GroupPhotoAvatar(roomID: community.id, token: community.avatar ?? "maroon", publicPreview: community.isPublic); Text(community.title).font(.title3.bold()) }
          Text("\(community.memberCount)/\(community.capacity) members · \(community.category)").font(.caption).foregroundStyle(.secondary)
          Text(community.description).font(.subheadline)
          Label(community.isPublic ? "Discoverable on campus" : "Invite-only group", systemImage: community.isPublic ? "globe.americas" : "lock").font(.caption).foregroundStyle(.secondary)
          if community.closed { Label("This group is closed", systemImage: "lock.fill").font(.subheadline) }
          if community.joined && showsOpenChat {
            Button(community.closed ? "Read conversation" : "Open chat", systemImage: "bubble.left.and.bubble.right") {
              AppHaptics.shared.play(.selection)
              Task { await store.refresh(); chat = id }
            }.accessibilityIdentifier("communityOpenChat")
          } else if !community.joined {
            Button(community.invited == true ? "Accept invitation" : "Join group") { AppHaptics.shared.play(.selection); joinConfirmation = true }.disabled(service.busy || community.closed || community.memberCount >= community.capacity).accessibilityIdentifier("communityJoin")
            Text("Join to read messages and see members.").font(.caption).foregroundStyle(.secondary)
          }
        }
        if community.owner {
          Section("Owner controls") {
            Button("Change group photo", systemImage: "photo") { editingGroupPhoto = true }.disabled(community.closed)
            Button("Edit group details", systemImage: "pencil") { AppHaptics.shared.play(.selection); editing = true }.disabled(community.closed)
            Button("Invite people", systemImage: "person.badge.plus") { AppHaptics.shared.play(.selection); inviting = true }.disabled(community.closed).accessibilityIdentifier("groupInvitePeople")
            if let code = community.inviteCode, !community.closed {
              HStack { Text("Invite code"); Spacer(); Text(code).font(.system(.body, design: .monospaced)).textSelection(.enabled) }
              ShareLink(item: "Join \(community.title) on Maroon Social. Enter invite code \(code) in Explore → Communities.") { Label("Share invitation", systemImage: "square.and.arrow.up") }
              Button("Replace invite code") { pendingAction = "rotate_code" }.disabled(community.closed)
            }
            if !community.closed { Button("Close group", role: .destructive) { pendingAction = "close" } }
          }
        }
        if community.joined {
          Section("Your group identity") {
            HStack(spacing: 10) { GroupPhotoAvatar(roomID: id, memberKey: "self", token: community.myAvatar ?? "gold", size: 36); Text(community.myAlias ?? "Group member") }
            Button("Change your group photo", systemImage: "photo") { editingMemberPhoto = true }.disabled(community.closed)
            Button("Edit your alias and avatar", systemImage: "person.crop.circle") { AppHaptics.shared.play(.selection); editingIdentity = true }.disabled(community.closed).accessibilityIdentifier("groupEditIdentity")
          }
          Section("Members") {
            ForEach(service.members) { member in
              HStack {
                GroupPhotoAvatar(roomID: id, memberKey: member.memberKey ?? "unavailable", token: member.avatar ?? "maroon", size: 30); Text(member.isMe == true ? "\(member.displayName) · You" : member.displayName).font(.subheadline)
                Spacer()
                if member.role == "owner" { Text("Owner").font(.caption).foregroundStyle(.secondary) }
                if community.owner && member.isMe != true && member.memberKey != nil && !community.closed {
                  Menu {
                    Button("Remove member") { target = member; pendingAction = "remove" }
                    Button("Ban from group", role: .destructive) { target = member; pendingAction = "ban" }
                    Button("Transfer ownership") { target = member; pendingAction = "transfer" }
                  } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Manage \(member.displayName)")
                }
              }
            }
          }
          if community.owner && !service.pending.isEmpty {
            Section("Pending invitations") {
              ForEach(service.pending) { member in
                HStack {
                  VStack(alignment: .leading, spacing: 3) { Text("@" + member.username); Text("Waiting for acceptance").font(.caption).foregroundStyle(Palette.secondary) }
                  Spacer()
                  Button("Revoke", role: .destructive) { target = nil; pendingInvitation = member; pendingAction = "revoke" }.disabled(service.busy)
                }
              }
            }
          }
          if community.owner && !service.bans.isEmpty {
            Section("Banned members") {
              ForEach(service.bans) { member in HStack { Text(member.displayName); Spacer(); Button("Unban") { target = member; pendingAction = "unban" }.font(.caption) } }
            }
          }
          Section { Button("Leave group", role: .destructive) { pendingAction = "leave" }.accessibilityIdentifier("communityLeave") }
        }
        Section { Button("Report group", systemImage: "flag", role: .destructive) { AppHaptics.shared.play(.selection); reporting = true } }
      } else if service.busy { ProgressView() }
      else if service.error == nil { Text("This group is unavailable.").foregroundStyle(.secondary) }
      if let error = service.error { Section { Text(error).font(.callout); Button("Try again") { Task { await reload() } } } }
    }.scrollContentBackground(.hidden).appBackground().navigationTitle(showsOpenChat ? "Group" : "Group settings").navigationBarTitleDisplayMode(.inline)
      .task {
        await reload()
        while !Task.isCancelled {
          do { try await Task.sleep(for: .seconds(8)) } catch { return }
          if scenePhase == .active && !reporting && !editing && !editingIdentity && !editingGroupPhoto && !editingMemberPhoto && !inviting && !joinConfirmation && pendingAction == nil && !performingAction { await reload() }
        }
      }.maroonRefreshable(scope: "communities") { await reload() }
      .sheet(isPresented: $editingGroupPhoto) { GroupPhotoEditor(roomID: id) }
      .sheet(isPresented: $editingMemberPhoto) { GroupPhotoEditor(roomID: id, memberKey: "self") }
      .sheet(isPresented: $joinConfirmation, onDismiss: { Task { await reload() } }) {
        GroupIdentityView(social: store.social, fixtureMode: store.fixtureMode, action: service.community?.invited == true ? .accept(id) : .join(id), groupName: service.community?.title ?? "") { _ in }
      }
      .confirmationDialog(actionTitle, isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil; target = nil; pendingInvitation = nil } }), titleVisibility: .visible) {
        Button(actionTitle, role: ["leave", "close", "ban", "remove", "revoke"].contains(pendingAction ?? "") ? .destructive : nil) {
          guard !service.busy, !performingAction, let action = pendingAction else { return }
          let memberKey = target?.memberKey; let invitationKey = pendingInvitation?.invitationKey
          // Hold off refreshes before scheduling the mutation task, including
          // the interval after the confirmation dialog dismisses.
          performingAction = true
          Task {
            defer { performingAction = false }
            var payload: [String: Any] = ["room_id": id]; if let memberKey { payload["member_key"] = memberKey }; if let invitationKey { payload["invitation_key"] = invitationKey }
            if await service.act(action, payload) != nil { AppHaptics.shared.play(.success); await store.refreshAfterMutation(); if action == "leave" { dismiss() } } else { AppHaptics.shared.play(.error) }
          }
          pendingAction = nil; target = nil; pendingInvitation = nil
        }.disabled(service.busy || performingAction)
      } message: { Text(actionExplanation) }
      .sheet(isPresented: $reporting) { CommunityReportView(service: service, roomID: id) }
      .sheet(isPresented: $editing) { if let community = service.community { CommunityEditView(service: service, community: community) } }
      .sheet(isPresented: $inviting, onDismiss: { Task { await reload() } }) { GroupInviteView(social: store.social, fixtureMode: store.fixtureMode, roomID: id) }
      .sheet(isPresented: $editingIdentity, onDismiss: { Task { await reload() } }) {
        GroupIdentityView(social: store.social, fixtureMode: store.fixtureMode, action: .profile(id), groupName: service.community?.title ?? "", initialAlias: service.community?.myAlias ?? "", initialAvatar: service.community?.myAvatar ?? "gold") { _ in }
      }
      .navigationDestination(item: $chat) { ChatView(id: $0) }
  }
  private func reload() async {
    guard pendingAction == nil, !performingAction else { return }
    await service.act("detail", ["room_id": id])
  }
  private var actionTitle: String {
    switch pendingAction {
    case "revoke": return "Revoke invitation to @\(pendingInvitation?.username ?? "member")"
    case "close": return "Close group"
    case "leave": return "Leave group"
    case "remove": return "Remove \(target?.displayName ?? "member")"
    case "ban": return "Ban \(target?.displayName ?? "member")"
    case "unban": return "Unban \(target?.displayName ?? "member")"
    case "transfer": return "Transfer ownership to \(target?.displayName ?? "member")"
    case "rotate_code": return "Replace invite code"
    default: return "Confirm"
    }
  }
  private var actionExplanation: String {
    switch pendingAction {
    case "revoke": return "This invitation will be removed from their Requests."
    case "close": return "The group will leave discovery and stop accepting messages or new members. Members can still read its history."
    case "leave": return "You’ll stop receiving messages. Owners must transfer ownership or close an active group before leaving."
    case "ban": return "This member will lose access and cannot rejoin, including with an invite code, until you unban them."
    case "remove": return "The member loses access. They may rejoin; use Ban to prevent that."
    case "transfer": return "The new owner will manage members, invitations and the group. You’ll remain a member."
    case "rotate_code": return "The previous invitation code will stop working. Existing members keep access."
    default: return "They can request to join this group again."
    }
  }
}

private struct CommunityReportView: View {
  @Environment(\.dismiss) private var dismiss
  let service: CommunitiesService
  let roomID: String
  @State private var reason = ""
  var body: some View {
    NavigationStack { Form {
      Section("Tell the app owner what happened") {
        TextField("Reason for reporting", text: $reason, axis: .vertical).lineLimit(3...6).accessibilityIdentifier("communityReportReason")
        Button("Send report") { Task { if await service.act("report", ["room_id": roomID, "reason": reason]) != nil { AppHaptics.shared.play(.success); dismiss() } else { AppHaptics.shared.play(.error) } } }.disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || reason.count > 500 || service.busy)
        if let error = service.error { Text(error).font(.callout) }
      }
    }.scrollContentBackground(.hidden).appBackground().navigationTitle("Report group").navigationBarTitleDisplayMode(.inline).toolbar { Button("Cancel") { dismiss() } } }
  }
}
private struct CommunityEditView: View {
  @Environment(\.dismiss) private var dismiss
  let service: CommunitiesService
  let community: CampusCommunity
  @State private var title: String
  @State private var description: String
  @State private var category: String
  @State private var avatar: String
  @State private var isPublic: Bool
  init(service: CommunitiesService, community: CampusCommunity) { self.service = service; self.community = community; _title = State(initialValue: community.title); _description = State(initialValue: community.description); _category = State(initialValue: community.category); _avatar = State(initialValue: community.avatar ?? "maroon"); _isPublic = State(initialValue: community.isPublic) }
  var body: some View {
    NavigationStack { Form {
      Section {
        TextField("Name", text: $title)
        TextField("Description", text: $description, axis: .vertical).lineLimit(3...6)
        Picker("Category", selection: $category) { ForEach(CommunitiesService.categories, id: \.self) { Text($0).tag($0) } }
        Picker("Visibility", selection: $isPublic) { Text("Public in Explore").tag(true); Text("Invite only").tag(false) }
        GroupAvatarPicker(selection: $avatar, label: "Group avatar")
        Button("Save changes") { Task { if await service.act("update", ["room_id": community.id, "title": title, "description": description, "category": category, "avatar": avatar, "is_public": isPublic]) != nil { AppHaptics.shared.play(.success); dismiss() } else { AppHaptics.shared.play(.error) } } }
          .disabled(service.busy || !(3...60).contains(title.trimmingCharacters(in: .whitespacesAndNewlines).count) || !(10...500).contains(description.trimmingCharacters(in: .whitespacesAndNewlines).count))
        if let error = service.error { Text(error).font(.callout) }
      }
    }.scrollContentBackground(.hidden).appBackground().navigationTitle("Edit group").navigationBarTitleDisplayMode(.inline).toolbar { Button("Cancel") { dismiss() } } }
  }
}
