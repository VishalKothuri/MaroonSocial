import XCTest
@testable import MaroonCore

final class GameTests: XCTestCase {
  func testPoolBreakIsDeterministicAndSettles() {
    var a = PoolGame(), b = PoolGame()
    XCTAssertTrue(a.shoot(angle: 0, power: 1))
    XCTAssertTrue(b.shoot(angle: 0, power: 1))
    XCTAssertFalse(a.shoot(angle: 40, power: 1))
    a.advance(steps: 2000); b.advance(steps: 2000)
    XCTAssertFalse(a.moving)
    XCTAssertEqual(a.balls, b.balls)
    XCTAssertEqual(a.shots, 1)
    XCTAssertTrue(a.balls.allSatisfy { $0.position.x.isFinite && $0.position.y.isFinite })
    XCTAssertTrue(a.balls.contains { $0.id != 0 && ($0.pocketed || $0.position.y > 0.65) })
  }
  func testPoolRepeatedShotsNeverStallOrProduceInvalidPositions() {
    var game = PoolGame()
    for shot in 0..<40 {
      if game.winner != nil { game = PoolGame() }
      XCTAssertTrue(game.shoot(angle: Double((shot * 137) % 360 - 180), power: 0.25 + Double(shot % 4) * 0.25))
      game.advance(steps: 2000)
      XCTAssertFalse(game.moving)
      XCTAssertFalse(game.cue.pocketed)
      for ball in game.balls where !ball.pocketed {
        XCTAssertTrue((-0.03...1.03).contains(ball.position.x))
        XCTAssertTrue((-0.03...2.03).contains(ball.position.y))
      }
    }
  }
  func testPoolGroupAssignmentAndRetainedTurn() {
    var game = PoolGame()
    game.resolveShot(first: 3, pocketed: [3], rail: false, legalTargets: Set(1...7))
    XCTAssertEqual(game.groups[0], .solids)
    XCTAssertEqual(game.groups[1], .stripes)
    XCTAssertEqual(game.turn, 0)
    XCTAssertEqual(game.remaining(for: 0), 6)
    game.resolveShot(first: 2, pocketed: [], rail: true, legalTargets: Set(1...7))
    XCTAssertEqual(game.turn, 1)
    XCTAssertFalse(game.ballInHand)
  }
  func testPoolScratchAndPlacementRejectsOverlap() {
    var game = PoolGame()
    game.resolveShot(first: 1, pocketed: [0, 1], rail: true, legalTargets: Set(1...7))
    XCTAssertTrue(game.ballInHand)
    XCTAssertEqual(game.turn, 1)
    XCTAssertNil(game.groups[0], "A foul must not assign groups")
    let object = game.balls.first { $0.id == 8 }!
    XCTAssertFalse(game.placeCue(at: object.position))
    XCTAssertFalse(game.placeCue(at: .init(-1, 2)))
    XCTAssertTrue(game.placeCue(at: .init(0.25, 1.6)))
    XCTAssertEqual(game.cue.position, .init(0.25, 1.6))
    XCTAssertFalse(game.cue.pocketed)
  }
  func testPoolNoRailAndWrongFirstAreFouls() {
    var game = PoolGame()
    game.resolveShot(first: 2, pocketed: [], rail: false, legalTargets: Set(1...7))
    XCTAssertEqual(game.turn, 1)
    XCTAssertTrue(game.ballInHand)
    game.resolveShot(first: 9, pocketed: [2], rail: true, legalTargets: Set(1...7))
    XCTAssertEqual(game.turn, 0)
    XCTAssertTrue(game.ballInHand)
  }
  func testPoolEarlyEightLosesAndLegalEightWins() {
    var early = PoolGame()
    early.resolveShot(first: 8, pocketed: [8], rail: true, legalTargets: Set(1...7))
    XCTAssertEqual(early.winner, 1)
    XCTAssertFalse(early.shoot(angle: 0, power: 1))
    var legal = PoolGame()
    legal.resolveShot(first: 1, pocketed: Array(1...7), rail: true, legalTargets: Set(1...7))
    XCTAssertEqual(legal.targetDescription(for: 0), "8 ball")
    legal.resolveShot(first: 8, pocketed: [8], rail: false, legalTargets: [8])
    XCTAssertEqual(legal.winner, 0)
    var scratch = PoolGame()
    scratch.resolveShot(first: 8, pocketed: [8, 0], rail: true, legalTargets: [8])
    XCTAssertEqual(scratch.winner, 1)
  }
  func testPoolEightOnBreakIsSpotted() {
    var game = PoolGame()
    _ = game.shoot(angle: 0, power: 1)
    game.resolveShot(first: 1, pocketed: [8], rail: true, legalTargets: Set(1...7))
    XCTAssertNil(game.winner)
    XCTAssertFalse(game.balls.first { $0.id == 8 }!.pocketed)
  }
  func testCupPongAlternatesAndHasSeparateRacks() {
    var game = CupPongGame()
    let cup = CupPongGame.rack[0]
    XCTAssertEqual(game.shoot(aim: 0, power: CupPongGame.idealPower(for: cup)), 0)
    XCTAssertEqual(game.turn, 1)
    XCTAssertEqual(game.removed[0], [0])
    XCTAssertTrue(game.removed[1].isEmpty)
    XCTAssertEqual(game.shoot(aim: 0, power: CupPongGame.idealPower(for: cup)), 0)
    XCTAssertEqual(game.turn, 0)
    XCTAssertNil(game.shoot(aim: 0, power: CupPongGame.idealPower(for: cup)), "An empty cup cannot score again")
    XCTAssertEqual(game.removed[0].count, 1)
  }
  func testCupPongCompleteMatchAndReset() {
    var game = CupPongGame()
    for cup in CupPongGame.rack {
      let aim = (cup.position.x - 0.5) / 0.38
      XCTAssertEqual(game.shoot(aim: aim, power: CupPongGame.idealPower(for: cup)), cup.id)
      if game.winner == nil { XCTAssertNil(game.shoot(aim: 1, power: 0)) }
    }
    XCTAssertEqual(game.winner, 0)
    XCTAssertEqual(game.shots, 11)
    XCTAssertNil(game.shoot(aim: 0, power: 0.5))
    XCTAssertEqual(game.shots, 11)
    game = CupPongGame()
    XCTAssertEqual(game.shots, 0)
    XCTAssertNil(game.winner)
  }
  func testThreefoldAndInsufficientMaterial() {
    var game = ChessGame()
    for _ in 0..<2 {
      XCTAssertTrue(game.move(from: 6, to: 21))
      XCTAssertTrue(game.move(from: 62, to: 45))
      XCTAssertTrue(game.move(from: 21, to: 6))
      XCTAssertTrue(game.move(from: 45, to: 62))
    }
    XCTAssertEqual(game.status, "Draw · threefold repetition")
    XCTAssertTrue(game.finished)
    let bare = ChessGame(board: [4: .init(.white, .king), 60: .init(.black, .king)], turn: .white)
    XCTAssertEqual(bare.status, "Draw · insufficient material")
    XCTAssertTrue(bare.finished)
  }
  func testUnavailableEnPassantDoesNotDelayRepetitionDraw() {
    var game = ChessGame()
    XCTAssertTrue(game.move(from: 8, to: 24))
    // The a-pawn cannot be captured en passant, so this is the same position after each knight cycle.
    for _ in 0..<2 {
      XCTAssertTrue(game.move(from: 62, to: 45))
      XCTAssertTrue(game.move(from: 6, to: 21))
      XCTAssertTrue(game.move(from: 45, to: 62))
      XCTAssertTrue(game.move(from: 21, to: 6))
    }
    XCTAssertEqual(game.status, "Draw · threefold repetition")
  }
  func testChessComputerChoosesLegalMoveAndFindsMate() {
    var game = ChessGame()
    _ = game.move(from: 13, to: 21)
    _ = game.move(from: 52, to: 36)
    _ = game.move(from: 14, to: 30)
    let move = game.suggestedMove()
    XCTAssertNotNil(move)
    XCTAssertTrue(game.move(from: move!.from, to: move!.to))
    XCTAssertEqual(game.status, "Checkmate · Black wins")
  }
}
