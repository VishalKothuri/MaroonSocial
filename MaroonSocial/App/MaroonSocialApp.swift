import SwiftUI

@main struct MaroonSocialApp: App {
  @State private var store = AppStore()
  var body: some Scene {
    WindowGroup { RootView().environment(store).tint(Palette.maroon).preferredColorScheme(.light) }
  }
}
struct RootView: View {
  @Environment(AppStore.self) private var store
  var body: some View {
    @Bindable var store = store
    Group {
      if store.state.onboarded {
        VStack(spacing: 0) {
          PreviewLabel()
          TabView(selection: $store.tab) {
            Tab("Community", systemImage: "bubble.left.and.bubble.right", value: 0) {
              NavigationStack { CommunityView() }
            }
            Tab("Classes", systemImage: "books.vertical", value: 1) {
              NavigationStack { ClassesView() }
            }
            Tab("Explore", systemImage: "sparkles", value: 2) { NavigationStack { ExploreView() } }
            Tab("Campus", systemImage: "calendar", value: 3) { NavigationStack { CampusView() } }
            Tab("Inbox", systemImage: "tray", value: 4) { NavigationStack { InboxView() } }
          }
        }.task { await store.campus.refresh() }
      } else {
        WelcomeView()
      }
    }.alert(
      "Maroon Social",
      isPresented: Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })
    ) {
      Button("OK") { store.notice = nil }
    } message: {
      Text(store.notice ?? "")
    }
  }
}
struct WelcomeView: View {
  @Environment(AppStore.self) private var store
  @State private var username = ""
  @State private var adult = false
  var valid: Bool {
    username.range(of: "^[a-zA-Z0-9_]{3,20}$", options: .regularExpression) != nil && adult
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 23) {
        Wordmark().padding(.top, 30)
        ZStack(alignment: .bottomLeading) {
          CampusPhoto().frame(height: 275).clipped()
          LinearGradient(
            colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
          VStack(alignment: .leading, spacing: 5) {
            Text("ALL AGGIES.\nALL YOU.").font(.system(size: 43, weight: .black)).tracking(-2)
            Text("Your campus. Your conversations.").font(.subheadline)
          }.foregroundStyle(.white).padding(22)
        }.clipShape(RoundedRectangle(cornerRadius: 25))
        Text("Make yourself at home.").font(.system(size: 29, weight: .bold, design: .serif))
        Text(
          "Pick one username for classes, hangouts and games. You can post anonymously in the community."
        ).foregroundStyle(.secondary)
        TextField("Your username", text: $username).textInputAutocapitalization(.never)
          .autocorrectionDisabled().padding(16).background(
            .white, in: RoundedRectangle(cornerRadius: 14)
          ).accessibilityIdentifier("username")
        Toggle("I’m 18 or older", isOn: $adult).font(.subheadline).accessibilityIdentifier(
          "adultToggle")
        Button("Explore local preview") { store.enter(username: username) }.buttonStyle(
          PrimaryButton()
        ).disabled(!valid).opacity(valid ? 1 : 0.5).accessibilityIdentifier("enterPreview")
        Text(
          "Preview only. No email is collected and no student status is verified. Account enrollment will be connected after backend setup."
        ).font(.caption).foregroundStyle(.secondary)
      }.padding(24)
    }.appBackground()
  }
}
struct CampusPhoto: View {
  var body: some View {
    Group {
      if let image = UIImage(named: "campus.jpg") {
        Image(uiImage: image).resizable().scaledToFill()
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
