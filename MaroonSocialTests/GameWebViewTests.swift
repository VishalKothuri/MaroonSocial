import XCTest
import WebKit
import UIKit
@testable import MaroonSocial

/// Exercises the real bundled Three/Matter/Cannon runtime inside iOS WebKit.
/// Synthetic games only: no network, social identity, camera or microphone.
@MainActor final class GameWebViewTests: XCTestCase {
  func testOfflinePoolBreakRendersAndChangesTurnAfterRealPhysics() async throws {
    let table = try await makeTable()
    defer { table.close() }
    try await table.configure(["kind": "pool", "online": false])
    try await assertTableFits(table)
    let flat = try await table.web.evaluateJavaScript("document.getElementById('table').getAttribute('aria-label').includes('flat overhead') && document.getElementById('camera').style.display === 'none'") as? Bool
    XCTAssertEqual(flat, true, "Pool aiming must stay flat and cannot be tilted mid-turn")
    let before = try await table.text("turn")
    let completed = expectation(description: "Real pool collision replay settles")
    table.settled = completed
    _ = try await table.web.evaluateJavaScript("document.getElementById('power').value='100'; document.getElementById('power').dispatchEvent(new Event('input')); document.getElementById('shoot').click();")
    await fulfillment(of: [completed], timeout: 15)
    let after = try await table.text("turn")
    XCTAssertNotEqual(after, before)
    XCTAssertTrue(after.contains("Player 2"), after)
    XCTAssertTrue(table.events.contains { $0["type"] as? String == "haptic" })
    let shotLabel = try await table.text("shoot")
    XCTAssertEqual(shotLabel, "Take shot")
    XCTAssertTrue(table.errors.isEmpty, table.errors.joined(separator: "; "))
    try await attachTable(table, name: "Pool after collision replay")
  }

  func testOfflineCupPongThrowScoresAndReplayDoesNotAwardAnotherPoint() async throws {
    let table = try await makeTable()
    defer { table.close() }
    try await table.configure(["kind": "pong", "online": false])
    try await assertTableFits(table)
    let completed = expectation(description: "Real 3D throw settles")
    table.settled = completed
    _ = try await table.web.evaluateJavaScript("document.getElementById('power').value='30'; document.getElementById('power').dispatchEvent(new Event('input')); document.getElementById('shoot').click();")
    await fulfillment(of: [completed], timeout: 10)
    let score = try await table.text("score")
    XCTAssertTrue(score.contains("1/6"), score)
    let nextTurn = try await table.text("turn")
    XCTAssertTrue(nextTurn.contains("Player 2"))
    let replayed = expectation(description: "Manual replay settles")
    table.settled = replayed
    _ = try await table.web.evaluateJavaScript("document.getElementById('replayShot').click()")
    await fulfillment(of: [replayed], timeout: 10)
    let scoreAfterReplay = try await table.text("score")
    XCTAssertEqual(scoreAfterReplay, score, "Watching a replay must not score again")
    XCTAssertTrue(table.errors.isEmpty, table.errors.joined(separator: "; "))
    try await attachTable(table, name: "Cup pong after a sunk cup")
  }

