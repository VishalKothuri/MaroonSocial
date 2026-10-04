import Foundation

/// Direction hysteresis ignores keyboard/layout changes and programmatic scrolling.
struct FeedChromeState {
  private(set) var collapsed = false
  private var previousOffset: Double?
  private var previousViewport: Double?
  private var travel = 0.0
  private var settlingUntil = 0.0
  mutating func reset() { collapsed = false; previousOffset = nil; previousViewport = nil; travel = 0; settlingUntil = 0 }
  mutating func observe(offset: Double, viewport: Double, interacting: Bool, locked: Bool, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    defer { previousOffset = offset; previousViewport = viewport }
    if locked || offset <= 8 { collapsed = false; travel = 0; settlingUntil = 0; return }
    // Hiding bars resizes the lazy feed. Its offset corrections can arrive
    // after the viewport update and resemble a reverse drag in that same frame.
    // Keep recording the baseline while this short transition settles.
    guard now >= settlingUntil else { travel = 0; return }
    guard interacting, let previousOffset, let previousViewport, abs(viewport - previousViewport) < 1 else { travel = 0; return }
    // A fast drag or a busy layout pass can deliver a large genuine movement.
    // Phase + viewport checks already exclude programmatic/layout changes.
    let delta = max(-80, min(80, offset - previousOffset))
    if delta * travel < 0 { travel = 0 }
    travel += delta
    if !collapsed && offset > 60 && travel > 32 { collapsed = true; travel = 0; settlingUntil = now + 0.4 }
    else if collapsed && travel < -20 { collapsed = false; travel = 0; settlingUntil = now + 0.4 }
  }
}
