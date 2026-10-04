import CoreLocation
import MapKit
import SwiftUI

struct TagView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var phase
  var body: some View {
    TagSessionView(service: store.tag)
      .appBackground().navigationTitle("Campus Tag").navigationBarTitleDisplayMode(.inline)
      .task { await store.tag.activate() }
      .onChange(of: phase) { _, phase in
        if phase == .background { store.tag.background() }
        if phase == .active { Task { await store.tag.activate() } }
      }
  }
}

private struct TagSessionView: View {
  @Bindable var service: TagService
  @State private var code = ""
  @State private var createSheet = false
  @State private var consent = false
  @State private var rules = false
  @State private var map = false
  @State private var chat = false
  @State private var confirmEnd = false
  @FocusState private var codeFocused: Bool
  private var finished: Bool { service.state == "finished" || service.state == "cancelled" }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        if let notice = service.notice {
          Label(notice, systemImage: "checkmark.shield").font(.caption).foregroundStyle(.secondary)
        }
        if let error = service.error {
          Label(error, systemImage: "wifi.exclamationmark").font(.callout)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("tagError")
        }
        if let lobby = service.lobby {
          matchHeader(lobby)
          if finished { results(lobby) }
          else if service.state == "lobby" { lobbyControls(lobby) }
          else { matchControls(lobby) }
          roster
          if !finished {
            HStack {
              Button { chat = true } label: { Label("Team & lobby chat", systemImage: "bubble.left.and.bubble.right") }
              Spacer()
              if let last = service.messages.last { Text(last.username).lineLimit(1).foregroundStyle(.secondary) }
            }.font(.caption.bold())
            Button("Leave & stop sharing", role: .destructive) {
              Task { await service.leave() }
            }.frame(maxWidth: .infinity).padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
              .accessibilityIdentifier("tagLeave")
          }
        } else { home }
      }.padding(18)
    }.scrollDismissesKeyboard(.interactively)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Rules", systemImage: "info.circle") { rules = true }
        }
        ToolbarItem(placement: .topBarTrailing) {
          if codeFocused { KeyboardDismissButton { codeFocused = false } }
        }
      }
      .sheet(isPresented: $createSheet) { CreateTagLobby(service: service) }
      .sheet(isPresented: $rules) { TagRulesView() }
      .sheet(isPresented: $map) { TagBoundaryView(service: service) }
      .sheet(isPresented: $chat) { TagChatView(service: service) }
      .confirmationDialog("End this match for everyone?", isPresented: $confirmEnd, titleVisibility: .visible) {
        Button("End match", role: .destructive) { Task { await service.end() } }
      }
      .onChange(of: service.lobby?.id) { _, _ in consent = false }
  }
  private var home: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 14) {
        Image(systemName: "location.north.circle.fill").font(.system(size: 44)).foregroundStyle(Palette.accentText)
        VStack(alignment: .leading, spacing: 5) {
          Text("Hide & seek with your people").font(.title3.bold())
          Text("Private lobbies · 2–12 players").font(.caption).foregroundStyle(.secondary)
        }
      }
      Text("Choose a permitted outdoor meeting area together. Create a lobby, share its code, and split into hiders and seekers.")
        .font(.subheadline).foregroundStyle(.secondary)
      Button("Create a private lobby", systemImage: "plus") { createSheet = true }
        .buttonStyle(PrimaryButton()).disabled(service.busy).accessibilityIdentifier("tagCreate")
      VStack(alignment: .leading, spacing: 12) {
        Text("Have a code?").font(.headline)
        HStack {
          TextField("8-character lobby code", text: $code).focused($codeFocused)
            .textInputAutocapitalization(.characters).autocorrectionDisabled()
            .font(.system(.body, design: .monospaced)).padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("tagCode")
          Button("Join") {
            codeFocused = false
            Task { await service.join(code: code) }
          }.buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent).disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).count != 8 || service.busy)
            .accessibilityIdentifier("tagJoin")
        }
      }
      Label("Location stays off until you consent for a match and the host starts it.", systemImage: "location.slash")
        .font(.caption).foregroundStyle(.secondary)
      if service.busy { ProgressView("Connecting…").frame(maxWidth: .infinity) }
    }
  }
  private func matchHeader(_ lobby: TagLobby) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(lobby.title).font(.title3.bold())
        Spacer()
        ShareLink(item: "Join my Maroon Social Campus Tag lobby: \(lobby.code). Meeting area: \(lobby.area).") {
          Label(lobby.code, systemImage: "square.and.arrow.up").font(.system(.caption, design: .monospaced).bold())
        }.accessibilityIdentifier("tagShareCode")
      }
      Label(lobby.area, systemImage: "mappin").font(.subheadline)
      HStack {
        Text("\(lobby.durationSeconds / 60) min · \(lobby.hideSeconds)s hiding · \(lobby.radiusM)m boundary")
        Spacer()
        Text("\(service.players.count)/\(lobby.capacity)")
      }.font(.caption).foregroundStyle(.secondary)
    }
  }
  private func lobbyControls(_ lobby: TagLobby) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Picker("Your role", selection: Binding(get: { service.me?.role ?? "hider" }, set: { role in Task { await service.choose(role: role) } })) {
        Text("Hider").tag("hider")
        Text("Seeker").tag("seeker")
      }.pickerStyle(.segmented).disabled(service.busy).accessibilityIdentifier("tagRole")
      VStack(alignment: .leading, spacing: 10) {
        Label("Location for this match", systemImage: "location.circle").font(.headline)
        Text("During foreground play, your latest position is sent to the game server, including while you use other app tabs. Seekers receive distance bands and compass directions, never your coordinates. Pause or background the app to stop sharing; resume within 90 seconds or leave the match. Hints expire after 45 seconds.")
          .font(.caption).foregroundStyle(.secondary)
        Toggle("I agree to share location for this match", isOn: $consent).font(.subheadline)
          .disabled(service.me?.ready == true).accessibilityIdentifier("tagConsent")
      }.padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
      Button(service.me?.ready == true ? "Not ready" : "I’m ready") {
        Task { await service.ready(consent: service.me?.ready != true && consent) }
      }.buttonStyle(PrimaryButton()).disabled(service.busy || (service.me?.ready != true && !consent))
        .accessibilityIdentifier("tagReady")
      if lobby.host {
        Button("Start hiding countdown") { Task { await service.start() } }
          .buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent).frame(maxWidth: .infinity)
          .disabled(service.busy || service.players.count < 2 || !service.players.allSatisfy(\.ready)
                    || !service.players.contains(where: { $0.role == "hider" })
                    || !service.players.contains(where: { $0.role == "seeker" }))
          .accessibilityIdentifier("tagStart")
      } else { Text("The host starts when everyone is ready.").font(.caption).foregroundStyle(.secondary) }
    }
  }
  private func matchControls(_ lobby: TagLobby) -> some View {
    VStack(spacing: 15) {
      TimelineView(.periodic(from: .now, by: 1)) { _ in
        VStack(spacing: 10) {
          Text(service.state == "hiding" ? "HIDING TIME" : service.me?.caught == true ? "CAUGHT" : "\((service.me?.role ?? "player").uppercased())")
            .font(.system(size: 10, weight: .bold)).tracking(2)
          let deadline = service.state == "hiding" ? lobby.seekAt : lobby.endsAt
          let seconds = max(0, Int((deadline ?? 0) - service.now.timeIntervalSince1970))
          Text(String(format: "%02d:%02d", seconds / 60, seconds % 60)).font(.system(size: 45, weight: .semibold, design: .rounded).monospacedDigit())
          Text(service.state == "hiding" ? "Hiders, find your spot. Seekers, stay at the meeting area." : service.me?.caught == true ? "Your location is off. Cheer on your team." : "Stay in your agreed public play area.")
            .font(.caption).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(20).foregroundStyle(Palette.lime)
          .background(Palette.hero, in: RoundedRectangle(cornerRadius: 22))
      }
      HStack {
        Label(service.sharing ? (service.me?.locationFresh == true ? "Location sharing on" : "Waiting for location") : "Location sharing off", systemImage: service.sharing ? "location.fill" : "location.slash")
        Spacer()
        Button("Boundary map") { map = true }
      }.font(.caption.bold())
      if service.needsResume {
        VStack(alignment: .leading, spacing: 10) {
          Label("Location sharing paused", systemImage: "pause.circle.fill").font(.headline)
          TimelineView(.periodic(from: .now, by: 1)) { _ in
            Text(service.pauseCountdown.map { "Resume within \($0)s to stay in this match. The game timer continues." } ?? "Your location is off. Consent again to resume this match.")
              .font(.caption).foregroundStyle(.secondary)
          }
          Button("Agree & resume sharing") { Task { await service.resume() } }
            .buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent).disabled(service.busy).accessibilityIdentifier("tagResume")
        }.padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
      } else if service.sharing {
        Button("Pause location sharing", systemImage: "pause.circle") { Task { await service.pause() } }.disabled(service.busy).accessibilityIdentifier("tagPause")
      }
      if let error = service.location.error {
        Text(error).font(.caption).foregroundStyle(Palette.accentText)
        if service.location.denied, let settings = URL(string: UIApplication.openSettingsURLString) {
          Link("Open Settings", destination: settings)
        }
      } else if service.me?.caught != true && service.me?.locationFresh != true {
        Label("Waiting for a fresh GPS location. Hints are paused.", systemImage: "location.magnifyingglass")
          .font(.caption).foregroundStyle(.secondary)
      }
      if service.me?.outside == true {
        Label("You’re outside the approximate boundary. Return to the agreed area safely.", systemImage: "exclamationmark.triangle")
          .font(.callout).foregroundStyle(Palette.accentText)
      }
      ForEach(service.catches) { attempt in
        VStack(alignment: .leading, spacing: 10) {
          if attempt.target == service.me?.id {
            Text("@\(attempt.requesterName) says they found you.").font(.headline)
            Text("Confirm only if you have met in person. GPS alone does not count.").font(.caption)
            HStack {
              Button("Not caught", role: .cancel) { Task { await service.confirm(attempt.id, accept: false) } }
              Spacer()
              Button("Yes, caught me") { Task { await service.confirm(attempt.id, accept: true) } }
            }.font(.subheadline.bold()).disabled(service.busy)
          } else {
            Label("Waiting for @\(attempt.targetName) to confirm…", systemImage: "hourglass").font(.subheadline)
          }
        }.padding(16).background(Palette.lime.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
      }
      if service.state == "seeking", service.me?.role == "seeker" {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("Hider hints").font(.headline)
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { _ in
              Text(service.hintCountdown.map { $0 == 0 ? "Updating hint…" : "Next hint in \($0)s" } ?? "Hints paused")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary).accessibilityIdentifier("tagNextHint")
            }
          }
          if service.hints.isEmpty {
            Text("Hints appear when both players have fresh locations inside the boundary.").font(.caption).foregroundStyle(.secondary)
          }
          ForEach(service.hints) { hint in
            HStack(spacing: 12) {
              VStack(spacing: 5) {
                Image(systemName: "location.north.fill").rotationEffect(.degrees(direction(hint.direction) - (service.location.hasHeading ? service.location.heading : 0)))
                Text(hint.direction).font(.caption.bold())
              }.foregroundStyle(Palette.accentText).frame(width: 36)
              VStack(alignment: .leading, spacing: 4) {
                Text("@\(hint.username)").font(.subheadline.bold())
                Text(hint.distance).font(.caption)
                Text(Date(timeIntervalSince1970: hint.recordedAt), style: .relative).font(.caption2).foregroundStyle(.secondary)
              }
              Spacer()
              Button("Found them") { Task { await service.catchPlayer(hint.id) } }
                .font(.caption.bold()).disabled(service.busy)
            }.padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 15))
          }
        }
      }
      if lobby.host { Button("End match for everyone", role: .destructive) { confirmEnd = true }.font(.caption) }
    }
  }
  private var roster: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Players").font(.headline)
      ForEach(service.players) { player in
        HStack(spacing: 10) {
          Circle().fill(player.online ? Color.green : Color.gray).frame(width: 7, height: 7)
          Text("@\(player.username)").font(.subheadline)
          Spacer()
          Text(player.caught ? "Caught" : player.role.capitalized).font(.caption).foregroundStyle(.secondary)
          if player.id != service.me?.id {
            Menu {
              Button("Report unsafe play", role: .destructive) { Task { await service.moderate(player: player.id, reason: "Unsafe play") } }
              Button("Report harassment", role: .destructive) { Task { await service.moderate(player: player.id, reason: "Harassment") } }
              Button("Block player & leave", role: .destructive) { Task { await service.moderate(player: player.id) } }
            } label: { Image(systemName: "ellipsis").padding(6) }.accessibilityLabel("Player options for \(player.username)")
          }
          if service.state == "lobby" {
            Image(systemName: player.ready ? "checkmark.circle.fill" : "circle")
              .foregroundStyle(player.ready ? Palette.accentText : Color.secondary)
          }
        }
      }
    }.padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
  }
  private func results(_ lobby: TagLobby) -> some View {
    VStack(spacing: 12) {
      Image(systemName: service.state == "finished" ? "flag.checkered" : "stop.circle").font(.largeTitle)
      Text(lobby.winner.map { "\($0.capitalized) win!" } ?? "Match ended").font(.title2.bold())
      Text("Location sharing is off. Temporary positions have been cleared.").font(.caption).foregroundStyle(.secondary)
      if let results = service.snapshot?.results {
        Text("\(results.totalCatches) confirmed catches · \(results.durationSeconds / 60)m \(results.durationSeconds % 60)s played")
          .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("tagResultsSummary")
        ForEach(results.players) { player in
          HStack {
            VStack(alignment: .leading, spacing: 4) { Text("@\(player.username)").font(.subheadline.bold()); Text(player.summary).font(.caption).foregroundStyle(.secondary) }
            Spacer(); Text(player.role.capitalized).font(.caption)
          }.padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        }
      }
      if service.snapshot?.rematchCode != nil {
        Button("Join rematch lobby") { Task { await service.joinRematch() } }.buttonStyle(PrimaryButton()).disabled(service.busy).accessibilityIdentifier("tagJoinRematch")
      } else if lobby.host {
        Button("Create rematch lobby") { Task { await service.rematch() } }.buttonStyle(PrimaryButton()).disabled(service.busy).accessibilityIdentifier("tagRematch")
        Text("Same settings, fresh consent. Other players choose whether to join.").font(.caption).foregroundStyle(.secondary)
      }
      Button("Done") { Task { await service.leave() } }.buttonStyle(PrimaryButton())
    }.padding(18)
  }
  private func direction(_ value: String) -> Double {
    ["N": 0, "NE": 45, "E": 90, "SE": 135, "S": 180, "SW": 225, "W": 270, "NW": 315][value] ?? 0
  }
}