  func testPullBackReleaseUsesFinalPositionWhenPointerMovesAreMissingOrCoalesced() async throws {
    let table = try await makeTable()
    defer { table.close() }
    let url = try XCTUnwrap(Bundle(for: GameWebViewTests.self).url(forResource: "game-states", withExtension: "json"))
    let fixtures = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String: Any]])
    for kind in ["pool", "pong"] {
      let state = try XCTUnwrap(fixtures[kind]?["state"] as? [String: Any])
      var inputs: [[String: Any]] = []
      for (index, moves) in ["none", "stale", "complete"].enumerated() {
        try await table.configure(["kind": kind, "online": true, "yourSeat": 0, "version": index + 20, "state": state, "interactive": true])
        let sent = expectation(description: "\(kind) releases one shot with \(moves) pointer moves")
        table.shot = sent
        let count = table.events.filter { $0["type"] as? String == "shot" }.count
        _ = try await table.web.callAsyncJavaScript("""
          const canvas = document.getElementById('table'), rect = canvas.getBoundingClientRect();
          const x = rect.left + rect.width * .5, startY = rect.top + rect.height * .45, endY = rect.top + rect.height * .79;
          const fire = (type, y, pointerId = 7) => canvas.dispatchEvent(new PointerEvent(type, {bubbles: true, pointerId, pointerType: 'touch', isPrimary: true, button: 0, buttons: type === 'pointerup' ? 0 : 1, clientX: x, clientY: y}));
          document.getElementById('power').value = '3'; document.getElementById('power').dispatchEvent(new Event('input'));
          fire('pointerdown', startY);
          if (moves === 'stale') fire('pointermove', startY + 1);
          if (moves === 'complete') fire('pointermove', endY);
          // Another pointer must not release the originating drag.
          fire('pointerup', startY, 99);
          fire('pointerup', endY);
          fire('pointerup', endY);
          """, arguments: ["moves": moves], in: nil, contentWorld: .page)
        await fulfillment(of: [sent], timeout: 3)
        XCTAssertEqual(table.events.filter { $0["type"] as? String == "shot" }.count, count + 1, "A release must submit exactly one shot")
        let input = try XCTUnwrap(table.events.last { $0["type"] as? String == "shot" }?["input"] as? [String: Any])
        XCTAssertGreaterThan(try XCTUnwrap(input["power"] as? Double), 0.1, "Release must use the pull distance instead of stale slider power")
        inputs.append(input)
      }
      for input in inputs.dropFirst() {
        XCTAssertEqual(try XCTUnwrap(input["power"] as? Double), try XCTUnwrap(inputs[0]["power"] as? Double), accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(input["aim"] as? Double), try XCTUnwrap(inputs[0]["aim"] as? Double), accuracy: 0.0001)
      }
    }
    XCTAssertTrue(table.errors.isEmpty, table.errors.joined(separator: "; "))
  }

  func testPongSidewaysAimDoesNotSwingWhenPullingFartherDown() async throws {
    let table = try await makeTable()
    defer { table.close() }
    try await table.configure(["kind": "pong", "online": false])
    let result = try await table.web.callAsyncJavaScript("""
      const canvas = document.getElementById('table'), rect = canvas.getBoundingClientRect();
      const x = rect.left + rect.width * .5, y = rect.top + rect.height * .45;
      const fire = (type, dx, dy) => canvas.dispatchEvent(new PointerEvent(type, {bubbles:true,pointerId:8,pointerType:'touch',isPrimary:true,button:0,buttons:1,clientX:x+dx,clientY:y+dy}));
      fire('pointerdown',0,0); fire('pointermove',-20,40);
      const shortAim = Number(document.getElementById('aim').value), shortPower = Number(document.getElementById('power').value);
      await new Promise(resolve => setTimeout(resolve, 100));
      fire('pointermove',-20,100);
      const longAim = Number(document.getElementById('aim').value), longPower = Number(document.getElementById('power').value);
      fire('pointercancel',-20,100); fire('pointerup',-20,100);
      return {shortAim,longAim,shortPower,longPower,replayEnabled:!document.getElementById('replayShot').disabled};
      """, arguments: [:], in: nil, contentWorld: .page) as? [String: Any]
    let values = try XCTUnwrap(result)
    XCTAssertEqual(try XCTUnwrap(values["shortAim"] as? Double), try XCTUnwrap(values["longAim"] as? Double), accuracy: 0.001)
    XCTAssertGreaterThan(try XCTUnwrap(values["longPower"] as? Double), try XCTUnwrap(values["shortPower"] as? Double))
    XCTAssertEqual(values["replayEnabled"] as? Bool, false, "A cancelled pull must never throw a ball or award a score")
    XCTAssertTrue(table.errors.isEmpty, table.errors.joined(separator: "; "))
  }

  func testOnlinePoolPongAndChessWaitForCanonicalStateAndDisableOpponentTurn() async throws {
    let table = try await makeTable()
    defer { table.close() }
    let url = try XCTUnwrap(Bundle(for: GameWebViewTests.self).url(forResource: "game-states", withExtension: "json"))
    let fixtures = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String: Any]])
    for kind in ["pool", "pong", "chess"] {
      let fixture = try XCTUnwrap(fixtures[kind])
      let state = try XCTUnwrap(fixture["state"] as? [String: Any])
      let outcome = try XCTUnwrap(fixture["outcome"] as? [String: Any])
      let before = table.events.filter { $0["type"] as? String == "shot" }.count
      let sent = expectation(description: "\(kind) sends bounded turn input")
      table.shot = sent
      try await table.configure(["kind": kind, "online": true, "yourSeat": 0, "players": ["Local", "Remote"], "version": 1, "state": state, "interactive": true])
      let initialTurn = try await table.text("turn")
      XCTAssertEqual(initialTurn, "Your turn")
      if kind == "chess" {
        _ = try await table.web.evaluateJavaScript("Array.from(document.querySelectorAll('#legal button')).find(b => b.textContent === 'e2 → e4').click()")
      } else {
        _ = try await table.web.evaluateJavaScript("document.getElementById('shoot').click()")
      }
      await fulfillment(of: [sent], timeout: 3)
      XCTAssertEqual(table.events.filter { $0["type"] as? String == "shot" }.count, before + 1)
      let pendingTurn = try await table.text("turn")
      XCTAssertEqual(pendingTurn, "Your turn", "A client must not advance an online turn before the canonical response")
      let input = try XCTUnwrap(table.events.last(where: { $0["type"] as? String == "shot" })?["input"] as? [String: Any])
      XCTAssertNil(input["winner"]); XCTAssertNil(input["state"])
      var canonical: [String: Any] = ["kind": kind, "online": true, "yourSeat": 0, "players": ["Local", "Remote"], "version": 2, "state": try XCTUnwrap(outcome["state"]), "replay": try XCTUnwrap(outcome["replay"]), "interactive": true]
      if kind != "chess" {
        let replayed = expectation(description: "\(kind) canonical replay settles")
        table.settled = replayed
        try await table.configure(canonical)
        // Native busy-state updates with the same version must not cancel the animation.
        canonical["interactive"] = false; try await table.configure(canonical)
        canonical["interactive"] = true; try await table.configure(canonical)
        await fulfillment(of: [replayed], timeout: 15)
      } else { try await table.configure(canonical) }
      let canonicalTurn = try await table.text("turn")
      XCTAssertEqual(canonicalTurn, "Remote’s turn")
      _ = try await table.web.evaluateJavaScript("document.getElementById('shoot').click()")
      XCTAssertEqual(table.events.filter { $0["type"] as? String == "shot" }.count, before + 1, "Opponent turns must not emit another shot")
      try await assertTableFits(table)
    }
    XCTAssertTrue(table.errors.isEmpty, table.errors.joined(separator: "; "))
  }

  private func makeTable() async throws -> GameTableTestHarness {
    let ready = expectation(description: "Offline bundled page and WebGL renderer ready")
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    let table = GameTableTestHarness(scene: scene, ready: ready)
    let url = try XCTUnwrap(Bundle.main.url(forResource: "game-table", withExtension: "html"))
    table.web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    await fulfillment(of: [ready], timeout: 12)
    XCTAssertTrue(table.errors.isEmpty, table.errors.joined(separator: "; "))
    return table
  }
  private func assertTableFits(_ table: GameTableTestHarness) async throws {
    let fits = try await table.web.callAsyncJavaScript("""
      await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
      const table = document.getElementById('table'), controls = document.getElementById('controls');
      const rect = table.getBoundingClientRect(), c = controls.getBoundingClientRect();
      const gl = table.getContext('webgl2');
      return rect.width > 250 && rect.height > 200 && c.bottom <= innerHeight && !!gl && !!gl.getParameter(gl.VERSION);
      """, arguments: [:], in: nil, contentWorld: .page) as? Bool
    XCTAssertEqual(fits, true, "Real WebGL table and controls must fit the phone viewport")
  }
  private func attachTable(_ table: GameTableTestHarness, name: String) async throws {
    let image = try await table.web.takeSnapshot(configuration: nil)
    let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
  }
}

