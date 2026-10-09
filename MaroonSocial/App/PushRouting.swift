import SwiftUI

/// A notification is a hint, never proof that a room or post is still accessible.
struct ResolvedPushRoute: Decodable {
  let kind: String
  let roomID: String?
  let postID: String?
  let gameID: String?
  enum Target: Equatable { case room(String), post(String), game(String) }
  var target: Target? {
    if ["game_invite", "game_turn"].contains(kind), let gameID, UUID(uuidString: gameID) != nil { return .game(gameID) }
    if let roomID, !roomID.isEmpty, roomID.count <= 160 { return .room(roomID) }
    if kind == "activity", let postID, UUID(uuidString: postID) != nil { return .post(postID) }
    return nil
  }
}

private struct PushRoutePresentation: Identifiable {
  let id = UUID()
  let target: ResolvedPushRoute.Target
}

private struct PushRouting: ViewModifier {
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  @State private var service = PushService.shared
  @State private var presentation: PushRoutePresentation?
  private struct Readiness: Equatable {
    let destination: PushDestination?
    let available: Bool
    let owner: String
    let identityRevision: Int
  }
  /// A post link waits for a signed-in, connected, active app; then it opens like a post notification.
  private struct LinkReadiness: Equatable {
    let link: String?
    let ready: Bool
  }

  func body(content: Content) -> some View {
    content
      .task(id: Readiness(destination: service.destination,
        available: store.connected && store.state.onboarded && scenePhase == .active,
        owner: store.compositions.owner, identityRevision: store.social.identityRevision)) {
        guard !store.fixtureMode, store.connected, store.state.onboarded,
          scenePhase == .active, let destination = service.destination else { return }
        let owner = store.compositions.owner
        let identityRevision = store.social.identityRevision
        do {
          let data = try await store.social.sendData(endpoint: "push-devices", action: "resolve",
            payload: ["kind": destination.kind, "reference": destination.reference])
          let route = try JSONDecoder().decode(ResolvedPushRoute.self, from: data)
          try Task.checkCancellation()
          guard service.destination == destination, store.state.onboarded,
            store.compositions.owner == owner, store.social.identityRevision == identityRevision else { return }
          switch route.target {
          case .game(let gameID):
            store.tab = 4
            presentation = PushRoutePresentation(target: .game(gameID))
          case .room(let roomID):
            await store.refreshAfterMutation()
            try Task.checkCancellation()
            guard store.compositions.owner == owner, store.social.identityRevision == identityRevision,
              store.connected, store.connectionError == nil,
              store.state.conversations.contains(where: { $0.id == roomID }),
              store.canAccessConversation(roomID) else {
              throw SocialServiceError(error: "This conversation is no longer available.", code: "unavailable")
            }
            store.tab = 4
            presentation = PushRoutePresentation(target: .room(roomID))
          case .post(let postID):
            presentation = PushRoutePresentation(target: .post(postID))
          case nil:
            throw SocialServiceError(error: "This notification is no longer available.", code: "unavailable")
          }
          service.destination = nil
        } catch {
          guard !Task.isCancelled, service.destination == destination,
            store.compositions.owner == owner, store.social.identityRevision == identityRevision else { return }
          service.destination = nil
          store.notice = error.localizedDescription
        }
      }
      .task(id: LinkReadiness(link: store.pendingPostLink, ready: store.connected && store.state.onboarded && scenePhase == .active)) {
        guard let postID = store.pendingPostLink, store.connected, store.state.onboarded, scenePhase == .active else { return }
        store.pendingPostLink = nil
        presentation = PushRoutePresentation(target: .post(postID))
      }
      .sheet(item: $presentation) { route in
        NavigationStack {
          Group {
            switch route.target {
            case .room(let roomID): ChatView(id: roomID)
            case .post(let postID): LibraryPostDestination(id: postID)
            case .game(let gameID): OnlineGameView(sessionID: gameID)
            }
          }.toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Done") { presentation = nil }
            }
          }
        }
      }
      .onChange(of: store.state.onboarded) { _, onboarded in
        if !onboarded { presentation = nil; service.destination = nil }
      }
      .onChange(of: store.compositions.owner) { _, _ in presentation = nil; service.destination = nil }
  }
}

extension View {
  func routePushNotifications() -> some View { modifier(PushRouting()) }
}
