import SwiftUI

struct ConnectionsView: View {
  @State private var service: AccountControlsService
  @State private var username = ""
  @State private var removing: NamedConnection?
  @State private var messaging: NamedConnection?
  @State private var destination: String?
  @FocusState private var typing: Bool
  init(social: SocialService) { _service = State(initialValue: AccountControlsService(social: social)) }
  private var accepted: [NamedConnection] { service.connections.filter { $0.status == "accepted" } }
  private var incoming: [NamedConnection] { service.connections.filter { $0.status == "incoming" } }
  private var outgoing: [NamedConnection] { service.connections.filter { $0.status == "outgoing" } }
  var body: some View {
    List {
      Section {
        TextField("Their username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled().focused($typing)
          .accessibilityIdentifier("connectionUsername")
        Button("Send connection request", systemImage: "person.badge.plus") {
          typing = false
          Task { if await service.act("connection.request", ["username": username]) { username = ""; if service.notice == nil { service.notice = "Request sent. They choose whether to accept." } } }
        }.disabled(service.busy || username.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "").range(of: "^[a-zA-Z0-9_]{3,20}$", options: .regularExpression) == nil)
          .accessibilityIdentifier("connectionSend")
      } header: { Text("Connect by username") } footer: {
        Text("Your username is shown in this invitation. Accepting connects your named accounts; it never reveals either person’s anonymous posts or private memberships.")
      }
      if let error = service.error { Section { Text(error).font(.callout).foregroundStyle(Palette.accentText); Button("Try again") { Task { await service.act("connections") } } } }
      if let notice = service.notice { Section { Label(notice, systemImage: "checkmark.circle").font(.callout) } }
      if !incoming.isEmpty {
        Section("Requests") {
          ForEach(incoming) { person in
            VStack(alignment: .leading, spacing: 12) {
              personLabel(person)
              HStack {
                Button("Accept") { Task { await service.act("connection.accept", ["id": person.id]) } }.buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent)
                  .accessibilityIdentifier("connectionAccept-\(person.id)")
                Button("Decline", role: .destructive) { Task { await service.act("connection.remove", ["id": person.id]) } }.buttonStyle(.bordered)
              }.disabled(service.busy)
            }.padding(.vertical, 5)
          }
        }
      }
      Section("Connected") {
        if accepted.isEmpty { Text(service.loaded ? "No connections yet" : "Loading connections…").foregroundStyle(.secondary) }
        ForEach(accepted) { person in
          HStack {
            personLabel(person)
            Spacer()
            Menu {
              Button("Message", systemImage: "bubble.left") { messaging = person }
              Button("Remove connection", systemImage: "person.badge.minus", role: .destructive) { removing = person }
            } label: { Image(systemName: "ellipsis").padding(8) }.accessibilityLabel("Connection options for \(person.username)")
          }
        }
      }
      if !outgoing.isEmpty {
        Section("Sent requests") {
          ForEach(outgoing) { person in
            HStack {
              personLabel(person)
              Spacer()
              Button("Cancel request", role: .destructive) { Task { await service.act("connection.remove", ["id": person.id]) } }.font(.caption).disabled(service.busy)
            }
          }
        }
      }
      if service.busy { ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear) }
    }.scrollContentBackground(.hidden).appBackground().scrollDismissesKeyboard(.interactively)
      .navigationTitle("Connections").navigationBarTitleDisplayMode(.inline)
      .task {
        await service.act("connections")
        while !Task.isCancelled {
          do { try await Task.sleep(for: .seconds(8)) } catch { break }
          guard !Task.isCancelled else { break }
          await service.act("connections")
        }
      }.maroonRefreshable(scope: "connections") { await service.act("connections") }
      .toolbar { ToolbarItem(placement: .topBarTrailing) { if typing { KeyboardDismissButton { typing = false } } } }
      .confirmationDialog("Remove this connection?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
        Button("Remove connection", role: .destructive) {
          if let person = removing { Task { await service.act("connection.remove", ["id": person.id]) } }; removing = nil
        }
      } message: { Text("Existing conversations remain. Use Block in a conversation to stop contact.") }
      .sheet(item: $messaging) { person in NewMessageView(initialUsername: person.username) { destination = $0 } }
      .navigationDestination(item: $destination) { ChatView(id: $0) }
  }
  private func personLabel(_ person: NamedConnection) -> some View {
    HStack(spacing: 10) {
      Avatar(size: 32)
      VStack(alignment: .leading, spacing: 3) {
        Text("@\(person.username)").font(.subheadline.bold())
        if person.status != "accepted" { Text(person.status == "incoming" ? "Wants to connect" : "Waiting for acceptance").font(.caption).foregroundStyle(.secondary) }
      }
    }
  }
}
