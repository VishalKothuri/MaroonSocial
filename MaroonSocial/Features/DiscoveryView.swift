import SwiftUI

struct DiscoveryView: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var service: DiscoveryService
  @State private var username = ""
  @State private var tags: [String] = []
  @State private var customTag = ""
  @State private var profileLoaded = false
  @State private var allowDirect = false
  @State private var selectedPerson: DiscoveryPerson?
  @State private var incoming: DiscoveryIncoming?
  @State private var showBrowser = false
  @State private var draft = ""
  @State private var status = "Connecting…"
  @State private var showReport = false
  init(social: SocialService) { _service = State(initialValue: DiscoveryService(social: social)) }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        if service.state == "connected", let session = service.session { connected(session) }
        else if service.state == "connecting" { connecting }
        else if service.state == "waiting" { waiting }
        else { setup }
        if let notice = service.notice { Text(notice).font(.callout).foregroundStyle(Palette.secondary) }
        if let error = service.error { Text(error).font(.callout).foregroundStyle(Palette.accentText).accessibilityIdentifier("discoveryError") }
      }.padding(20)
    }.scrollDismissesKeyboard(.interactively).appBackground().navigationTitle("Meet people").navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .tabBar)
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Menu {
        Button("Use in browser", systemImage: "safari") { incoming = nil; selectedPerson = nil; service.deactivate(); showBrowser = true }
        if service.session != nil { Button("Block this account", systemImage: "hand.raised", role: .destructive) { Task { await service.moderate(reason: nil) } }; Button("Report", systemImage: "flag", role: .destructive) { showReport = true } }
      } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("Discovery options") } } }
      .task { await service.activate(); fillProfile() }
      .onDisappear { service.deactivate() }
      .onChange(of: scenePhase) { _, phase in if phase == .background { incoming = nil; selectedPerson = nil; service.deactivate() } else if phase == .active, !showBrowser { Task { await service.activate() } } }
      .onChange(of: service.profile) { _, _ in fillProfile() }
      .onChange(of: service.session?.id) { _, _ in draft = ""; status = "Connecting…" }
      .onChange(of: service.incoming) { _, requests in
        if let shown = incoming { if !requests.contains(where: { $0.id == shown.id }) { incoming = nil } }
        else { incoming = requests.first }
      }
      .alert("\(incoming?.from.username ?? "Someone") wants to connect", isPresented: Binding(get: { incoming != nil }, set: { if !$0 { incoming = nil } }), presenting: incoming) { request in
        Button("Accept video & text") { Task { await service.accept(request) } }
        Button("Decline", role: .cancel) { Task { await service.decline(request) } }
      } message: { _ in Text("Both of you must remain here. Camera, microphone and text become available only after you accept and both devices confirm.") }
      .sheet(item: $selectedPerson) { person in profile(person) }
      .sheet(isPresented: $showBrowser, onDismiss: { if scenePhase == .active { Task { await service.activate() } } }) { RandomBrowserPairView() }
      .confirmationDialog("Report this conversation", isPresented: $showReport) { ForEach(["Harassment", "Sexual content", "Hate or threats", "Spam", "Other"], id: \.self) { reason in Button(reason, role: .destructive) { Task { await service.moderate(reason: reason) } } } }
  }
  private var setup: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Find people with shared interests").font(.title2.bold())
      Text("Choose a discovery username and up to six interests. People see only this name and these interests while you’re waiting.").foregroundStyle(Palette.secondary)
      TextField("Discovery username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled().padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("discoveryUsername")
      interestsPicker
      if service.transport == "direct" {
        Text("Direct video is free to connect peer to peer. Other participants may learn your network address. Some networks cannot connect; another Wi-Fi or mobile network may help, but is not a guarantee.").font(.caption).foregroundStyle(Palette.secondary)
        Toggle("I agree to direct video connections", isOn: $allowDirect).tint(Palette.maroon).accessibilityIdentifier("discoveryConsent")
      }
      Button(service.busy ? "Saving…" : "Save & enter waiting area") {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines), selected = tags, consent = allowDirect
        Task { await service.saveAndEnter(username: name, tags: selected, allowDirect: consent) }
      }.buttonStyle(PrimaryButton()).disabled(service.busy || !validProfile || (service.transport == "direct" && !allowDirect)).accessibilityIdentifier("discoveryEnter")
      Text("Waiting keeps your camera and microphone off. You choose whom to request, and the other person must accept. Leaving or backgrounding removes you from the waiting area.").font(.caption).foregroundStyle(Palette.secondary)
      if service.state == "ended" { Text("The previous conversation ended.").font(.caption).foregroundStyle(Palette.secondary) }
    }
  }
  private var waiting: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack { Label("Waiting · \(service.profile?.username ?? "")", systemImage: "circle.fill").font(.subheadline.bold()); Spacer(); Button("Leave") { Task { await service.leave() } }.accessibilityIdentifier("discoveryLeave") }
      Text("People waiting now").font(.title2.bold())
      if let outgoing = service.outgoing { HStack { Text("Request sent to \(outgoing.to.username)").font(.subheadline); Spacer(); Button("Cancel") { Task { await service.cancelRequest() } } }.padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14)) }
      if service.people.isEmpty { ContentUnavailableView("No one else is waiting", systemImage: "person.2", description: Text("Keep this screen open. People appear when they choose to wait.")) }
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ForEach(service.people) { person in Button { selectedPerson = person } label: {
          VStack(alignment: .leading, spacing: 12) {
            Text(String(person.username.prefix(1)).uppercased()).font(.largeTitle.bold()).frame(width: 54, height: 54).background(Palette.maroon, in: Circle()).foregroundStyle(Palette.onAccent)
            Text(person.username).font(.headline).lineLimit(1)
            Text(person.tags.map { "#" + $0 }.joined(separator: " ")).font(.caption).foregroundStyle(Palette.secondary).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
          }.padding(16).frame(maxWidth: .infinity, minHeight: 175, alignment: .topLeading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityIdentifier("discoveryPerson") }
      }
    }
  }
  private var connecting: some View {
    VStack(spacing: 18) { ProgressView().tint(Palette.accentText); Text("Confirming both devices…").font(.headline); Text("Video and text stay off until both people are still here.").font(.caption).foregroundStyle(Palette.secondary); Button("Cancel") { Task { await service.leave() } } }.frame(maxWidth: .infinity).padding(.vertical, 50)
  }
  private func connected(_ session: DiscoverySession) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack { Text(session.peer.username).font(.title2.bold()); Spacer(); Button("End", role: .destructive) { Task { await service.leave() } }.accessibilityIdentifier("discoveryEnd") }
      if service.canCapture, let room = session.room {
        VideoChatWebView(roomID: room, initiator: session.initiator, mode: "video", transport: service.transport, iceServers: service.iceServers, signals: service.signals, onSignal: { kind, payload in Task { await service.signal(kind: kind, payloadJSON: payload) } }, onStatus: { status = $0 }).frame(height: 330).clipShape(RoundedRectangle(cornerRadius: 18))
        Text(status).font(.caption).foregroundStyle(Palette.secondary)
      } else { ProgressView("Preparing video…") }
      Button("Continue chatting in Inbox") { Task { await service.continueInInbox() } }.font(.subheadline.bold()).disabled(service.busy)
      ForEach(service.messages) { message in VStack(alignment: message.mine ? .trailing : .leading, spacing: 4) {
        Text(message.mine ? (service.profile?.username ?? "You") : session.peer.username).font(.caption2.bold()).foregroundStyle(Palette.secondary)
        Text(message.body).textSelection(.enabled).padding(12).background(message.mine ? Palette.maroon : Palette.surface, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(message.mine ? Palette.onAccent : Palette.ink)
      }.frame(maxWidth: .infinity, alignment: message.mine ? .trailing : .leading) }
      HStack(alignment: .bottom) { TextField("Say something…", text: $draft, axis: .vertical).lineLimit(1...4).padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14)); Button { let value = draft; Task { if await service.send(value), draft == value { draft = "" } } } label: { Image(systemName: "arrow.up").font(.headline).frame(width: 44, height: 44).background(Palette.maroon, in: Circle()).foregroundStyle(Palette.onAccent) }.disabled(service.sending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.count > 2000).accessibilityLabel("Send message") }
    }
  }
  private func profile(_ person: DiscoveryPerson) -> some View {
    NavigationStack { VStack(alignment: .leading, spacing: 22) { Text(person.username).font(.largeTitle.bold()); Text("Interests").font(.headline); Text(person.tags.map { "#" + $0 }.joined(separator: "  ")).font(.title3).foregroundStyle(Palette.secondary); Button("Send connection request") { selectedPerson = nil; Task { await service.request(person) } }.buttonStyle(PrimaryButton()).disabled(service.outgoing != nil || service.state != "waiting"); Spacer() }.padding(24).appBackground().navigationTitle("Profile").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { selectedPerson = nil } } }
  }
  private let suggestions = ["music", "gaming", "coffee", "engineering", "sports", "art", "movies", "fitness", "books", "cooking", "outdoors", "photography", "football", "study", "technology", "travel", "dance", "animals"]
  private var validProfile: Bool {
    username.trimmingCharacters(in: .whitespacesAndNewlines).range(of: "^[A-Za-z0-9_]{3,20}$", options: .regularExpression) != nil && tags.count <= 6
  }
  private var normalizedCustomTag: String { customTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#")) }
  private var canAddCustomTag: Bool { tags.count < 6 && !tags.contains(normalizedCustomTag) && normalizedCustomTag.range(of: "^[a-z0-9_]{1,24}$", options: .regularExpression) != nil }
  private var interestsPicker: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack { Text("Your interests").font(.headline); Spacer(); Text("\(tags.count) / 6").font(.caption.monospacedDigit()).foregroundStyle(Palette.secondary).accessibilityIdentifier("discoveryInterestCount") }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
        ForEach(Array(Set(suggestions + tags)).sorted { a, b in
          let ai = suggestions.firstIndex(of: a) ?? 999, bi = suggestions.firstIndex(of: b) ?? 999
          return ai == bi ? a < b : ai < bi
        }, id: \.self) { tag in
          let selected = tags.contains(tag)
          Button { if selected { tags.removeAll { $0 == tag } } else if tags.count < 6 { tags.append(tag) } } label: {
            Text("#" + tag).font(.subheadline.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity, minHeight: 40)
              .foregroundStyle(selected ? Palette.onAccent : Palette.ink)
              .background(selected ? Palette.maroon : Palette.surface, in: Capsule())
          }.buttonStyle(.plain).disabled(!selected && tags.count == 6).accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("discoveryTag_" + tag)
        }
      }
      HStack {
        TextField("Add an interest", text: $customTag).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.done).onSubmit { addCustomTag() }.accessibilityIdentifier("discoveryInterests")
        Button("Add", systemImage: "plus") { addCustomTag() }.labelStyle(.iconOnly).font(.headline).disabled(!canAddCustomTag).accessibilityLabel("Add interest")
      }.padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
      Text("Choose up to six, or add your own using letters, numbers and underscores.").font(.caption).foregroundStyle(Palette.secondary)
    }
  }
  private func addCustomTag() { guard canAddCustomTag else { return }; tags.append(normalizedCustomTag); customTag = "" }
  private func fillProfile() {
    guard !profileLoaded, let profile = service.profile else { return }; profileLoaded = true
    username = profile.username; tags = profile.tags
  }
}
