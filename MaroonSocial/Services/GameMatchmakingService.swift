import Foundation
import Observation

struct GameQueueResponse: Decodable {
  struct Queue: Decodable { let status: String }
  let queue: Queue?
  let game: OnlineGame?
}

@Observable @MainActor final class GameMatchmakingService {
  typealias Transport = @MainActor (String, [String: Any]) async throws -> Data
  let kind: String
  private let transport: Transport?
  private(set) var searching = false
  private(set) var busy = false
  private(set) var game: OnlineGame?
  private(set) var error: String?
  private var nonce: String?
  private var generation = 0
  init(kind: String, transport: Transport? = nil) { self.kind = kind; self.transport = transport }
  func find(using social: SocialService) async {
    guard !busy, !searching else { return }
    // An interrupted response does not prove the join failed. Retry the same
    // server operation until it reports a terminal state or the user cancels.
    let id = nonce ?? UUID().uuidString; nonce = id
    generation += 1
    let epoch = generation
    game = nil; error = nil; busy = true
    defer { busy = false }
    do {
      let value = try await request("match.join", nonce: id, social: social)
      guard nonce == id, generation == epoch else { return }
      apply(value)
    } catch { if nonce == id, generation == epoch { self.error = error.localizedDescription; searching = false } }
  }
  func poll(using social: SocialService) async {
    guard searching, !busy, let id = nonce else { return }
    busy = true; defer { busy = false }
    do {
      let value = try await request("match.status", nonce: id, social: social)
      guard nonce == id, searching else { return }
      error = nil; apply(value)
    } catch { if nonce == id { self.error = error.localizedDescription } }
  }
  func cancel(using social: SocialService) async {
    guard let id = nonce else { return }
    generation += 1
    let epoch = generation
    nonce = nil; searching = false
    do {
      let value = try await request("match.cancel", nonce: id, social: social)
      // A simultaneous match remains recoverable in My matches; never reopen a
      // dismissed lobby from a late cancellation response.
      if generation == epoch, value.game != nil { error = "A player matched just before you cancelled. The game is in My matches." }
    } catch { if generation == epoch { self.error = "Search stopped on this phone. The queue will expire shortly." } }
  }
  func clearMatch() { generation += 1; game = nil; nonce = nil; searching = false }
  private func apply(_ response: GameQueueResponse) {
    game = response.game; searching = response.queue?.status == "waiting"
    if game == nil && !searching {
      nonce = nil
      error = "Your search expired. Find a player to try again."
    }
  }
  private func request(_ action: String, nonce: String, social: SocialService) async throws -> GameQueueResponse {
    let payload: [String: Any] = ["kind": kind, "nonce": nonce]
    let data: Data
    if let transport { data = try await transport(action, payload) }
    else { data = try await social.sendData(endpoint: "games", action: action, payload: payload) }
    return try JSONDecoder().decode(GameQueueResponse.self, from: data)
  }
}
