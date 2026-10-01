import MaroonCore
import SceneKit
import SwiftUI

struct GameView: View {
  let kind: String
  var body: some View {
    Group { if kind == "Chess" { ChessView() } else { ArcadeView(kind: kind) } }.navigationTitle(
      kind
    ).navigationBarTitleDisplayMode(.inline)
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
  scene.background.contents = UIColor(red: 0.91, green: 0.91, blue: 0.87, alpha: 1)
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
  @State private var selected: Int?
  @State private var scene = SCNScene()
  @State private var accessibleBoard = false
  func refresh() { scene = ChessScene.make(game, selected: selected) }
  func select(_ square: Int) {
    if let selected, game.move(from: selected, to: square) {
      self.selected = nil
    } else {
      selected = game.board[square]?.side == game.turn ? square : nil
    }
    refresh()
  }
  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        HStack {
          Pill(text: "Pass & play", icon: "person.2")
          Spacer()
          Button("New game") {
            game = ChessGame()
            selected = nil
            refresh()
          }
        }
        Text(game.status).font(.title3.bold()).accessibilityIdentifier("chessStatus")
        InteractiveScene(scene: scene) { name in
          if let s = Int(name.replacingOccurrences(of: "square-", with: "")) { select(s) }
        }.frame(height: 380).clipShape(RoundedRectangle(cornerRadius: 25))
        Text("Tap a piece, then a highlighted square.").font(.caption).foregroundStyle(.secondary)
        Toggle("Show labeled board", isOn: $accessibleBoard).font(.caption)
        if accessibleBoard {
          LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8), spacing: 2
          ) {
            ForEach((0..<64).reversed(), id: \.self) { s in
              let square = (s / 8) * 8 + (7 - s % 8)
              Button {
                select(square)
              } label: {
                VStack(spacing: 1) {
                  Text(game.board[square].map { symbol($0) } ?? " ").font(.title3)
                  Text(ChessGame.square(square)).font(.system(size: 8))
                }.frame(maxWidth: .infinity).frame(height: 40).background(
                  selected == square
                    ? Palette.lime
                    : ((square % 8 + square / 8) % 2 == 0
                      ? Color.white : Palette.maroon.opacity(0.15)))
              }.buttonStyle(.plain).accessibilityIdentifier("square-\(ChessGame.square(square))")
            }
          }
        }
        if !game.history.isEmpty {
          Text(game.history.suffix(8).joined(separator: "   ")).font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
        Text(
          "Local two-player chess. Pawns promote to queen automatically. Online invitations and server-authoritative games are not connected yet."
        ).font(.caption).foregroundStyle(.secondary)
      }.padding(20)
    }.appBackground().onAppear { refresh() }
  }
  func symbol(_ p: ChessGame.Piece) -> String {
    let white: [ChessGame.Kind: String] = [
      .king: "♔", .queen: "♕", .rook: "♖", .bishop: "♗", .knight: "♘", .pawn: "♙",
    ]
    let black: [ChessGame.Kind: String] = [
      .king: "♚", .queen: "♛", .rook: "♜", .bishop: "♝", .knight: "♞", .pawn: "♟",
    ]
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
@Observable final class ArcadeEngine {
  let kind: String
  var scene: SCNScene
  var angle: Double = 0
  var power: Double = 0.65
  var score = 0
  var shots = 0
  var busy = false
  var status = "Aim, set your power, and take a shot."
  private var balls: [SCNNode] = []
  private var cups: [SCNNode] = []
  private var cue: SCNNode?
  private var ticks = 0
  init(_ kind: String) {
    self.kind = kind
    scene = stage(camera: SCNVector3(0, 6, 6))
    reset()
  }
  func reset() {
    scene = stage(camera: SCNVector3(0, 6, 6))
    balls = []
    cups = []
    score = 0
    shots = 0
    busy = false
    scene.physicsWorld.gravity = SCNVector3Zero
    scene.physicsWorld.speed = 1
    let pool = kind == "8 Ball"
    let table = node(
      SCNBox(width: 2.8, height: 0.25, length: 5.15, chamferRadius: 0.15), dark,
      SCNVector3(0, -0.2, 0))
    scene.rootNode.addChildNode(table)
    scene.rootNode.addChildNode(
      node(
        SCNBox(width: 2.35, height: 0.05, length: 4.65, chamferRadius: 0.1),
        pool ? UIColor(red: 0.15, green: 0.37, blue: 0.28, alpha: 1) : cream,
        SCNVector3(0, -0.04, 0)))
    if pool {
      for (x, z, w, l) in [
        (-1.24, 0.0, 0.1, 4.8), (1.24, 0.0, 0.1, 4.8), (0.0, -2.39, 2.5, 0.1),
        (0.0, 2.39, 2.5, 0.1),
      ] {
        let rail = node(
          SCNBox(width: w, height: 0.4, length: l, chamferRadius: 0.03), dark,
          SCNVector3(Float(x), 0.08, Float(z)))
        rail.physicsBody = .static()
        rail.physicsBody?.restitution = 0.75
        scene.rootNode.addChildNode(rail)
      }
      for x: Float in [-1.12, 1.12] {
        for z: Float in [-2.25, 0, 2.25] {
          scene.rootNode.addChildNode(
            node(SCNCylinder(radius: 0.17, height: 0.03), .black, SCNVector3(x, 0.002, z)))
        }
      }
      let white = ball(.white, at: SCNVector3(0, 0.10, 1.1))
      cue = white
      balls.append(white)
      var n = 1
      for row in 0..<5 {
        for col in 0...row {
          let color: UIColor =
            n == 8
            ? .black
            : [
              .systemYellow, .systemBlue, .systemRed, .systemPurple, .systemOrange, .systemGreen,
              .brown,
            ][(n - 1) % 7]
          let b = ball(
            color,
            at: SCNVector3(Float(col) * 0.215 - Float(row) * 0.1075, 0.1, -0.7 - Float(row) * 0.19))
          b.name = "ball-\(n)"
          b.geometry?.firstMaterial?.diffuse.contents = ballTexture(number: n, color: color)
          balls.append(b)
          n += 1
        }
      }
    } else {
      for row in 0..<3 {
        for col in 0...row {
          let cup = node(
            SCNTube(innerRadius: 0.135, outerRadius: 0.16, height: 0.34),
            UIColor(red: 0.45, green: 0.07, blue: 0.12, alpha: 1),
            SCNVector3(Float(col) * 0.37 - Float(row) * 0.185, 0.17, -0.6 - Float(row) * 0.37))
          cups.append(cup)
          scene.rootNode.addChildNode(cup)
        }
      }
      cue = ball(.white, at: SCNVector3(0, 0.14, 1.65))
      cue?.physicsBody = nil
    }
    status = pool ? "Practice table · pocket all 15 balls." : "Sink all six cups."
  }
  private func ballTexture(number: Int, color: UIColor) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 256))
    return renderer.image { context in
      (number > 8 ? UIColor.white : color).setFill()
      context.fill(CGRect(x: 0, y: 0, width: 512, height: 256))
      if number > 8 {
        color.setFill()
        context.fill(CGRect(x: 0, y: 69, width: 512, height: 118))
      }
      for x in [128, 384] {
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(x: x - 32, y: 96, width: 64, height: 64)).fill()
        let text = "\(number)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
          .font: UIFont.boldSystemFont(ofSize: 37), .foregroundColor: UIColor.black,
        ]
        let size = text.size(withAttributes: attrs)
        text.draw(
          at: CGPoint(x: CGFloat(x) - size.width / 2, y: 128 - size.height / 2),
          withAttributes: attrs)
      }
    }
  }
  private func ball(_ color: UIColor, at position: SCNVector3) -> SCNNode {
    let b = node(SCNSphere(radius: 0.1), color, position)
    b.geometry?.materials = [material(color, rough: 0.16)]
    let body = SCNPhysicsBody(
      type: .dynamic, shape: SCNPhysicsShape(geometry: SCNSphere(radius: 0.1)))
    body.mass = 0.17
    body.restitution = 0.91
    body.friction = 0.1
    body.damping = 0.50
    body.angularDamping = 0.6
    body.velocityFactor = SCNVector3(1, 0, 1)
    b.physicsBody = body
    scene.rootNode.addChildNode(b)
    return b
  }
  func shoot() {
    guard !busy, let cue else { return }
    shots += 1
    busy = true
    ticks = 0
    if kind == "8 Ball" {
      let a = Float(angle * Double.pi / 180)
      cue.physicsBody?.velocity = SCNVector3(
        sin(a) * Float(power) * 7, 0, -cos(a) * Float(power) * 7)
      status = "Nice and easy…"
    } else {
      let x = Float(angle / 45) * 1.4
      let z = Float(1.65 - power * 4.5)
      let start = cue.position
      let action = SCNAction.customAction(duration: 1.1) { node, t in
        let f = Float(t / 1.1)
        node.position = SCNVector3(
          start.x + (x - start.x) * f, 0.14 + sin(f * .pi) * 1.5, start.z + (z - start.z) * f)
      }
      cue.runAction(action) {
        DispatchQueue.main.async {
          if let hit = self.cups.first(where: { hypot($0.position.x - x, $0.position.z - z) < 0.17 }
          ) {
            hit.removeFromParentNode()
            self.cups.removeAll { $0 === hit }
            self.score += 1
            self.status = self.score == 6 ? "All six! \(self.shots) shots." : "In the cup."
          } else {
            self.status = "Close. Adjust the aim and power."
          }
          cue.position = SCNVector3(0, 0.14, 1.65)
          self.busy = false
        }
      }
    }
  }
  func tick() {
    guard kind == "8 Ball", busy else { return }
    ticks += 1
    for ball in balls {
      let p = ball.presentation.position
      let pocket = abs(p.x) > 0.99 && (abs(p.z) > 2.10 || abs(p.z) < 0.13)
      if pocket {
        if ball === cue {
          ball.physicsBody?.velocity = SCNVector3Zero
          ball.position = SCNVector3(0, 0.1, 1.1)
          ball.physicsBody?.resetTransform()
          status = "Scratch · cue ball reset."
        } else {
          ball.removeFromParentNode()
          score += 1
          balls.removeAll { $0 === ball }
        }
      }
    }
    if ticks > 15
      && (balls.allSatisfy {
        let v = $0.physicsBody?.velocity ?? SCNVector3Zero
        return abs(v.x) + abs(v.z) < 0.07
      } || ticks > 150)
    {
      busy = false
      status =
        score == 15
        ? "Table cleared in \(shots) shots!" : "\(score) pocketed. Line up your next shot."
    }
  }
}
struct ArcadeView: View {
  let kind: String
  @State private var engine: ArcadeEngine
  init(kind: String) {
    self.kind = kind
    _engine = State(initialValue: ArcadeEngine(kind))
  }
  let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        HStack {
          Pill(text: "Solo practice", icon: "gamecontroller")
          Spacer()
          Button("Reset") { engine.reset() }
        }
        HStack {
          Text("\(engine.score) \(kind=="8 Ball" ? "pocketed":"cups")").font(.title3.bold())
          Spacer()
          Text("\(engine.shots) shots").font(.caption).foregroundStyle(.secondary)
        }
        InteractiveScene(scene: engine.scene).frame(height: 365).clipShape(
          RoundedRectangle(cornerRadius: 26))
        Text(engine.status).font(.subheadline).frame(minHeight: 30)
        HStack {
          Text("Aim").frame(width: 48, alignment: .leading)
          Slider(value: $engine.angle, in: kind == "8 Ball" ? -180...180 : -80...80)
          Text("\(Int(engine.angle))°").monospacedDigit().frame(width: 40)
        }
        HStack {
          Text("Power").frame(width: 48, alignment: .leading)
          Slider(value: $engine.power, in: 0.1...1)
          Text("\(Int(engine.power*100))%").monospacedDigit().frame(width: 40)
        }
        Button(engine.busy ? "Shot in motion…" : "Take shot") { engine.shoot() }.buttonStyle(
          PrimaryButton()
        ).disabled(engine.busy).accessibilityIdentifier("takeShot")
        Text(
          kind == "8 Ball"
            ? "Physics practice table. Competitive 8-ball rules, turn synchronization and online opponents are not enabled yet."
            : "3D skill practice. Online cup pong matches are not enabled yet."
        ).font(.caption).foregroundStyle(.secondary)
      }.padding(20)
    }.appBackground().onReceive(timer) { _ in engine.tick() }
  }
}
