import Foundation

/// SwiftUI keeps a destination's state while another destination is pushed.
/// A lease is released when that navigation state is removed, rather than on
/// onDisappear (which also runs when opening a post or another tag).
@MainActor final class TaggedPostLease {
  let id: UUID
  let query: SocialTagQuery
  private let release: @MainActor @Sendable (UUID) -> Void
  init(id: UUID, query: SocialTagQuery, release: @escaping @MainActor @Sendable (UUID) -> Void) {
    self.id = id; self.query = query; self.release = release
  }
  deinit {
    let id = id; let release = release
    Task { @MainActor in release(id) }
  }
}
