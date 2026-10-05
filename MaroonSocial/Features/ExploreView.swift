import MaroonCore
import SwiftUI

struct ExploreView: View {
  @Environment(AppStore.self) private var store
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack(spacing: 12) {
          NavigationLink { RandomChatView().appHapticOnOpen().toolbar(.visible, for: .navigationBar) } label: {
            featureTile("Meet people", detail: "Interests · Text & video", icon: "person.2")
          }
          NavigationLink { TagView().appHapticOnOpen().toolbar(.visible, for: .navigationBar) } label: {
            featureTile("Campus Tag", detail: "Create or join a lobby", icon: "location.north.circle")
          }
        }.buttonStyle(.plain)
        NavigationLink { CommunitiesView(social: store.social, fixtureMode: store.fixtureMode).appHapticOnOpen().toolbar(.visible, for: .navigationBar) } label: {
          HStack(spacing: 12) {
            Image(systemName: "person.3.fill").foregroundStyle(Palette.accentText)
            VStack(alignment: .leading, spacing: 3) { Text("Communities").font(.subheadline.bold()); Text("Find a campus chat or create your own").font(.caption).foregroundStyle(.secondary) }
            Spacer(); Image(systemName: "chevron.right").font(.caption)
          }.padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain).accessibilityIdentifier("exploreCommunities")
        Text("Find your people").font(.headline)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
          ForEach(ActivityKind.allCases) { kind in
            NavigationLink {
              if kind == .organization { OrganizationsView().appHapticOnOpen().toolbar(.visible, for: .navigationBar) } else { ActivityListView(filter: kind).appHapticOnOpen().toolbar(.visible, for: .navigationBar) }
            } label: {
              HStack { Image(systemName: kind.icon).foregroundStyle(Palette.accentText); Text(kind.rawValue).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.8); Spacer(); Image(systemName: "chevron.right").font(.caption2) }
                .padding(15).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
          }
        }
        HStack { Text("Games").font(.headline); Spacer(); NavigationLink("Online matches") { OnlineGamesListView().appHapticOnOpen().toolbar(.visible, for: .navigationBar) }.font(.subheadline) }
        ForEach(["8 Ball", "Chess", "Cup Pong"], id: \.self) { game in
          NavigationLink { GameLobbyView(kind: game).appHapticOnOpen().toolbar(.visible, for: .navigationBar) } label: {
            HStack(spacing: 12) {
              Avatar(symbol: game == "Chess" ? "crown.fill" : game == "8 Ball" ? "8.circle.fill" : "cup.and.saucer.fill")
              VStack(alignment: .leading, spacing: 3) { Text(game).font(.subheadline.bold()); Text("Find a player · Take turns online").font(.caption).foregroundStyle(.secondary) }
              Spacer(); Image(systemName: "chevron.right").font(.caption)
            }.padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
          }.buttonStyle(.plain)
        }
        // Only plans that are still ahead earn the heading; past or cancelled ones leave it out.
        let upcoming = store.state.activities.filter { !$0.cancelled && $0.starts > .now }.sorted { $0.starts < $1.starts }.prefix(4)
        if !upcoming.isEmpty {
          Text("Upcoming plans").font(.headline)
          ForEach(upcoming) { activity in
            NavigationLink { ActivityDetailView(id: activity.id).appHapticOnOpen().toolbar(.visible, for: .navigationBar) } label: { ActivityCard(activity: activity) }.buttonStyle(.plain)
          }
        }
      }.padding(16)
    }.maroonRefreshable { await store.refreshAndWait() }.appBackground().toolbar(.hidden, for: .navigationBar)
  }
  private func featureTile(_ title: String, detail: String, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: icon).font(.title2).foregroundStyle(Palette.lime)
      Text(title).font(.subheadline.bold()).foregroundStyle(.white)
      Text(detail).font(.caption2).foregroundStyle(.white.opacity(0.75))
    }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Palette.hero, in: RoundedRectangle(cornerRadius: 16))
  }
}

