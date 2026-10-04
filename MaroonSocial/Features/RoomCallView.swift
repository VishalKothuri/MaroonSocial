import SwiftUI

struct RoomCallView: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var service: RoomCallService
  @State private var mode = "voice"
  @State private var allowDirect = false
  @State private var callStatus = "Connecting…"

  init(social: SocialService, roomID: String) {
    _service = State(initialValue: RoomCallService(social: social, roomID: roomID))
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Label("Voice & video", systemImage: "phone.bubble.fill").font(.title2.bold()).foregroundStyle(Palette.ink)
        if service.canCapture, let call = service.call {
          VideoChatWebView(roomID: call.id, initiator: call.initiator, mode: call.mode, transport: call.transport,
            iceServers: service.iceServers, signals: service.signals,
            onSignal: { kind, payload in Task { await service.sendSignal(kind: kind, payloadJSON: payload) } },
            onStatus: { callStatus = $0 })
            .frame(height: call.mode == "video" ? 420 : 190)
            .clipShape(RoundedRectangle(cornerRadius: 22))
          Text(callStatus).font(.subheadline).foregroundStyle(.secondary)
        } else if let call = service.call {
          Label(call.incoming ? "Incoming \(call.mode) call" : call.state == "ringing" ? "Waiting for an answer…" : "Ready to join the call", systemImage: call.mode == "video" ? "video.fill" : "phone.fill")
            .font(.headline).padding(.vertical, 14)
          if call.incoming || (call.state == "connected" && !service.consented) {
            consent
            Button("Accept \(call.mode) call") { Task { await service.accept(allowDirect: allowDirect) } }
              .buttonStyle(PrimaryButton()).disabled(service.busy || needsConsent)
              .accessibilityIdentifier("roomCallAccept")
          } else if call.state == "connected" { ProgressView("Preparing call…") }
        } else {
          Text("Invite the other person to a voice or video call. The camera and microphone start only after both people accept.")
            .foregroundStyle(.secondary)
          Picker("Call type", selection: $mode) { Text("Voice").tag("voice"); Text("Video").tag("video") }.pickerStyle(.segmented)
          consent
          Button { Task { await service.invite(mode: mode, allowDirect: allowDirect) } } label: {
            Label(service.busy ? "Calling…" : "Invite to \(mode) call", systemImage: mode == "video" ? "video" : "phone")
          }.buttonStyle(PrimaryButton()).disabled(service.busy || needsConsent).accessibilityIdentifier("roomCallInvite")
        }
        if let call = service.call {
          Button(call.incoming ? "Decline" : "End call", role: .destructive) { Task { await service.end(decline: call.incoming) } }
            .buttonStyle(.bordered).tint(Palette.accentText).accessibilityIdentifier("roomCallEnd")
        }
        if let notice = service.notice { Text(notice).font(.subheadline).foregroundStyle(.secondary) }
        if let error = service.error { Text(error).font(.callout).foregroundStyle(Palette.accentText).accessibilityIdentifier("roomCallError") }
        Text("Leaving this screen or sending the app to the background ends your call. Calls are not recorded by this app.")
          .font(.caption).foregroundStyle(.secondary)
      }.padding(24)
    }
    .appBackground().navigationTitle("Voice & video").navigationBarTitleDisplayMode(.inline)
    .toolbar(.hidden, for: .tabBar)
    .task { await service.activate() }
    .onDisappear { service.deactivate() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background { service.deactivate() }
      else if phase == .active { Task { await service.activate() } }
    }
  }
  private var needsConsent: Bool { (service.call?.transport ?? service.transport) == "direct" && !allowDirect }
  @ViewBuilder private var consent: some View {
    if (service.call?.transport ?? service.transport) == "direct" {
      VStack(alignment: .leading, spacing: 12) {
        Text("Direct calls may reveal your network address to the other person. Some networks cannot connect without a relay.").font(.caption).foregroundStyle(.secondary)
        Toggle("I agree to a direct call", isOn: $allowDirect).font(.subheadline).tint(Palette.maroon).accessibilityIdentifier("roomCallDirectConsent")
      }.padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
    }
  }
}
