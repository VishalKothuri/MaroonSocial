import Foundation

public struct TablePoint: Equatable, Sendable {
  public var x: Double
  public var y: Double
  public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
  public func distance(to other: Self) -> Double { hypot(x - other.x, y - other.y) }
}

/// A fixed-step equal-mass billiards simulation. Rendering never participates in the rules.
public struct PoolGame: Sendable {
  public struct Ball: Equatable, Identifiable, Sendable {
    public let id: Int
    public var position: TablePoint
    public var velocity: TablePoint = .init(0, 0)
    public var pocketed = false
    public init(id: Int, position: TablePoint) { self.id = id; self.position = position }
  }
  public enum Group: String, Sendable { case solids, stripes }
  public static let radius = 0.027
  public static let pockets: [TablePoint] = [.init(0.035, 0.035), .init(0.965, 0.035), .init(0.02, 1), .init(0.98, 1), .init(0.035, 1.965), .init(0.965, 1.965)]
  public private(set) var balls: [Ball] = []
  public private(set) var turn = 0
  public private(set) var groups: [Group?] = [nil, nil]
  public private(set) var winner: Int?
  public private(set) var moving = false
  public private(set) var ballInHand = false
  public private(set) var shots = 0
  public private(set) var status = "Player 1 breaks. Aim up the table and use a firm shot."
  private var firstContact: Int?
  private var shotPocketed: [Int] = []
  private var railAfterContact = false
  private var elapsedSteps = 0
  private var targetsAtStart: Set<Int> = []
  public init() {
    balls = [.init(id: 0, position: .init(0.5, 1.5))]
    // Eight in the middle; opposite groups at the rear corners.
    let rack = [1, 10, 2, 3, 8, 11, 12, 4, 13, 5, 6, 14, 7, 15, 9]
    var index = 0
    for row in 0..<5 {
      for col in 0...row {
        balls.append(.init(id: rack[index], position: .init(0.5 + Double(col) * 0.055 - Double(row) * 0.0275, 0.60 - Double(row) * 0.048)))
        index += 1
      }
    }
  }
  public var cue: Ball { balls.first { $0.id == 0 }! }
  public func remaining(for player: Int) -> Int {
    guard let group = groups[player] else { return 7 }
    return balls.filter { !$0.pocketed && Self.group(of: $0.id) == group }.count
  }
  public func targetDescription(for player: Int) -> String {
    guard let group = groups[player] else { return "Open table" }
    return remaining(for: player) == 0 ? "8 ball" : "\(remaining(for: player)) \(group.rawValue) left"
  }
  public static func group(of number: Int) -> Group? {
    (1...7).contains(number) ? .solids : (9...15).contains(number) ? .stripes : nil
  }
  public func validCuePosition(_ point: TablePoint) -> Bool {
    (0.07...0.93).contains(point.x) && (0.07...1.93).contains(point.y)
      && balls.filter { $0.id != 0 && !$0.pocketed }.allSatisfy { $0.position.distance(to: point) > Self.radius * 2.05 }
      && Self.pockets.allSatisfy { $0.distance(to: point) > 0.085 }
  }
  @discardableResult public mutating func placeCue(at point: TablePoint) -> Bool {
    guard ballInHand, !moving, winner == nil, validCuePosition(point), let index = balls.firstIndex(where: { $0.id == 0 }) else { return false }
    balls[index].position = point
    balls[index].pocketed = false
    return true
  }
  /// Degrees clockwise from the top of the table; power is normalized 0...1.
  @discardableResult public mutating func shoot(angle: Double, power: Double) -> Bool {
    guard !moving, winner == nil, power.isFinite, angle.isFinite, power > 0 else { return false }
    let rad = angle * .pi / 180
    firstContact = nil; shotPocketed = []; railAfterContact = false; elapsedSteps = 0
    if let group = groups[turn] {
      targetsAtStart = Set(balls.filter { !$0.pocketed && Self.group(of: $0.id) == group }.map(\.id))
      if targetsAtStart.isEmpty { targetsAtStart = [8] }
    } else { targetsAtStart = Set((1...15).filter { $0 != 8 }) }
    let speed = 0.6 + min(1, power) * 3.7
    balls[0].velocity = .init(sin(rad) * speed, -cos(rad) * speed)
    balls[0].pocketed = false
    shots += 1; moving = true; ballInHand = false
    status = "Shot in motion…"
    return true
  }
  public mutating func advance(steps: Int = 1) {
    guard moving else { return }
    for _ in 0..<max(0, steps) {
      guard moving else { break }
      step()
    }
  }
  private mutating func step() {
    let dt = 1.0 / 120.0
    elapsedSteps += 1
    for i in balls.indices where !balls[i].pocketed {
      balls[i].position.x += balls[i].velocity.x * dt
      balls[i].position.y += balls[i].velocity.y * dt
      // Rolling resistance is speed independent, producing a definite resting state.
      let speed = hypot(balls[i].velocity.x, balls[i].velocity.y)
      let factor = speed > 0 ? max(0, speed - 0.42 * dt) / speed : 0
      balls[i].velocity.x *= factor; balls[i].velocity.y *= factor
      if Self.pockets.contains(where: { $0.distance(to: balls[i].position) < 0.060 }) {
        balls[i].pocketed = true; balls[i].velocity = .init(0, 0)
        shotPocketed.append(balls[i].id)
        continue
      }
      let r = Self.radius
      if balls[i].position.x < r || balls[i].position.x > 1 - r {
        balls[i].position.x = min(1 - r, max(r, balls[i].position.x))
        balls[i].velocity.x *= -0.88
        if firstContact != nil { railAfterContact = true }
      }
      if balls[i].position.y < r || balls[i].position.y > 2 - r {
        balls[i].position.y = min(2 - r, max(r, balls[i].position.y))
        balls[i].velocity.y *= -0.88
        if firstContact != nil { railAfterContact = true }
      }
    }
    for i in balls.indices where !balls[i].pocketed {
      for j in balls.indices where j > i && !balls[j].pocketed {
        let dx = balls[j].position.x - balls[i].position.x
        let dy = balls[j].position.y - balls[i].position.y
        let distance = hypot(dx, dy)
        guard distance < Self.radius * 2, distance > 0.00001 else { continue }
        let nx = dx / distance, ny = dy / distance
        let relative = (balls[i].velocity.x - balls[j].velocity.x) * nx + (balls[i].velocity.y - balls[j].velocity.y) * ny
        if relative > 0 {
          if firstContact == nil && (balls[i].id == 0 || balls[j].id == 0) {
            firstContact = balls[i].id == 0 ? balls[j].id : balls[i].id
          }
          let impulse = relative * 0.97
          balls[i].velocity.x -= impulse * nx; balls[i].velocity.y -= impulse * ny
          balls[j].velocity.x += impulse * nx; balls[j].velocity.y += impulse * ny
        }
        let separation = (Self.radius * 2 - distance + 0.00001) / 2
        balls[i].position.x -= separation * nx; balls[i].position.y -= separation * ny
        balls[j].position.x += separation * nx; balls[j].position.y += separation * ny
      }
    }
    if elapsedSteps >= 1800 || balls.allSatisfy({ $0.pocketed || hypot($0.velocity.x, $0.velocity.y) < 0.008 }) {
      for i in balls.indices { balls[i].velocity = .init(0, 0) }
      resolveShot()
    }
  }
  // Internal so rule fixtures can cover unusual match endings independently of physics.
  mutating func resolveShot(first: Int?, pocketed: [Int], rail: Bool, legalTargets: Set<Int>) {
    firstContact = first; shotPocketed = pocketed; railAfterContact = rail; targetsAtStart = legalTargets
    for i in balls.indices where pocketed.contains(balls[i].id) { balls[i].pocketed = true }
    resolveShot()
  }
  private mutating func resolveShot() {
    moving = false
    let scratch = shotPocketed.contains(0)
    let wrongFirst = firstContact.map { !targetsAtStart.contains($0) } ?? true
    let noRail = !railAfterContact && shotPocketed.isEmpty
    let foul = scratch || wrongFirst || noRail
    if shotPocketed.contains(8) {
      if shots == 1 {
        spotEight()
      } else {
        winner = !foul && targetsAtStart == [8] ? turn : 1 - turn
        status = winner == turn ? "Player \(turn + 1) wins! The 8 ball is home." : "Player \(1 - turn + 1) wins · \(scratch ? "scratch on the 8" : "8 ball pocketed early or illegally")."
        return
      }
    }
    if groups[turn] == nil, !foul, let first = shotPocketed.first(where: { Self.group(of: $0) != nil }), let group = Self.group(of: first) {
      groups[turn] = group; groups[1 - turn] = group == .solids ? .stripes : .solids
    }
    let ownPocket = shotPocketed.contains { Self.group(of: $0) != nil && Self.group(of: $0) == groups[turn] }
    if foul {
      turn = 1 - turn; ballInHand = true
      resetCue()
      let reason = scratch ? "Scratch" : wrongFirst ? (firstContact == nil ? "No ball contacted" : "Wrong ball hit first") : "No ball reached a rail"
      status = "\(reason). Player \(turn + 1) has ball in hand."
    } else if ownPocket {
      status = "Ball pocketed! Player \(turn + 1) shoots again."
    } else {
      turn = 1 - turn
      status = "Player \(turn + 1) to shoot · \(targetDescription(for: turn))."
    }
  }
  private mutating func resetCue() {
    balls[0].pocketed = false; balls[0].velocity = .init(0, 0)
    if validCuePosition(balls[0].position) { return }
    for y in stride(from: 1.5, through: 0.1, by: -0.08) {
      for x in stride(from: 0.5, through: 0.9, by: 0.08) {
        let p = TablePoint(x, y)
        if validCuePosition(p) { balls[0].position = p; return }
      }
    }
  }
  private mutating func spotEight() {
    guard let i = balls.firstIndex(where: { $0.id == 8 }) else { return }
    balls[i].pocketed = true
    for y in stride(from: 0.6, through: 1.85, by: 0.06) {
      let p = TablePoint(0.5, y)
      if balls.filter({ !$0.pocketed }).allSatisfy({ $0.position.distance(to: p) > Self.radius * 2.1 }) {
        balls[i].position = p; balls[i].pocketed = false; return
      }
    }
  }
}