struct ActivityListView: View {
  @Environment(AppStore.self) private var store
  let filter: ActivityKind
  @State private var create = false
  @State private var search = ""
  @State private var joinedOnly = false
  private var activities: [Activity] {
    store.state.activities.filter { $0.kind == filter && !$0.cancelled && $0.starts > .now.addingTimeInterval(-3600)
      && (!joinedOnly || $0.participants.contains(store.state.username) || $0.waitlisted == true)
      && (search.isEmpty || "\($0.title) \($0.place) \($0.course ?? "") \($0.details)".localizedCaseInsensitiveContains(search)) }
      .sorted { $0.starts < $1.starts }
  }
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
        TextField(filter == .study ? "Search course, topic or place" : "Search plans or places", text: $search).autocorrectionDisabled()
        Button { joinedOnly.toggle(); AppHaptics.shared.play(.selection) } label: { Image(systemName: joinedOnly ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle") }.accessibilityLabel("My plans")
      }.padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12)).padding(16)
      ScrollView {
        LazyVStack(spacing: 10) {
          ForEach(activities) { activity in NavigationLink { ActivityDetailView(id: activity.id).appHapticOnOpen() } label: { ActivityCard(activity: activity) }.buttonStyle(.plain) }
          if activities.isEmpty {
            EmptyCard(icon: filter.icon, title: "No plans yet", detail: "Create a plan or try another search.")
            Button("Create a plan") { AppHaptics.shared.play(.selection); create = true }.buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent)
          }
        }.padding(.horizontal, 16).padding(.bottom, 18)
      }.maroonRefreshable { await store.refreshAndWait() }
    }.appBackground().navigationTitle(filter.rawValue).navigationBarTitleDisplayMode(.inline)
      .toolbar { Button("Create", systemImage: "plus") { AppHaptics.shared.play(.selection); create = true } }
      .sheet(isPresented: $create) { CreateActivityView(kind: filter) }
  }
}
struct ActivityCard: View {
  let activity: Activity
  var body: some View {
    Card {
      HStack(alignment: .top, spacing: 12) {
        VStack(spacing: 2) {
          Text(activity.starts, format: .dateTime.month(.abbreviated)).font(.caption2.bold()).textCase(.uppercase)
          Text(activity.starts, format: .dateTime.day()).font(.title3.bold())
        }.frame(width: 42).padding(.vertical, 9).foregroundStyle(Palette.accentText).background(Palette.maroon.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        VStack(alignment: .leading, spacing: 6) {
          Text(activity.title).font(.subheadline.bold()).lineLimit(2)
          Label(activity.place, systemImage: "mappin.and.ellipse").font(.caption).lineLimit(1)
          HStack {
            Text(activity.starts, format: .dateTime.weekday(.abbreviated).hour().minute())
            Spacer()
            Text("\(activity.participantCount ?? activity.participants.count)/\(activity.capacity) going")
          }.font(.caption2).foregroundStyle(.secondary)
        }
      }
    }
  }
}
struct ActivityDetailView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let id: String
  @State private var confirmLeave = false
  @State private var edit = false
  @State private var dm = false
  @State private var destination: String?
  private var activity: Activity? { store.state.activities.first { $0.id == id } }
  private var isHost: Bool { store.conversationMeta[id]?.role == "owner" || activity?.host == store.state.username }
  private var joined: Bool { activity?.membershipStatus == "accepted" || activity?.participants.contains(store.state.username) == true }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        if let activity {
          Card { VStack(alignment: .leading, spacing: 14) {
            Label(activity.kind.rawValue, systemImage: activity.kind.icon).font(.caption.bold()).foregroundStyle(Palette.accentText)
            Text(activity.title).font(.title2.bold())
            Label(activity.starts.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar").font(.subheadline)
            Label(activity.place, systemImage: "mappin.and.ellipse").font(.subheadline)
            if let course = activity.course { Label(course, systemImage: "book.closed").font(.subheadline) }
            Text("Hosted by @\(activity.host)").font(.caption).foregroundStyle(.secondary)
          } }
          if activity.kind == .study { StudySeriesView(activityID: activity.id) }
          if activity.kind == .organization && !activity.cancelled { OrganizationPosterView(activityID: activity.id) }
          if !activity.details.isEmpty { Card { VStack(alignment: .leading, spacing: 8) { Text("About this plan").font(.headline); Text(activity.details).font(.subheadline).textSelection(.enabled) } } }
          Card { VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Who’s going").font(.headline); Spacer(); Text("\(activity.participantCount ?? activity.participants.count)/\(activity.capacity)").font(.subheadline).foregroundStyle(.secondary) }
            if activity.participants.isEmpty { Text("Join to see the participants.").font(.caption).foregroundStyle(.secondary) }
            ForEach(activity.participants, id: \.self) { name in HStack { Avatar(size: 28); Text("@\(name)").font(.subheadline); Spacer(); if name == activity.host { Text("Host").font(.caption).foregroundStyle(.secondary) } } }
          } }
          if isHost, let requests = activity.joinRequests, !requests.isEmpty {
            Card { VStack(alignment: .leading, spacing: 12) {
              Text("Join requests").font(.headline)
              ForEach(requests, id: \.self) { name in
                HStack { Text("@\(name)"); Spacer(); Button("Approve") { Task { _ = await store.mutate("activity.approve", ["activity_id": id, "username": name]) } }.buttonStyle(.bordered) }
              }
            } }
          }
          if activity.cancelled {
            Label("This activity was cancelled", systemImage: "calendar.badge.minus").font(.headline).foregroundStyle(.secondary)
          } else if joined {
            NavigationLink { ChatView(id: activity.id).appHapticOnOpen() } label: { Label("Open group chat", systemImage: "bubble.left.and.bubble.right") }.buttonStyle(PrimaryButton())
            if isHost { Button("Edit plan") { AppHaptics.shared.play(.selection); edit = true }.buttonStyle(.bordered).frame(maxWidth: .infinity) }
            Button(isHost ? "Cancel activity" : "Leave activity", role: .destructive) { AppHaptics.shared.play(.warning); confirmLeave = true }
              .buttonStyle(.bordered).frame(maxWidth: .infinity).padding(.top, 4)
          } else if activity.waitlisted == true || activity.membershipStatus == "pending" {
            Card { Label(activity.membershipStatus == "pending" ? "Waiting for host approval" : "You’re on the waitlist", systemImage: "clock").font(.subheadline.bold()) }
            Button("Cancel request", role: .destructive) { Task { _ = await store.mutate("activity.leave", ["activity_id": id]) } }.buttonStyle(.bordered)
          } else {
            Button(activity.approvalRequired == true ? "Request to join" : (activity.participantCount ?? activity.participants.count) >= activity.capacity ? "Join waitlist" : "Join plan") { AppHaptics.shared.play(.impact); store.joinActivity(id) }
              .buttonStyle(PrimaryButton()).disabled(store.busy).accessibilityIdentifier("joinActivity")
          }
          if !isHost { Button("Message host", systemImage: "envelope") { AppHaptics.shared.play(.selection); dm = true }.buttonStyle(.bordered) }
          Label("Meet in a public place. Share only what you choose.", systemImage: "hand.raised").font(.caption).foregroundStyle(.secondary)
        } else { EmptyCard(icon: "calendar.badge.exclamationmark", title: "Plan unavailable", detail: "It may have been cancelled or removed.") }
      }.padding(16)
    }.maroonRefreshable { await store.refreshAndWait() }.appBackground().navigationTitle("Plan details").navigationBarTitleDisplayMode(.inline).hidesTabBarWhenPushed()
      .toolbar { Button("Report", systemImage: "flag") { Task { _ = await store.mutate("report", ["target_type": "activity", "target_id": id, "reason": "Activity report"]) } } }
      .confirmationDialog(isHost ? "Cancel this activity?" : "Leave this activity?", isPresented: $confirmLeave, titleVisibility: .visible) {
        Button(isHost ? "Cancel activity" : "Leave activity", role: .destructive) {
          Task { if await store.mutate(isHost ? "activity.cancel" : "activity.leave", ["activity_id": id]) { dismiss() } }
        }
      } message: { Text("Membership and the shared chat will update for everyone.") }
      .sheet(isPresented: $edit) { if let activity { CreateActivityView(kind: activity.kind, editing: activity) } }
      .sheet(isPresented: $dm) { NewMessageView(organizationID: activity?.kind == .organization ? store.organizations.first(where: { $0.name == activity?.host })?.id : nil, initialUsername: activity?.host ?? "") { destination = $0 } }
      .navigationDestination(item: $destination) { ChatView(id: $0) }
  }
}
struct CreateActivityView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let kind: ActivityKind
  var initialCourse = ""
  var editing: Activity? = nil
  var organizationID: String? = nil
  @State private var title = ""
  @State private var place = ""
  @State private var details = ""
  @State private var starts = Date.now.addingTimeInterval(3600)
  @State private var capacity = 6
  @State private var course = ""
  @State private var approval = false
  @State private var weeks = 1
  @State private var nonce = UUID().uuidString
  @State private var saving = false
  @State private var draftOwner = ""
  @State private var closing = false
  @FocusState private var focused: String?
  private var draftKey: String { "activity:" + (editing?.id ?? organizationID ?? kind.rawValue) + ":" + initialCourse }
  private var savedDraft: Binding<CompositionDraft> {
    Binding(get: { CompositionDraft(text: details, fields: ["title":title,"place":place,"starts":String(starts.timeIntervalSince1970),"capacity":String(capacity),"course":course,"approval":String(approval),"weeks":String(weeks)], nonce:nonce, hasContent:!title.isEmpty || !place.isEmpty || !details.isEmpty) }, set: { draft in
      title=draft.fields["title"] ?? "";place=draft.fields["place"] ?? "";details=draft.text;nonce=draft.nonce
      starts=Date(timeIntervalSince1970:Double(draft.fields["starts"] ?? "") ?? Date.now.addingTimeInterval(3600).timeIntervalSince1970)
      capacity=Int(draft.fields["capacity"] ?? "") ?? 6;course=draft.fields["course"] ?? initialCourse;approval=draft.fields["approval"] == "true";weeks=Int(draft.fields["weeks"] ?? "") ?? 1
    })
  }
  var body: some View {
    NavigationStack { Form {
      Section("Plan") {
        TextField("Title", text: $title).focused($focused, equals: "title").accessibilityIdentifier("activityTitle")
        TextField("Public meeting place or online venue", text: $place).focused($focused, equals: "place").accessibilityIdentifier("activityPlace")
        DatePicker("When", selection: $starts, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
        Stepper("\(capacity) spots", value: $capacity, in: 2...100)
        Toggle("Approve join requests", isOn: $approval)
      }
      if kind == .study { Section("Course") { TextField("Course code (optional)", text: $course).textInputAutocapitalization(.characters).autocorrectionDisabled() } }
      if kind == .study && editing == nil { Section("Repeat") {
        Picker("Meetings",selection:$weeks){Text("Just once").tag(1);ForEach(2...8,id:\.self){Text("Every week · \($0) meetings").tag($0)}}.accessibilityIdentifier("studyRepeat")
        if weeks > 1 { Text("Same local time each week in College Station. People join each meeting separately.").font(.caption).foregroundStyle(Palette.secondary)
          ForEach(ActivityPlansService.weeklyDates(start:starts,weeks:weeks),id:\.self){Text($0,format:.dateTime.month(.abbreviated).day().hour().minute()).font(.caption)} }
      } }
      Section("Details") {
        TextEditor(text: $details).frame(minHeight: 100).focused($focused, equals: "details").accessibilityIdentifier("activityDetails")
        Text(kind == .gaming ? "Include the game, platform, skill level, and any equipment to bring." : kind == .study ? "Include the topic, meeting mode, and what to prepare." : "What should people know or bring?").font(.caption).foregroundStyle(.secondary)
      }
    }.scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden).appBackground().interactiveDismissDisabled(!title.isEmpty || !place.isEmpty || !details.isEmpty).navigationTitle(editing == nil ? "New plan" : "Edit plan").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if !title.isEmpty || !place.isEmpty || !details.isEmpty { closing = true } else { dismiss() } }.disabled(saving) }
        ToolbarItem(placement: .confirmationAction) { Button(saving ? "Saving…" : editing == nil ? "Create" : "Save") { save() }
          .disabled(saving || title.trimmingCharacters(in: .whitespaces).isEmpty || place.trimmingCharacters(in: .whitespaces).isEmpty || title.count > 100 || place.count > 200 || details.count > 2000 || starts <= .now).accessibilityIdentifier("publishActivity") }
        ToolbarItem(placement: .topBarTrailing) { if focused != nil { KeyboardDismissButton { focused = nil } } }
      }.onAppear {
        if draftOwner.isEmpty { draftOwner = store.compositions.owner }
        guard store.compositions.draft(draftKey) == nil else { return }
        course = initialCourse
        if let editing { title = editing.title; place = editing.place; starts = editing.starts; capacity = editing.capacity; details = editing.details; course = editing.course ?? ""; approval = editing.approvalRequired ?? false }
      }.persistentDraft(draftKey,value:savedDraft)
        .alert("Keep this plan draft?",isPresented:$closing){
          Button("Save and close"){Task{if await store.compositions.saveDraft(savedDraft.wrappedValue,key:draftKey,owner:draftOwner){dismiss()}}}
          Button("Discard draft",role:.destructive){Task{title="";place="";details="";await store.compositions.removeDraft(draftKey,owner:draftOwner);dismiss()}}
          Button("Keep editing",role:.cancel){}
        }message:{Text("Saved drafts stay on this device.")}
    }
  }
  private func save() {
    guard draftOwner == store.compositions.owner else { return }
    saving = true
    Task {
      guard await store.compositions.saveDraft(savedDraft.wrappedValue,key:draftKey,owner:draftOwner), draftOwner == store.compositions.owner else { saving=false;return }
      let success: Bool
      let value = Activity(title: title, kind: kind, host: store.state.username, place: place, starts: starts, capacity: capacity, details: details, course: course.isEmpty ? nil : course)
      if let editing {
        success = await store.mutate("activity.edit", ["activity_id": editing.id, "title": title, "place": place, "starts": starts.timeIntervalSince1970, "details": details, "capacity": capacity, "approval_required": approval])
      } else if let organizationID {
        success = await store.mutate("organization.publish", ["organization_id": organizationID, "kind": ActivityKind.organization.rawValue, "title": title, "place": place, "starts": starts.timeIntervalSince1970, "capacity": capacity, "details": details])
      } else if kind == .study && weeks > 1 {
        do { _ = try await ActivityPlansService(social:store.social,fixtureMode:store.fixtureMode).createSeries(["nonce":nonce,"title":title,"place":place,"starts":starts.timeIntervalSince1970,"capacity":capacity,"course":course,"details":details,"approval_required":approval,"weeks":weeks]); await store.refreshAndWait(); success=true }
        catch { if draftOwner == store.compositions.owner { store.notice=error.localizedDescription };success=false }
      } else { success = await store.createActivity(value, extra: ["approval_required": approval,"nonce":nonce]) }
      guard draftOwner == store.compositions.owner else { return }
      AppHaptics.shared.play(success ? .success : .error)
      if success { title="";place="";details=""; await store.compositions.removeDraft(draftKey,owner:draftOwner); dismiss() }; saving = false
    }
  }
}
