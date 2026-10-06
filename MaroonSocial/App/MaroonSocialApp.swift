import SwiftUI

@main struct MaroonSocialApp: App {
  @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var pushDelegate
  @State private var store = AppStore()
  init() { Palette.configureUIKit() }
  var body: some Scene {
    WindowGroup {
      RootView().environment(store).tint(Palette.accentText).foregroundStyle(Palette.ink).preferredColorScheme(.dark)
        .toggleStyle(SwitchToggleStyle(tint: Palette.maroon))
        .background(Palette.paper.ignoresSafeArea())
    }
  }
}
struct RootView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var openSavedContent = false
  @State private var recoverLogin = false
  @State private var showActiveTag = false
  @State private var startupPresentation = StartupPresentation()
  private var shouldConnect: Bool { store.state.onboarded && scenePhase == .active }
  private var starting: Bool { store.state.onboarded && !store.fixtureMode && !openSavedContent && (!store.connected || startupPresentation.isPresented) }
  private var startupRetrying: Bool { store.busy || store.syncing }
  private struct StartupCompletion: Equatable {
    let ready: Bool
    let presented: Bool
    let reduceMotion: Bool
  }
  var body: some View {
    @Bindable var store = store
    Group {
      if starting {
        StartupView(error: store.connectionError, retrying: startupRetrying,
          artworkAnimating: startupPresentation.animating,
          hasSavedContent: !store.state.posts.isEmpty || !store.state.conversations.isEmpty || !store.state.courses.isEmpty,
          retry: { startupPresentation.restart(at: ProcessInfo.processInfo.systemUptime); Task { await store.refresh() } },
          openSaved: { startupPresentation.cancel(); openSavedContent = true },
          signIn: { startupPresentation.cancel(); recoverLogin = true })
          .onAppear { startupPresentation.begin(at: ProcessInfo.processInfo.systemUptime) }
      } else if store.state.onboarded {
        VStack(spacing: 0) {
          // Campus Tag is hidden (FeatureAvailability): no banner, no sheet, no polling.
          if FeatureAvailability.isCampusTagAvailable() { ActiveTagBanner(service: store.tag) { showActiveTag = true } }
          if let error = store.connectionError {
            HStack(spacing: 8) {
              Image(systemName: "wifi.exclamationmark")
              Text(error).font(.caption).lineLimit(2)
              Spacer()
              Button("Retry") { Task { await store.refresh() } }.font(.caption.bold())
            }.padding(10).background(Palette.hero)
          }
          TabView(selection: $store.tab) {
            Tab("Community", systemImage: "bubble.left.and.bubble.right", value: 0) {
              NavigationStack { CommunityView() }
            }
            Tab("Classes", systemImage: "books.vertical", value: 1) {
              NavigationStack { ClassesView() }
            }
            Tab("Explore", systemImage: "safari", value: 2) { NavigationStack { ExploreView() } }
            Tab("Campus", systemImage: "calendar", value: 3) { NavigationStack { CampusView() } }
            Tab("Inbox", systemImage: "tray", value: 4) { NavigationStack { InboxView() } }.badge(store.inboxCounts.total)
          }.toolbarBackground(Palette.paper, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .swipeBetweenRootTabs(selection: $store.tab, count: 5)
            .onChange(of: store.tab) { previous, selected in
              guard previous != selected, store.state.onboarded, scenePhase == .active, !starting else { return }
              AppHaptics.shared.play(.selection)
            }
        }.background(Palette.paper.ignoresSafeArea()).task { await store.campus.refresh() }

      } else {
        WelcomeView()
      }
    }.background(Palette.paper.ignoresSafeArea())
      .routePushNotifications()
      .sheet(isPresented: Binding(get: { showActiveTag && FeatureAvailability.isCampusTagAvailable() }, set: { showActiveTag = $0 })) { NavigationStack { TagView().toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showActiveTag = false } } } } }
      .sheet(isPresented: $recoverLogin) { NavigationStack { EmailLoginView(linkExisting: store.social.hasDeviceCredential).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { recoverLogin = false }.disabled(store.auth.busy || store.busy) } } } }
      .task(id: shouldConnect) { if shouldConnect { await store.runUpdates() } }
      .task(id: StartupCompletion(ready: store.connected, presented: startupPresentation.isPresented, reduceMotion: reduceMotion)) {
        guard store.connected, startupPresentation.isPresented else { return }
        while let delay = startupPresentation.advanceAfterLoad(at: ProcessInfo.processInfo.systemUptime, reduceMotion: reduceMotion) {
          do { try await Task.sleep(for: .seconds(delay)) } catch { return }
          guard !Task.isCancelled, store.connected else { return }
        }
      }
      .onChange(of: startupRetrying) { _, retrying in
        guard starting, store.connectionError != nil else { return }
        if retrying { startupPresentation.restart(at: ProcessInfo.processInfo.systemUptime) }
        else { startupPresentation.cancel() }
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .background { store.tag.background() }
        if phase == .active, FeatureAvailability.isCampusTagAvailable(), store.tag.hasSession { Task { await store.tag.activate() } }
        if phase != .active { startupPresentation.cancel() }
        else if starting, !recoverLogin { startupPresentation.begin(at: ProcessInfo.processInfo.systemUptime) }
      }
      .onChange(of: store.state.onboarded) { _, onboarded in
        if !onboarded { openSavedContent = false; startupPresentation.cancel(); store.tag.deactivate(); showActiveTag = false }
      }
      .onDisappear { startupPresentation.cancel() }
      .alert(
      "Maroon Social",
      isPresented: Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })
    ) {
      Button("OK") { store.notice = nil }
    } message: {
      Text(store.notice ?? "")
    }
  }
}
struct StartupView: View {
  let error: String?
  let retrying: Bool
  let artworkAnimating: Bool
  let hasSavedContent: Bool
  let retry: () -> Void
  let openSaved: () -> Void
  let signIn: () -> Void
  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      LoadingWordmark(animating: artworkAnimating && (error == nil || retrying))
        // Shared vector asset and geometry match LaunchScreen.storyboard exactly.
        .accessibilityIdentifier("startupWordmark")
      if let error {
        VStack(spacing: 12) {
          Text("Couldn’t connect").font(.headline).foregroundStyle(Palette.ink)
          Text(error).font(.callout).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
          Button(action: retry) {
            HStack(spacing: 8) {
              if retrying { ProgressView().tint(Palette.onAccent) }
              Text(retrying ? "Trying again…" : "Try again")
            }
          }.buttonStyle(PrimaryButton()).disabled(retrying).accessibilityIdentifier("startupRetry")
          Button("Sign in with email", action: signIn).font(.callout).disabled(retrying)
          if hasSavedContent {
            Button("Open saved content", action: openSaved).font(.callout).foregroundStyle(Palette.accentText)
              .padding(.top, 4).accessibilityIdentifier("startupOpenSaved")
          }
        }.frame(maxWidth: 300)
      } else {
        Text("Loading your community…").font(.callout).foregroundStyle(Palette.secondary)
          .accessibilityIdentifier("startupStatus")
      }
      Spacer()
    }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Palette.paper.ignoresSafeArea())
  }
}