public struct CupPongGame: Sendable {
  public struct Cup: Identifiable, Equatable, Sendable {
    public let id: Int
    public let position: TablePoint
  }
  public static let rack: [Cup] = [
    .init(id: 0, position: .init(0.5, 0.83)),
    .init(id: 1, position: .init(0.395, 0.63)), .init(id: 2, position: .init(0.605, 0.63)),
    .init(id: 3, position: .init(0.29, 0.43)), .init(id: 4, position: .init(0.5, 0.43)), .init(id: 5, position: .init(0.71, 0.43)),
  ]
  public private(set) var removed: [Set<Int>] = [[], []]
  public private(set) var turn = 0
  public private(set) var winner: Int?
  public private(set) var shots = 0
  public private(set) var status = "Player 1 · clear six cups to win."
  public init() {}
  public var targets: [Cup] { Self.rack.filter { !removed[turn].contains($0.id) } }
  public static func landing(aim: Double, power: Double) -> TablePoint {
    .init(0.5 + max(-1, min(1, aim)) * 0.38, 1.65 - max(0, min(1, power)) * 1.55)
  }
  public static func idealPower(for cup: Cup) -> Double { (1.65 - cup.position.y) / 1.55 }
  @discardableResult public mutating func shoot(aim: Double, power: Double) -> Int? {
    guard winner == nil, aim.isFinite, power.isFinite else { return nil }
    shots += 1
    let end = Self.landing(aim: aim, power: power)
    let hit = targets.first { $0.position.distance(to: end) < 0.073 }
    let player = turn
    if let hit { removed[player].insert(hit.id) }
    if removed[player].count == 6 {
      winner = player
      status = "Player \(player + 1) wins! Six cups cleared."
    } else {
      turn = 1 - turn
      status = hit == nil ? "Missed. Player \(turn + 1), your throw." : "Cup sunk! Player \(turn + 1), your throw."
    }
    return hit?.id
  }
}
