import SwiftUI

/// The previous random guest flow has been replaced by explicit interest requests.
struct RandomChatView: View {
  @Environment(AppStore.self) private var store
  var body: some View { DiscoveryView(social: store.social) }
}
