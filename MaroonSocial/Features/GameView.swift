import MaroonCore
import SceneKit
import SwiftUI

struct GameView: View {
  let kind: String
  var body: some View {
    Group {
      if !FeatureAvailability.isGameAvailable(title: kind) {
        ContentUnavailableView(FeatureAvailability.unavailableMessage(for: kind), systemImage: "gamecontroller", description: Text("This game is turned off for now. Chess is still available from Explore."))
          .accessibilityIdentifier("hiddenGameUnavailable")
      } else if kind == "Chess" { ChessView() } else { PhysicsGameView(kind: kind) }
    }.navigationTitle(
      FeatureAvailability.isGameAvailable(title: kind) ? kind : ""
    ).navigationBarTitleDisplayMode(.inline).hidesTabBarWhenPushed()
  }
}
private func material(_ color: UIColor, metal: CGFloat = 0, rough: CGFloat = 0.5) -> SCNMaterial {
  let m = SCNMaterial()
  m.diffuse.contents = color
  m.metalness.contents = metal
  m.roughness.contents = rough
  m.lightingModel = .physicallyBased
  return m
}
private func node(_ shape: SCNGeometry, _ color: UIColor, _ at: SCNVector3) -> SCNNode {
  shape.materials = [material(color)]
  let n = SCNNode(geometry: shape)
  n.position = at
  return n
}
private let cream = UIColor(red: 0.93, green: 0.89, blue: 0.78, alpha: 1)
private let dark = UIColor(red: 0.12, green: 0.17, blue: 0.14, alpha: 1)
private func stage(camera: SCNVector3, at: SCNVector3 = SCNVector3Zero) -> SCNScene {
  let scene = SCNScene()
  scene.background.contents = UIColor(red: 0.055, green: 0.059, blue: 0.071, alpha: 1)
  let c = SCNNode()
  c.camera = SCNCamera()
  c.camera?.usesOrthographicProjection = true
  c.camera?.orthographicScale = 2.8
  c.position = camera
  c.look(at: at)
  scene.rootNode.addChildNode(c)
  let key = SCNNode()
  key.light = SCNLight()
  key.light?.type = .omni
  key.light?.intensity = 650
  key.light?.castsShadow = true
  key.position = SCNVector3(1, 8, 4)
  scene.rootNode.addChildNode(key)
  let fill = SCNNode()
  fill.light = SCNLight()
  fill.light?.type = .ambient
  fill.light?.intensity = 280
  scene.rootNode.addChildNode(fill)
  return scene
}
struct InteractiveScene: UIViewRepresentable {
  let scene: SCNScene
  var tap: ((String) -> Void)? = nil
  func makeCoordinator() -> Coordinator { Coordinator(tap) }
  func makeUIView(context: Context) -> SCNView {
    let v = SCNView()
    v.scene = scene
    v.antialiasingMode = .multisampling4X
    v.isPlaying = true
    v.backgroundColor = .clear
    v.addGestureRecognizer(
      UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.hit(_:))))
    return v
  }
  func updateUIView(_ view: SCNView, context: Context) {
    if view.scene !== scene { view.scene = scene }
    context.coordinator.tap = tap
  }
  class Coordinator: NSObject {
    var tap: ((String) -> Void)?
    init(_ tap: ((String) -> Void)?) { self.tap = tap }
    @objc func hit(_ gesture: UITapGestureRecognizer) {
      guard let v = gesture.view as? SCNView else { return }
      for hit in v.hitTest(gesture.location(in: v), options: nil) {
        var n: SCNNode? = hit.node
        while let current = n {
          if let name = current.name, name.hasPrefix("square-") {
            tap?(name)
            return
          }
          n = current.parent
        }
      }
    }
  }
}
struct ChessView: View {
  @State private var game = ChessGame()
  @State private var previous: [ChessGame] = []
  @State private var selected: Int?
  @State private var scene = SCNScene()
  @State private var accessibleBoard = false
  @State private var computer = false
  @State private var thinking = false
  @State private var confirmReset = false
  @State private var pendingPromotion: (Int, Int)?
  private var targets: Set<Int> { Set(selected.map { game.legalMoves(from: $0).map { $0.1 } } ?? []) }
  private func refresh() { scene = ChessScene.make(game, selected: selected) }
  private func reset() {
    game = ChessGame(); previous = []; selected = nil; thinking = false; pendingPromotion = nil
    refresh()
  }
  private func move(_ from: Int, _ to: Int, promotion: ChessGame.Kind = .queen, userInitiated: Bool = true) {
    let before = game
    if game.move(from: from, to: to, promotion: promotion) {
      previous.append(before); selected = nil
      if userInitiated { AppHaptics.shared.play(.impact) }
    }
    refresh()
  }
  private func select(_ square: Int) {
    guard !game.finished, !thinking, !(computer && game.turn == .black) else { return }
    if let selected, targets.contains(square) {
      if game.board[selected]?.kind == .pawn && [0, 7].contains(square / 8) {
        pendingPromotion = (selected, square)
      } else { move(selected, square) }
    } else {
      let previousSelection = selected
      selected = selected == square ? nil : game.board[square]?.side == game.turn ? square : nil
      if selected != previousSelection, selected != nil { AppHaptics.shared.play(.selection) }
      refresh()
    }
  }
  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        HStack {
          Pill(text: computer ? "You vs. computer" : "Pass & play", icon: computer ? "cpu" : "person.2")
          Spacer()
          Button("New game") { confirmReset = true }.font(.subheadline.bold())
        }
        Picker("Opponent", selection: $computer) {
          Text("Two players").tag(false)
          Text("Computer").tag(true)
        }.pickerStyle(.segmented).onChange(of: computer) { _, _ in reset() }
        VStack(spacing: 5) {
          Text(game.status).font(.title3.bold()).accessibilityIdentifier("chessStatus")
          Text(thinking ? "Computer is thinking…" : game.finished ? "Start a rematch or undo the last move." : selected.map { "\(ChessGame.square($0)) selected · choose a highlighted square" } ?? "Tap one of your pieces to see legal moves.")
            .font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).frame(minHeight: 56)
        if accessibleBoard { labeledBoard }
        else {
          InteractiveScene(scene: scene) { name in
            if let s = Int(name.replacingOccurrences(of: "square-", with: "")) { select(s) }
          }.frame(height: 340).clipShape(RoundedRectangle(cornerRadius: 25))
        }
        HStack {
          Toggle("Show labeled board", isOn: $accessibleBoard).font(.caption)
          Spacer(minLength: 18)
          Button {
            if computer && game.turn == .white && previous.count >= 2 {
              previous.removeLast(); game = previous.removeLast()
            } else if let last = previous.popLast() { game = last }
            selected = nil; refresh()
          } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
          .font(.caption.bold()).disabled(previous.isEmpty || thinking)
        }
        if !game.history.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            Text(game.history.enumerated().map { "\($0.offset + 1). \($0.element)" }.suffix(8).joined(separator: "   "))
              .font(.caption.monospaced()).padding(12)
          }.background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        GameRules(title: "Chess at your pace", text: computer ? "You play White. The computer considers your next reply before moving. Tap Undo to take back a turn. Castling, en passant, promotion, checkmate and draw rules are supported." : "Share this iPhone and alternate moves. White moves first. Castling, en passant and promotion are supported. Legal destinations glow green; your king can never move into check.")
      }.padding(20)
    }.appBackground().onAppear { refresh() }
      .confirmationDialog("Start a new chess game?", isPresented: $confirmReset, titleVisibility: .visible) {
        Button("New game", role: .destructive) { reset(); AppHaptics.shared.play(.selection) }
      }
      .confirmationDialog("Promote your pawn", isPresented: Binding(get: { pendingPromotion != nil }, set: { if !$0 { pendingPromotion = nil } }), titleVisibility: .visible) {
        ForEach([ChessGame.Kind.queen, .rook, .bishop, .knight], id: \.self) { kind in
          Button(kind.rawValue.capitalized) {
            if let pending = pendingPromotion { move(pending.0, pending.1, promotion: kind) }
            pendingPromotion = nil
          }
        }
      }
      .task(id: "\(computer)-\(game.history.count)") {
        guard computer, game.turn == .black, !game.finished else { return }
        thinking = true
        let snapshot = game
        let choice = await Task.detached(priority: .userInitiated) { snapshot.suggestedMove() }.value
        guard !Task.isCancelled else { return }
        thinking = false
        if let choice { move(choice.from, choice.to, userInitiated: false) }
      }
  }
  private var labeledBoard: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 8), spacing: 0) {
      ForEach(0..<64, id: \.self) { index in
        let square = (7 - index / 8) * 8 + index % 8
        let piece = game.board[square]
        Button { select(square) } label: {
          ZStack(alignment: .bottomLeading) {
            Rectangle().fill(selected == square ? Palette.lime : (square % 8 + square / 8) % 2 == 0 ? Color(red: 0.52, green: 0.39, blue: 0.40) : Color(red: 0.86, green: 0.81, blue: 0.72))
            if targets.contains(square) {
              Circle().fill(Palette.maroon.opacity(0.32)).frame(width: piece == nil ? 13 : 34, height: piece == nil ? 13 : 34).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Text(piece.map { symbol($0) } ?? "").font(.system(size: 32)).foregroundStyle(Color(red: 0.10, green: 0.07, blue: 0.08)).frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(ChessGame.square(square)).font(.system(size: 8, weight: .semibold)).foregroundStyle(Color.black.opacity(0.7)).padding(3)
          }.aspectRatio(1, contentMode: .fit)
        }.buttonStyle(.plain).accessibilityIdentifier("square-\(ChessGame.square(square))")
          .accessibilityLabel("\(ChessGame.square(square)), \(piece.map { "\($0.side.rawValue) \($0.kind.rawValue)" } ?? "empty")\(targets.contains(square) ? ", legal destination" : "")")
      }
    }.clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.maroon.opacity(0.2)))
  }
  private func symbol(_ p: ChessGame.Piece) -> String {
    let white: [ChessGame.Kind: String] = [.king: "♔", .queen: "♕", .rook: "♖", .bishop: "♗", .knight: "♘", .pawn: "♙"]
    let black: [ChessGame.Kind: String] = [.king: "♚", .queen: "♛", .rook: "♜", .bishop: "♝", .knight: "♞", .pawn: "♟"]
    return (p.side == .white ? white : black)[p.kind]!
  }
}
enum ChessScene {
  static func make(_ game: ChessGame, selected: Int?) -> SCNScene {
    let s = stage(camera: SCNVector3(0, 7.2, 6.3))
    let base = node(
      SCNBox(width: 4.5, height: 0.22, length: 4.5, chamferRadius: 0.1), dark,
      SCNVector3(0, -0.18, 0))
    s.rootNode.addChildNode(base)
    let targets = selected.map { game.legalMoves(from: $0).map { $0.1 } } ?? []
    for i in 0..<64 {
      let x = Float(i % 8) * 0.5 - 1.75
      let z = 1.75 - Float(i / 8) * 0.5
      let color: UIColor =
        selected == i
        ? .systemYellow
        : targets.contains(i)
          ? UIColor(red: 0.7, green: 0.84, blue: 0.4, alpha: 1)
          : (i % 8 + i / 8) % 2 == 0 ? UIColor(red: 0.36, green: 0.08, blue: 0.13, alpha: 1) : cream
      let tile = node(
        SCNBox(width: 0.5, height: 0.035, length: 0.5, chamferRadius: 0), color,
        SCNVector3(x, -0.035, z))
      tile.name = "square-\(i)"
      s.rootNode.addChildNode(tile)
      if let p = game.board[i] {
        let piece = makePiece(p)
        piece.position = SCNVector3(x, 0, z)
        piece.name = "square-\(i)"
        s.rootNode.addChildNode(piece)
      }
    }
    return s
  }
  static func makePiece(_ p: ChessGame.Piece) -> SCNNode {
    let root = SCNNode()
    let color = p.side == .white ? cream : dark
    func part(_ geometry: SCNGeometry, _ y: Float) {
      root.addChildNode(node(geometry, color, SCNVector3(0, y, 0)))
    }
    part(SCNCylinder(radius: 0.18, height: 0.07), 0.035)
    part(SCNCylinder(radius: 0.145, height: 0.04), 0.09)
    let h: CGFloat = p.kind == .pawn ? 0.2 : p.kind == .king ? 0.39 : 0.31
    part(SCNCone(topRadius: 0.065, bottomRadius: 0.12, height: h), Float(h / 2) + 0.11)
    let top = Float(h) + 0.11
    switch p.kind {
    case .pawn: part(SCNSphere(radius: 0.105), top + 0.06)
    case .rook:
      part(SCNCylinder(radius: 0.135, height: 0.13), top + 0.05)
      for i in 0..<4 {
        let a = Double(i) * Double.pi / 2
        root.addChildNode(
          node(
            SCNBox(width: 0.075, height: 0.09, length: 0.07, chamferRadius: 0.008), color,
            SCNVector3(Float(cos(a) * 0.1), top + 0.15, Float(sin(a) * 0.1))))
      }
    case .bishop:
      part(SCNSphere(radius: 0.12), top + 0.06)
      part(SCNCone(topRadius: 0, bottomRadius: 0.07, height: 0.15), top + 0.17)
    case .knight:
      let neck = node(
        SCNBox(width: 0.12, height: 0.2, length: 0.14, chamferRadius: 0.05), color,
        SCNVector3(0, top + 0.07, 0))
      neck.eulerAngles.x = -0.25
      root.addChildNode(neck)
      root.addChildNode(
        node(
          SCNBox(width: 0.13, height: 0.09, length: 0.22, chamferRadius: 0.03), color,
          SCNVector3(0, top + 0.15, -0.06)))
      part(SCNCone(topRadius: 0, bottomRadius: 0.055, height: 0.13), top + 0.24)
    case .queen:
      part(SCNCone(topRadius: 0.145, bottomRadius: 0.07, height: 0.13), top + 0.045)
      part(SCNSphere(radius: 0.055), top + 0.145)
    case .king:
      part(SCNSphere(radius: 0.10), top + 0.04)
      part(SCNBox(width: 0.055, height: 0.22, length: 0.055, chamferRadius: 0.01), top + 0.19)
      part(SCNBox(width: 0.17, height: 0.045, length: 0.055, chamferRadius: 0.01), top + 0.22)
    }
    return root
  }
}

private struct GameRules: View {
  let title: String
  let text: String
  var body: some View {
    DisclosureGroup {
      Text(text).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
    } label: {
      Label(title, systemImage: "info.circle").font(.subheadline.weight(.medium))
    }.padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
  }
}
