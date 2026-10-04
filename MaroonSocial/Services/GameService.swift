import Foundation
import Observation

enum GameJSON: Codable {
  case object([String: GameJSON]), array([GameJSON]), string(String), number(Double), bool(Bool), null
  init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() { self = .null }
    else if let v = try? c.decode(Bool.self) { self = .bool(v) }
    else if let v = try? c.decode(Double.self) { self = .number(v) }
    else if let v = try? c.decode(String.self) { self = .string(v) }
    else if let v = try? c.decode([String: GameJSON].self) { self = .object(v) }
    else { self = .array(try c.decode([GameJSON].self)) }
  }
  func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self { case .object(let v): try c.encode(v); case .array(let v): try c.encode(v); case .string(let v): try c.encode(v); case .number(let v): try c.encode(v); case .bool(let v): try c.encode(v); case .null: try c.encodeNil() }
  }
  var value: Any {
    switch self { case .object(let v): return v.mapValues(\.value); case .array(let v): return v.map(\.value); case .string(let v): return v; case .number(let v): return v; case .bool(let v): return v; case .null: return NSNull() }
  }
  subscript(key: String) -> GameJSON? { if case .object(let v) = self { return v[key] }; return nil }
  var int: Int? { if case .number(let v) = self { return Int(v) }; return nil }
  var text: String? { if case .string(let v) = self { return v }; return nil }
}
struct OnlineGame: Decodable, Identifiable {
  let id, roomID, kind, rules, status: String
  let version, yourSeat: Int
  let players: [String]
  let state: GameJSON
  let replay: GameJSON?
  let updatedAt, expiresAt: Double
  var usesHostedPool: Bool { rules == "maroon-web-pool-3.0.0" }
  var title: String { Self.title(kind) }
  static func title(_ kind: String) -> String { kind == "pool" ? "8 Ball" : kind == "pong" ? "Cup Pong" : "Chess" }
  var canAccept: Bool { status == "pending" && yourSeat == 1 }
  var yourTurn: Bool { status == "active" && state["turn"]?.int == yourSeat }
  var opponent: String { players.indices.contains(1 - yourSeat) ? players[1 - yourSeat] : "Player" }
  var detail: String {
    if status == "pending" { return canAccept ? "Your invitation is waiting" : "Waiting for \(opponent) to accept" }
    if status == "active" { return yourTurn ? "Your turn" : "\(opponent)’s turn" }
    if status == "finished" { return state["status"]?.text ?? "Match finished" }
    return status.capitalized
  }
  var configuration: [String: Any] {
    var result: [String: Any] = ["kind": kind, "online": true, "yourSeat": yourSeat, "players": players, "version": version, "state": state.value, "interactive": status == "active"]
    if let replay { result["replay"] = replay.value }
    return result
  }
}
struct GameInvitationInfo: Decodable {
  let id, kind, status: String
  let players: [String]
  let canOpen: Bool
}
struct GameResponse: Decodable { var game: OnlineGame?; var games: [OnlineGame]?; var invitation: GameInvitationInfo? }

/// A room-scoped identity is required; cached legacy usernames must never be
/// reused as an account lookup when a group moves to private aliases.
enum GroupGameOpponents {
  static func eligible(_ members: [SocialGroupMember]) -> [SocialGroupMember] {
    var seen = Set<UUID>()
    return members.filter { member in
      guard member.status == "accepted", member.isMe == false,
        let key = member.memberKey, let id = UUID(uuidString: key) else { return false }
      return seen.insert(id).inserted
    }.sorted { $0.username.localizedStandardCompare($1.username) == .orderedAscending }
  }
}

@Observable @MainActor final class GameService {
  var game: OnlineGame?
  var games: [OnlineGame] = []
  var busy = false
  var error: String?
  private var endpoints: [String: String] = [:]
  private var retry: (version: Int, input: Data, nonce: String)?
  func fetch(_ id: String, using social: SocialService) async {
    do { let result = try await resolve("get", id: id, social); if let value = result.game, game?.id != value.id || value.version >= (game?.version ?? -1) { game = value }; if !busy { self.error = nil } }
    catch { self.error = error.localizedDescription }
  }
  func list(using social: SocialService) async {
    do {
      async let previous = request("list", [:], social)
      async let hosted = request("list", [:], social, endpoint: "web-pool")
      let (old, new) = try await (previous, hosted)
      games = ((old.games ?? []) + (new.games ?? [])).sorted { $0.updatedAt > $1.updatedAt }
      for item in games { endpoints[item.id] = item.usesHostedPool ? "web-pool" : "games" }
      error = nil
    }
    catch { self.error = error.localizedDescription }
  }
  func act(_ action: String, using social: SocialService) async {
    guard let game, !busy else { return }; busy = true; error = nil
    defer { busy = false }
    do { self.game = try await request(action, ["id": game.id], social, endpoint: game.usesHostedPool ? "web-pool" : "games").game }
    catch { let message = error.localizedDescription; await fetch(game.id, using: social); self.error = message }
  }
  func turn(_ input: [String: Any], using social: SocialService) async {
    guard let game, game.yourTurn, !busy else { return }; busy = true; error = nil
    defer { busy = false }
    do {
      let encoded = try JSONSerialization.data(withJSONObject: input, options: .sortedKeys)
      let nonce = retry.flatMap { $0.version == game.version && $0.input == encoded ? $0.nonce : nil } ?? UUID().uuidString
      retry = (game.version, encoded, nonce)
      self.game = try await request("turn", ["id": game.id, "version": game.version, "nonce": nonce, "input": input], social).game
      retry = nil
    } catch { let message = error.localizedDescription; await fetch(game.id, using: social); self.error = message }
  }
  func invite(room: String, kind: String, nonce: String, opponentMemberKey: String? = nil, using social: SocialService) async throws -> OnlineGame {
    var payload: [String: Any] = ["room": room, "kind": kind, "nonce": nonce]
    if let opponentMemberKey {
      guard UUID(uuidString: opponentMemberKey) != nil else {
        throw SocialServiceError(error: "Choose a current group member to invite.", code: "invalid")
      }
      payload["opponent_member_key"] = opponentMemberKey
    }
    guard let game = try await request("invite", payload, social, endpoint: kind == "pool" ? "web-pool" : "games").game else { throw URLError(.badServerResponse) }
    endpoints[game.id] = game.usesHostedPool ? "web-pool" : "games"
    return game
  }
  func invitation(_ id: String, using social: SocialService) async throws -> GameInvitationInfo {
    guard let value = try await resolve("card", id: id, social).invitation else { throw URLError(.badServerResponse) }
    return value
  }
  private func resolve(_ action: String, id: String, _ social: SocialService) async throws -> GameResponse {
    if let endpoint = endpoints[id] { return try await request(action, ["id": id], social, endpoint: endpoint) }
    do {
      let value = try await request(action, ["id": id], social, endpoint: "web-pool")
      endpoints[id] = "web-pool"; return value
    } catch let error as SocialServiceError where error.code == "not_found" {
      let value = try await request(action, ["id": id], social)
      endpoints[id] = "games"; return value
    }
  }
  private func request(_ action: String, _ payload: [String: Any], _ social: SocialService, endpoint: String = "games") async throws -> GameResponse {
    let data = try await social.sendData(endpoint: endpoint, action: action, payload: payload)
    return try JSONDecoder().decode(GameResponse.self, from: data)
  }
}
