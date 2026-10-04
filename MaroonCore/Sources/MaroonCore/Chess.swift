import Foundation

public struct ChessGame: Equatable, Sendable {
  public enum Side: String, Equatable, Sendable {
    case white, black
    public var other: Side { self == .white ? .black : .white }
  }
  public enum Kind: String, Equatable, Sendable { case pawn, rook, knight, bishop, queen, king }
  public struct Piece: Equatable, Sendable {
    public let side: Side
    public var kind: Kind
    public init(_ side: Side, _ kind: Kind) {
      self.side = side
      self.kind = kind
    }
  }
  public private(set) var board: [Int: Piece] = [:]
  public private(set) var turn: Side = .white
  public private(set) var enPassant: Int?
  public private(set) var moved: Set<Int> = []
  public private(set) var history: [String] = []
  public private(set) var halfMoves = 0
  private var positions: [String: Int] = [:]
  public init() {
    let back: [Kind] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
    for f in 0..<8 {
      board[f] = Piece(.white, back[f])
      board[8 + f] = Piece(.white, .pawn)
      board[48 + f] = Piece(.black, .pawn)
      board[56 + f] = Piece(.black, back[f])
    }
    positions[positionKey] = 1
  }
  public init(board: [Int: Piece], turn: Side) {
    self.board = board
    self.turn = turn
    positions[positionKey] = 1
  }
  public var status: String {
    if legalMoves().isEmpty {
      return inCheck(turn) ? "Checkmate · \(turn.other.rawValue.capitalized) wins" : "Stalemate"
    }
    if insufficientMaterial { return "Draw · insufficient material" }
    if positions[positionKey, default: 0] >= 3 { return "Draw · threefold repetition" }
    if halfMoves >= 100 { return "Draw · fifty-move rule" }
    return "\(turn.rawValue.capitalized) to move\(inCheck(turn) ? " · check":"")"
  }
  public var finished: Bool {
    insufficientMaterial || positions[positionKey, default: 0] >= 3 || halfMoves >= 100 || legalMoves().isEmpty
  }
  private var insufficientMaterial: Bool {
    let pieces = board.filter { $0.value.kind != .king }
    if pieces.isEmpty { return true }
    if pieces.count == 1 { return pieces.values.first!.kind == .bishop || pieces.values.first!.kind == .knight }
    return pieces.values.allSatisfy { $0.kind == .bishop }
      && Set(pieces.keys.map { ($0 / 8 + $0 % 8) % 2 }).count == 1
  }
  private var positionKey: String {
    let pieces = board.keys.sorted().map { "\($0):\(board[$0]!.side.rawValue):\(board[$0]!.kind.rawValue)" }.joined(separator: ",")
    let rights = [0, 7, 56, 63].map { rook in
      let king = rook < 8 ? 4 : 60
      return !moved.contains(king) && !moved.contains(rook) ? String(rook) : "-"
    }.joined(separator: ",")
    // En passant only distinguishes positions when a legal capture is actually available.
    let effectiveEnPassant = enPassant.flatMap { destination -> Int? in
      let direction = turn == .white ? 8 : -8
      for fileOffset in [-1, 1] {
        let source = destination - direction + fileOffset
        guard (0..<64).contains(source), abs(source % 8 - destination % 8) == 1,
          board[source] == Piece(turn, .pawn) else { continue }
        var capture = self
        capture.apply(source, destination, promotion: .queen)
        if !capture.inCheck(turn) { return destination }
      }
      return nil
    }
    return "\(pieces)|\(turn.rawValue)|\(rights)|\(effectiveEnPassant.map(String.init) ?? "-")"
  }
  /// A deterministic two-ply opponent: considers every legal reply and prioritizes king safety.
  public func suggestedMove() -> (from: Int, to: Int)? {
    guard !finished else { return nil }
    let side = turn
    func value(_ position: ChessGame) -> Int {
      let moves = position.legalMoves()
      if moves.isEmpty { return position.inCheck(position.turn) ? (position.turn == side ? -100_000 : 100_000) : 0 }
      if position.insufficientMaterial { return 0 }
      return position.board.reduce(0) { score, entry in
        let (square, piece) = entry
        let values: [Kind: Int] = [.pawn: 100, .knight: 320, .bishop: 330, .rook: 500, .queen: 900, .king: 0]
        let center = 7 - abs(square % 8 * 2 - 7) / 2 - abs(square / 8 * 2 - 7) / 2
        let advancement = piece.side == .white ? square / 8 : 7 - square / 8
        let positional = piece.kind == .pawn ? advancement * 4 : piece.kind == .king ? 0 : center * 3
        return score + (piece.side == side ? 1 : -1) * (values[piece.kind, default: 0] + positional)
      }
    }
    var best: (Int, Int)?
    var bestScore = Int.min
    for move in legalMoves().sorted(by: { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }) {
      var candidate = self
      candidate.apply(move.0, move.1, promotion: .queen)
      candidate.turn = side.other
      let replies = candidate.legalMoves()
      var score = value(candidate)
      if !replies.isEmpty {
        score = Int.max
        for reply in replies {
          var response = candidate
          response.apply(reply.0, reply.1, promotion: .queen)
          response.turn = side
          score = min(score, value(response))
        }
      }
      if score > bestScore { best = move; bestScore = score }
    }
    return best.map { (from: $0.0, to: $0.1) }
  }
  public func legalMoves(from: Int? = nil) -> [(Int, Int)] {
    var moves: [(Int, Int)] = []
    for (s, p) in board where p.side == turn && (from == nil || from == s) {
      for d in pseudo(s, attacks: false) {
        var next = self
        next.apply(s, d, promotion: .queen)
        if !next.inCheck(turn) { moves.append((s, d)) }
      }
    }
    return moves
  }
  @discardableResult public mutating func move(from: Int, to: Int, promotion: Kind = .queen) -> Bool
  {
    guard !finished, legalMoves(from: from).contains(where: { $0.1 == to }) else { return false }
    let chosen: [Kind] = [.queen, .rook, .bishop, .knight]
    apply(from, to, promotion: chosen.contains(promotion) ? promotion : .queen)
    history.append("\(Self.square(from))–\(Self.square(to))")
    turn = turn.other
    positions[positionKey, default: 0] += 1
    return true
  }
  public static func square(_ index: Int) -> String { "\(Array("abcdefgh")[index%8])\(index/8+1)" }
  public func inCheck(_ side: Side) -> Bool {
    guard let king = board.first(where: { $0.value == Piece(side, .king) })?.key else {
      return true
    }
    return attacked(king, by: side.other)
  }
  private func attacked(_ square: Int, by side: Side) -> Bool {
    board.contains { index, piece in
      piece.side == side && pseudo(index, attacks: true).contains(square)
    }
  }
  private func pseudo(_ s: Int, attacks: Bool) -> [Int] {
    guard let p = board[s] else { return [] }
    let x = s % 8
    let y = s / 8
    var result: [Int] = []
    func add(_ dx: Int, _ dy: Int, slide: Bool = false) {
      var nx = x + dx
      var ny = y + dy
      while (0..<8).contains(nx) && (0..<8).contains(ny) {
        let d = ny * 8 + nx
        if let target = board[d] {
          if target.side != p.side && (attacks || target.kind != .king) { result.append(d) }
          if attacks && target.side == p.side { result.append(d) }
          break
        } else {
          result.append(d)
        }
        if !slide { break }
        nx += dx
        ny += dy
      }
    }
    switch p.kind {
    case .pawn:
      let step = p.side == .white ? 1 : -1
      if attacks {
        for dx in [-1, 1] {
          let nx = x + dx
          let ny = y + step
          if (0..<8).contains(nx) && (0..<8).contains(ny) { result.append(ny * 8 + nx) }
        }
      } else {
        let one = s + step * 8
        if (0..<64).contains(one), board[one] == nil {
          result.append(one)
          let two = one + step * 8
          if y == (p.side == .white ? 1 : 6), board[two] == nil { result.append(two) }
        }
        for dx in [-1, 1] {
          let nx = x + dx
          let ny = y + step
          if (0..<8).contains(nx) && (0..<8).contains(ny) {
            let d = ny * 8 + nx
            if let other = board[d], other.side != p.side, other.kind != .king {
              result.append(d)
            } else if d == enPassant {
              result.append(d)
            }
          }
        }
      }
    case .knight:
      for (a, b) in [(1, 2), (2, 1), (-1, 2), (-2, 1), (1, -2), (2, -1), (-1, -2), (-2, -1)] {
        add(a, b)
      }
    case .bishop: for (a, b) in [(1, 1), (1, -1), (-1, 1), (-1, -1)] { add(a, b, slide: true) }
    case .rook: for (a, b) in [(1, 0), (-1, 0), (0, 1), (0, -1)] { add(a, b, slide: true) }
    case .queen:
      for (a, b) in [(1, 1), (1, -1), (-1, 1), (-1, -1), (1, 0), (-1, 0), (0, 1), (0, -1)] {
        add(a, b, slide: true)
      }
    case .king:
      for dx in -1...1 { for dy in -1...1 where dx != 0 || dy != 0 { add(dx, dy) } }
      let base = p.side == .white ? 0 : 56
      if !attacks, s == base + 4, !moved.contains(s), !attacked(s, by: p.side.other) {
        for (rook, dest, between) in [
          (base + 7, base + 6, [base + 5, base + 6]),
          (base, base + 2, [base + 1, base + 2, base + 3]),
        ] {
          if board[rook] == Piece(p.side, .rook), !moved.contains(rook),
            between.allSatisfy({ board[$0] == nil }),
            [s + (dest > s ? 1 : -1), dest].allSatisfy({ !attacked($0, by: p.side.other) })
          {
            result.append(dest)
          }
        }
      }
    }
    return result
  }
  private mutating func apply(_ from: Int, _ to: Int, promotion: Kind) {
    guard var p = board[from] else { return }
    let capture = board[to] != nil || (p.kind == .pawn && to == enPassant)
    halfMoves = p.kind == .pawn || capture ? 0 : halfMoves + 1
    if p.kind == .pawn, to == enPassant {
      board.removeValue(forKey: to + (p.side == .white ? -8 : 8))
    }
    enPassant = p.kind == .pawn && abs(to - from) == 16 ? (from + to) / 2 : nil
    if p.kind == .king, abs(to - from) == 2 {
      let rookFrom = to > from ? from + 3 : from - 4
      let rookTo = to > from ? from + 1 : from - 1
      board[rookTo] = board.removeValue(forKey: rookFrom)
      moved.insert(rookFrom)
      moved.insert(rookTo)
    }
    if p.kind == .pawn, to / 8 == 0 || to / 8 == 7 { p.kind = promotion }
    board.removeValue(forKey: from)
    board[to] = p
    moved.insert(from)
    moved.insert(to)
  }
}