struct WelcomeView: View {
  @Environment(AppStore.self) private var store
  @State private var username = ""
  @State private var adult = false
  @State private var emailLogin = false
  @FocusState private var usernameFocused: Bool
  var valid: Bool {
    username.range(of: "^[a-zA-Z0-9_]{3,20}$", options: .regularExpression) != nil && adult
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 23) {
        Wordmark().padding(.top, 10)
        ZStack(alignment: .bottomLeading) {
          CampusPhoto().frame(height: 190).clipped()
          LinearGradient(
            colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
          VStack(alignment: .leading, spacing: 5) {
            Text("ALL AGGIES.\nALL YOU.").font(.system(size: 34, weight: .black)).tracking(-2)
            Text("Your campus. Your conversations.").font(.subheadline)
          }.foregroundStyle(.white).padding(22)
        }.clipShape(RoundedRectangle(cornerRadius: 25))
        Text("Make yourself at home.").font(.system(size: 29, weight: .bold, design: .serif))
        Text(
          "Pick one username for classes, hangouts and games. You can post anonymously in the community."
        ).foregroundStyle(.secondary)
        TextField("Your username", text: $username).textInputAutocapitalization(.never)
          .autocorrectionDisabled().focused($usernameFocused).submitLabel(.done)
          .onSubmit { usernameFocused = false }.padding(16).background(
            Palette.surface, in: RoundedRectangle(cornerRadius: 14)
          ).accessibilityIdentifier("username")
        Text("3–20 letters, numbers or underscores.")
          .font(.caption).foregroundStyle(.secondary).padding(.top, -15)
        Toggle("I’m 18 or older", isOn: $adult).font(.subheadline).accessibilityIdentifier(
          "adultToggle")
        Button(store.busy ? "Connecting…" : "Explore Maroon Social") {
          usernameFocused = false
          store.enter(username: username)
        }.buttonStyle(
          PrimaryButton()
        ).disabled(!valid || store.busy).opacity(valid ? 1 : 0.5).accessibilityIdentifier("enterPreview")
        Button("Sign in or recover with personal email") { emailLogin = true }.font(.subheadline).accessibilityIdentifier("emailLogin")
        Text(
          "Shared campus community. Your account is secured on this device. University verification is not enabled yet; do not treat membership as proof of enrollment."
        ).font(.caption).foregroundStyle(.secondary)
      }.padding(24)
    }.scrollDismissesKeyboard(.interactively).appBackground()
      .sheet(isPresented: $emailLogin) { NavigationStack { EmailLoginView(linkExisting: false).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { emailLogin = false }.disabled(store.auth.busy || store.busy) } } } }
  }
}
struct CampusPhoto: View {
  var body: some View {
    Group {
      if let image = UIImage(named: "campus.jpg") {
        GeometryReader { geometry in
          Image(uiImage: image).resizable().scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
      } else {
        ZStack {
          Palette.maroon
          Image(systemName: "building.columns.fill").font(.system(size: 90)).foregroundStyle(
            .white.opacity(0.3))
        }
      }
    }
  }
}
