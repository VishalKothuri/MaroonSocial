import Foundation

/// The original caller owns the network operation. Pulls can join it without
/// starting another request; canceling a waiter never cancels that owner.
@MainActor final class RefreshWork {
  private var active = false
  private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]
  var waitingCount: Int { waiters.count }
  /// A mutation must read a snapshot started after it completed. Joining a
  /// refresh already in flight could otherwise return pre-mutation content.
  func runAfterCurrent(operation: @MainActor () async -> Void) async {
    while active {
      await waitForCurrent()
      guard !Task.isCancelled else { return }
    }
    guard !Task.isCancelled else { return }
    await run(joinExisting: false, operation: operation)
  }
  func run(joinExisting: Bool, operation: @MainActor () async -> Void) async {
    if active {
      if joinExisting { await waitForCurrent() }
      return
    }
    active = true
    defer {
      active = false
      let pending = waiters.values; waiters.removeAll()
      pending.forEach { $0.resume() }
    }
    await operation()
  }
  private func waitForCurrent() async {
    let id = UUID()
    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        if Task.isCancelled || !active { continuation.resume() }
        else { waiters[id] = continuation }
      }
    } onCancel: {
      Task { @MainActor [weak self] in self?.waiters.removeValue(forKey: id)?.resume() }
    }
  }
}

struct RefreshPresentation: Equatable {
  static let logoSize: CGFloat = 25
  static let logoHeight: CGFloat = 56 * logoSize / 43
  static let logoWidth: CGFloat = 320 * logoSize / 43
  static let idle = RefreshPresentation(pullDistance: 0, refreshing: false, dragging: false)
  let pullDistance: CGFloat
  let refreshing: Bool
  let dragging: Bool
  var progress: CGFloat { refreshing ? 1 : min(1, max(0, pullDistance / Self.logoHeight)) }
  var headerTranslation: CGFloat { progress * Self.logoHeight }
}
