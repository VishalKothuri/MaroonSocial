import Foundation
import Observation

/// Owns only the short-lived pool credential, bound to the currently visible
/// account. An old create/close response cannot replace a newer account's table.
@Observable @MainActor final class WebPoolSessionStore {
  private(set) var session: WebPoolSession?
  private(set) var owner: String?
  var loading = true
  var error: String?
  private var generation = UUID()
  func connect(owner: String, currentOwner: @escaping @MainActor () -> String,
               create: @MainActor () async throws -> WebPoolSession,
               revoke: @escaping @MainActor (WebPoolSession) async -> Void) async {
    invalidate(revoke: revoke)
    let attempt = UUID(); generation = attempt; self.owner = owner; loading = true; error = nil
    do {
      let created = try await create()
      guard generation == attempt, owner == currentOwner(), !Task.isCancelled else { await revoke(created); return }
      session = created
    } catch {
      guard generation == attempt, owner == currentOwner(), !Task.isCancelled else { return }
      self.error = error.localizedDescription; loading = false
    }
  }
  func invalidate(revoke: @escaping @MainActor (WebPoolSession) async -> Void) {
    generation = UUID(); let old = session; session = nil; owner = nil; loading = false; error = nil
    if let old { Task { await revoke(old) } }
  }
  static func revoke(_ session: WebPoolSession) async {
    guard session.endpoint == "https://myxbghfbapbfffkpndwo.supabase.co/functions/v1/web-pool",
      let url = URL(string: session.endpoint) else { return }
    var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 12
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(session.token, forHTTPHeaderField: "X-Maroon-Pool-Session")
    request.httpBody = Data(#"{"action":"close"}"#.utf8)
    _ = try? await URLSession.shared.data(for: request)
  }
}
