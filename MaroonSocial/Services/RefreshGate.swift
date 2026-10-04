import Foundation
import Observation

/// Manual refresh admission is shared across screens that read the same data.
/// A ticket keeps a late completion from releasing a newer request.
@Observable @MainActor final class RefreshGate {
  static let shared = RefreshGate()
  enum Decision: Equatable { case admitted(UUID), inFlight, cooldown(Int) }
  private struct Entry { let started: TimeInterval; var ticket: UUID? }
  private var entries: [String: Entry] = [:]
  private let interval: TimeInterval
  private let clock: () -> TimeInterval
  init(interval: TimeInterval = 10, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
    self.interval = max(10, interval); self.clock = clock
  }
  func isBlocked(scope: String) -> Bool {
    guard let entry = entries[scope] else { return false }
    return entry.ticket != nil || clock() < entry.started + interval
  }
  func deadline(scope: String) -> TimeInterval? { entries[scope].map { $0.started + interval } }
  func remaining(scope: String) -> TimeInterval {
    max(0, (deadline(scope: scope) ?? clock()) - clock())
  }
  func expire(scope: String) {
    guard let entry = entries[scope], entry.ticket == nil, clock() >= entry.started + interval else { return }
    entries.removeValue(forKey: scope)
  }
  func begin(scope: String) -> Decision {
    let now = clock()
    entries = entries.filter { $0.value.ticket != nil || now - $0.value.started < interval }
    if let entry = entries[scope] {
      if entry.ticket != nil { return .inFlight }
      let remaining = Int(ceil(max(0, interval - (now - entry.started))))
      if remaining > 0 { return .cooldown(remaining) }
    }
    let ticket = UUID(); entries[scope] = Entry(started: now, ticket: ticket)
    return .admitted(ticket)
  }
  func finish(scope: String, ticket: UUID) {
    guard entries[scope]?.ticket == ticket else { return }
    entries[scope]?.ticket = nil
    expire(scope: scope)
  }
}