@MainActor private final class GameTableTestHarness: NSObject, WKScriptMessageHandler {
  let web: WKWebView
  let window: UIWindow
  let ready: XCTestExpectation
  var settled: XCTestExpectation?
  var shot: XCTestExpectation?
  var events: [[String: Any]] = []
  var errors: [String] = []
  init(scene: UIWindowScene, ready: XCTestExpectation) {
    self.ready = ready
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    web = WKWebView(frame: CGRect(x: 0, y: 0, width: 402, height: 720), configuration: config)
    window = UIWindow(windowScene: scene)
    super.init()
    config.userContentController.add(self, name: "game")
    config.userContentController.addUserScript(WKUserScript(source: "window.addEventListener('error', e => window.webkit.messageHandlers.game.postMessage({type:'error',message:e.message}));", injectionTime: .atDocumentStart, forMainFrameOnly: true))
    let controller = UIViewController(); window.rootViewController = controller; window.isHidden = false
    controller.view.addSubview(web)
  }
  func configure(_ value: [String: Any]) async throws {
    _ = try await web.callAsyncJavaScript("window.MaroonGame.configure(config)", arguments: ["config": value], in: nil, contentWorld: .page)
  }
  func text(_ id: String) async throws -> String {
    try await web.callAsyncJavaScript("return document.getElementById(id).textContent", arguments: ["id": id], in: nil, contentWorld: .page) as? String ?? ""
  }
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let body = message.body as? [String: Any] else { return }
    events.append(body)
    switch body["type"] as? String {
    case "ready": ready.fulfill()
    case "settled": settled?.fulfill(); settled = nil
    case "shot": shot?.fulfill(); shot = nil
    case "error": errors.append(body["message"] as? String ?? "Unknown renderer error")
    default: break
    }
  }
  func close() {
    web.configuration.userContentController.removeScriptMessageHandler(forName: "game")
    web.stopLoading(); web.removeFromSuperview(); window.isHidden = true
  }
}
