import Foundation

struct TagResults: Decodable, Equatable {
  let durationSeconds: Int
  let totalCatches: Int
  let players: [TagResultPlayer]
}
struct TagResultPlayer: Decodable, Identifiable, Equatable {
  let id: String
  let username: String
  let role: String
  let caught: Bool
  let left: Bool
  let catches: Int
  let survivedSeconds: Int?
  var summary: String {
    if role == "seeker" { return "\(catches) confirmed \(catches == 1 ? "catch" : "catches")" }
    let seconds = max(0, survivedSeconds ?? 0)
    return "\(left ? "Left after" : caught ? "Caught after" : "Survived") \(seconds / 60)m \(seconds % 60)s"
  }
}
