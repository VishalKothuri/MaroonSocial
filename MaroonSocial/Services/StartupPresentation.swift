import Foundation

/// Presentation timing only; connection work and its errors stay in AppStore.
/// A fast connection finishes the first fill before the artwork settles away.
struct StartupPresentation {
  enum Phase: Equatable { case idle, loading, settling, complete }
  private(set) var phase: Phase = .idle
  private var appearedAt: TimeInterval = 0
  private var settleUntil: TimeInterval = 0
  var isPresented: Bool { phase == .loading || phase == .settling }
  var animating: Bool { phase == .idle || phase == .loading }

  mutating func begin(at now: TimeInterval) {
    guard !isPresented else { return }
    appearedAt = now; phase = .loading
  }
  mutating func restart(at now: TimeInterval) {
    cancel(); begin(at: now)
  }
  mutating func cancel() { phase = .complete }

  /// Called only once the real load is complete. Returns the next visual
  /// deadline, or nil when the content can be revealed immediately.
  mutating func advanceAfterLoad(at now: TimeInterval, reduceMotion: Bool) -> TimeInterval? {
    guard isPresented else { return nil }
    if reduceMotion { cancel(); return nil }
    if phase == .loading {
      let remaining = appearedAt + LoadingWordmarkTiming.minimumFill - now
      if remaining > 0 { return remaining }
      phase = .settling
      settleUntil = now + LoadingWordmarkTiming.settle
    }
    let remaining = settleUntil - now
    if remaining > 0 { return remaining }
    cancel(); return nil
  }
}
