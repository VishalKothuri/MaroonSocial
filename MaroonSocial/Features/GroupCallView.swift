import SwiftUI

struct GroupCallView: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var service: GroupCallService
  @State private var mode = "voice"
  @State private var allowDirect = false
  @State private var status = "Connecting…"
  init(social: SocialService, roomID: String) { _service = State(initialValue: GroupCallService(social: social, roomID: roomID)) }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Label("Group call", systemImage: "person.3.fill").font(.title2.bold())
        if service.canCapture, let call = service.call {
          GroupCallWebView(call: call, iceServers: service.iceServers, signals: service.signals,
            onSignal: { to, kind, payload in Task { await service.signal(to: to, kind: kind, payloadJSON: payload) } },
            onStatus: { status = $0 }, onFailure: { failure in Task { await service.end(); service.error = failure } })
            .frame(height: call.mode == "video" ? 510 : 260).clipShape(RoundedRectangle(cornerRadius: 20))
          Text(status).font(.caption).foregroundStyle(Palette.secondary)
        } else if let call = service.call, call.joined {
          Label("Waiting for another member to join", systemImage: "person.badge.clock")
          Text("Your camera and microphone stay off until another person accepts.").font(.caption).foregroundStyle(Palette.secondary)
        } else {
          Text("Up to four accepted members can join. Each person chooses to accept, and calls end after 20 minutes.").foregroundStyle(Palette.secondary)
          if let call = service.call { Text("\(call.participants.count) in this \(call.mode) call").font(.headline) }
          else { Picker("Call type", selection: $mode) { Text("Voice").tag("voice"); Text("Video").tag("video") }.pickerStyle(.segmented) }
          if (service.call?.transport ?? service.transport) == "direct" {
            Text("Direct calls may reveal your network address to other call participants. Some networks cannot connect without a relay.").font(.caption).foregroundStyle(Palette.secondary)
            Toggle("I agree to a direct group call", isOn: $allowDirect).tint(Palette.maroon).accessibilityIdentifier("groupCallConsent")
          }
          Button(service.call == nil ? "Start group call" : "Join call") { Task { await service.join(mode: service.call?.mode ?? mode, allowDirect: allowDirect) } }
            .buttonStyle(PrimaryButton()).disabled(service.busy || ((service.call?.transport ?? service.transport) == "direct" && !allowDirect)).accessibilityIdentifier("groupCallJoin")
        }
        if let call = service.call {
          ForEach(call.participants) { peer in Label(peer.isMe ? "You · \(peer.alias)" : peer.alias, systemImage: "person.crop.circle").font(.subheadline) }
          if call.joined { Button("Leave call", role: .destructive) { Task { await service.end() } }.buttonStyle(.bordered).accessibilityIdentifier("groupCallEnd") }
        }
        if let error = service.error { Text(error).font(.callout).foregroundStyle(Palette.accentText) }
        if let notice = service.notice { Text(notice).font(.caption).foregroundStyle(Palette.secondary) }
        Text("Leaving this screen or backgrounding the app stops your microphone and camera. Calls are not recorded by this app.").font(.caption).foregroundStyle(Palette.secondary)
      }.padding(24)
    }.appBackground().navigationTitle("Group call").navigationBarTitleDisplayMode(.inline).hidesTabBarWhenPushed()
      .task { await service.activate() }.onDisappear { service.deactivate() }
      .onChange(of: scenePhase) { _, phase in if phase == .background { service.deactivate() } else if phase == .active { Task { await service.activate() } } }
  }
}
