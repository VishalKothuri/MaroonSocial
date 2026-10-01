import XCTest

@testable import MaroonCore

final class CoreTests: XCTestCase {
  func testDomainDoesNotAcceptLookalikes() {
    XCTAssertTrue(Eligibility.allows("Aggie@tamu.edu"))
    for email in [
      "a@tamu.edu.attacker.com", "a@not-tamu.edu", "a@dept.tamu.edu", "@tamu.edu", "a@@tamu.edu",
      "a b@tamu.edu",
    ] { XCTAssertFalse(Eligibility.allows(email), email) }
  }
  func testSingleAttachmentAndLimits() throws {
    let image = MediaAttachment(kind: .image, data: Data([1]))
    let gif = MediaAttachment(kind: .gif, data: Data([2]))
    XCTAssertNoThrow(try MessageValidation.validate(text: "", media: [gif]))
    XCTAssertThrowsError(try MessageValidation.validate(text: "hello", media: [image, gif]))
    XCTAssertThrowsError(try MessageValidation.validate(text: "  ", media: []))
    XCTAssertThrowsError(
      try MessageValidation.validate(
        text: "photo", media: [MediaAttachment(kind: .image, data: Data(count: 5_000_001))]))
  }
  func testVoteSwitchDoesNotInflateScore() {
    var post = Post(author: "demo", text: "Howdy", score: 10)
    post.setVote(1)
    XCTAssertEqual(post.score, 11)
    post.setVote(-1)
    XCTAssertEqual(post.score, 9)
    post.setVote(-1)
    XCTAssertEqual(post.score, 10)
  }
  func testActivityCapacityAndDuplicateJoin() throws {
    var a = Activity(
      title: "Study", kind: .study, host: "host", place: "Library",
      starts: .now.addingTimeInterval(3600), capacity: 2, details: "")
    try a.join("guest")
    try a.join("guest")
    XCTAssertEqual(a.participants.count, 2)
    XCTAssertThrowsError(try a.join("third"))
  }
  func testSportsWindowExcludesAllDayAndCancelledEvents() {
    let now = Date.now
    var e = CampusEvent(
      id: "1", title: "Game", category: "Sports", starts: now.addingTimeInterval(1800),
      url: "https://calendar.tamu.edu", source: "calendar")
    XCTAssertTrue(e.canOpenSportsChat(at: now))
    XCTAssertFalse(e.canOpenSportsChat(at: now.addingTimeInterval(-1)))
    e.allDay = true
    XCTAssertFalse(e.canOpenSportsChat(at: now))
    e.allDay = false
    e.cancelled = true
    XCTAssertFalse(e.canOpenSportsChat(at: now))
  }
  func testChessOpeningAndIllegalMoves() {
    var game = ChessGame()
    XCTAssertEqual(game.legalMoves().count, 20)
    XCTAssertFalse(game.move(from: 4, to: 20))
    XCTAssertTrue(game.move(from: 12, to: 28))
    XCTAssertEqual(game.turn, .black)
    XCTAssertFalse(game.move(from: 11, to: 27))
  }
  func testFoolsMate() {
    var g = ChessGame()
    XCTAssertTrue(g.move(from: 13, to: 21))
    XCTAssertTrue(g.move(from: 52, to: 36))
    XCTAssertTrue(g.move(from: 14, to: 30))
    XCTAssertTrue(g.move(from: 59, to: 31))
    XCTAssertTrue(g.finished)
    XCTAssertEqual(g.status, "Checkmate · Black wins")
  }
  func testCastlingAndCheckRestrictions() {
    var g = ChessGame(
      board: [4: .init(.white, .king), 7: .init(.white, .rook), 60: .init(.black, .king)],
      turn: .white)
    XCTAssertTrue(g.move(from: 4, to: 6))
    XCTAssertEqual(g.board[5], .init(.white, .rook))
    XCTAssertNil(g.board[7])
    let blocked = ChessGame(
      board: [
        4: .init(.white, .king), 7: .init(.white, .rook), 60: .init(.black, .king),
        61: .init(.black, .rook),
      ], turn: .white)
    XCTAssertFalse(blocked.legalMoves(from: 4).contains { $0.1 == 6 })
  }
  func testEnPassant() {
    var g = ChessGame()
    XCTAssertTrue(g.move(from: 12, to: 28))
    XCTAssertTrue(g.move(from: 48, to: 40))
    XCTAssertTrue(g.move(from: 28, to: 36))
    XCTAssertTrue(g.move(from: 51, to: 35))
    XCTAssertTrue(g.move(from: 36, to: 43))
    XCTAssertNil(g.board[35])
    XCTAssertEqual(g.board[43], .init(.white, .pawn))
  }
  func testPromotionAndPin() {
    var g = ChessGame(
      board: [4: .init(.white, .king), 60: .init(.black, .king), 48: .init(.white, .pawn)],
      turn: .white)
    XCTAssertTrue(g.move(from: 48, to: 56))
    XCTAssertEqual(g.board[56], .init(.white, .queen))
    let pinned = ChessGame(
      board: [
        4: .init(.white, .king), 12: .init(.white, .rook), 60: .init(.black, .rook),
        63: .init(.black, .king),
      ], turn: .white)
    XCTAssertFalse(pinned.legalMoves(from: 12).contains { $0.1 == 13 })
  }
}