private struct CreateTagLobby: View {
  @Bindable var service: TagService
  @Environment(\.dismiss) private var dismiss
  @State private var title = "Campus hide & seek"
  @State private var area = ""
  @State private var duration = 10
  @State private var hiding = 60
  @State private var capacity = 8
  @State private var radius = 300
  @State private var permission = false
  @FocusState private var typing: Bool
  var body: some View {
    NavigationStack {
      Form {
        Section("Meet first, then play") {
          TextField("Lobby name", text: $title).focused($typing).accessibilityIdentifier("tagLobbyTitle")
          TextField("Agreed public outdoor area", text: $area).focused($typing).accessibilityIdentifier("tagArea")
          Text("The group must confirm access and boundaries in person. The map is an approximate reminder, not permission to enter roads, buildings or restricted spaces.").font(.caption)
          Toggle("We’ll use an area where play is permitted", isOn: $permission).font(.subheadline)
        }
        Section("Match settings") {
          Picker("Seeking time", selection: $duration) { ForEach([5,10,15,20,30], id: \.self) { Text("\($0) minutes").tag($0) } }
          Picker("Hiding time", selection: $hiding) { ForEach([30,60,120], id: \.self) { Text("\($0) seconds").tag($0) } }
          Picker("Approximate boundary", selection: $radius) { ForEach([150,300,500], id: \.self) { Text("\($0) metres").tag($0) } }
          Stepper("Up to \(capacity) players", value: $capacity, in: 2...12)
        }
        if let error = service.error { Section { Text(error).foregroundStyle(Palette.accentText) } }
      }.scrollContentBackground(.hidden).appBackground().scrollDismissesKeyboard(.interactively)
        .navigationTitle("New Tag lobby").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Create") {
              typing = false
              Task {
                await service.create(title: title, area: area, duration: duration, hiding: hiding, capacity: capacity, radius: radius)
                if service.lobby != nil { dismiss() }
              }
            }.disabled(service.busy || !permission || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                       || area.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || title.count > 60 || area.count > 120)
              .accessibilityIdentifier("tagPublishLobby")
          }
          ToolbarItem(placement: .topBarTrailing) { if typing { KeyboardDismissButton { typing = false } } }
        }
    }
  }
}
private struct TagRulesView: View {
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("A real game, with people you know.").font(.title3.bold())
          Text("1. Meet in a permitted public outdoor area. Agree on walkable limits, then share your private lobby code.\n\n2. Choose hider or seeker, consent to location for this match, and get ready.\n\n3. The host starts the hiding countdown. Seekers remain at the meeting area until it ends.\n\n4. Seekers get coarse direction and distance hints every 30 seconds. Find someone in person and request a catch. The hider must confirm within 30 seconds; stale or distant GPS cannot confirm a catch.\n\n5. Seekers win by catching every hider. Hiders win if time runs out. Switching app tabs keeps your match active. Pause or background the app to stop location immediately; resume within 90 seconds or the server removes you. The game clock keeps running.")
            .font(.subheadline).lineSpacing(4)
          Text("Latest coordinates are rounded to roughly 10 m and kept only for active play. Other players never receive those coordinates. Stale positions stop producing hints after 45 seconds and are removed within two minutes; completed lobby/chat records expire after one hour. Reports retain the submitted text and context, never coordinates. A rough host starting area is shared as the boundary centre. Compass and GPS accuracy vary: follow agreed walkable boundaries, not an arrow across a road.")
            .font(.caption).foregroundStyle(.secondary)
        }.padding(22)
      }.appBackground().navigationTitle("Tag rules").navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Done") { dismiss() } }
    }
  }
}
private struct TagBoundaryView: View {
  @Bindable var service: TagService
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      VStack(spacing: 15) {
        if let lobby = service.lobby, let lat = lobby.centerLat, let lon = lobby.centerLon {
          let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
          Map(initialPosition: .region(MKCoordinateRegion(center: center, latitudinalMeters: Double(lobby.radiusM) * 3, longitudinalMeters: Double(lobby.radiusM) * 3))) {
            MapCircle(center: center, radius: Double(lobby.radiusM)).foregroundStyle(Palette.maroon.opacity(0.12)).stroke(Palette.maroon, lineWidth: 2)
            Marker(lobby.area, coordinate: center).tint(Palette.maroon)
          }.clipShape(RoundedRectangle(cornerRadius: 20))
          Text("Approximate \(lobby.radiusM)m boundary. Use your agreed outdoor limits; roads, buildings and restricted areas are excluded.")
            .font(.caption).foregroundStyle(.secondary)
        } else {
          EmptyCard(icon: "map", title: "Boundary appears after start", detail: "The host’s first location during play sets the approximate meeting-area centre.")
        }
      }.padding(18).appBackground().navigationTitle("Play area").navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Done") { dismiss() } }
    }
  }
}
private struct TagChatView: View {
  @Bindable var service: TagService
  @Environment(\.dismiss) private var dismiss
  @State private var team = true
  @FocusState private var typing: Bool
  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 12) {
            if service.messages.isEmpty { Text("Coordinate with your lobby here.").font(.caption).foregroundStyle(.secondary) }
            ForEach(service.messages) { item in
              VStack(alignment: .leading, spacing: 6) {
                Text("@\(item.username) · \(item.team == nil ? "Lobby" : "Team")").font(.caption.bold()).foregroundStyle(.secondary)
                Text(item.body)
              }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14)).id(item.id)
            }
          }.padding(18)
        }.scrollDismissesKeyboard(.interactively).appBackground()
          .onChange(of: service.messages.count) { _, _ in if let last = service.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
      }.safeAreaInset(edge: .bottom) {
        VStack(spacing: 8) {
          if service.playing { Toggle("Team only", isOn: $team).font(.caption) }
          HStack {
            TextField("Message…", text: $service.message, axis: .vertical).lineLimit(1...3).focused($typing)
              .padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("tagMessage")
            Button { Task { await service.send(team: team) } } label: { Image(systemName: "arrow.up.circle.fill").font(.title) }
              .disabled(service.busy || service.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.message.count > 500)
              .accessibilityLabel("Send Tag message")
          }
        }.padding(16).background(Palette.paper)
      }.navigationTitle("Tag chat").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
          ToolbarItem(placement: .topBarTrailing) { if typing { KeyboardDismissButton { typing = false } } }
        }
    }
  }
}
