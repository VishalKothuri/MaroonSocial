import XCTest

extension XCUIApplication {
  /// Fixture mode has topics, so a new post needs one before Send enables. Taps the chip in the
  /// composer's grey panel (scrolling the expanded composer if needed); a no-op without topics.
  func pickPostTopic(_ slug: String = "aggie_life", file: StaticString = #filePath, line: UInt = #line) {
    let chip = buttons["postTopic-\(slug)"]
    guard chip.waitForExistence(timeout: 3) else { return }
    revealInComposer(chip, file: file, line: line)
    XCTAssertTrue(chip.isHittable, "The topic chip is reachable", file: file, line: line)
    if !chip.isSelected { chip.tap() }
  }

  /// Brings an element of the expanded composer into view. The card and the grey panel scroll
  /// together as one region (`postComposer`) when they are taller than the space above the keyboard.
  func revealInComposer(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    let composer = scrollViews["postComposer"]
    guard composer.waitForExistence(timeout: 3) else { return }
    for _ in 0..<10 {
      if element.isHittable { return }
      let keyboard = keyboards.firstMatch
      let bottom = keyboard.exists ? min(composer.frame.maxY, keyboard.frame.minY) : composer.frame.maxY
      let center = (composer.frame.minY + bottom) / 2
      // Starts in the card's side margin: pressing on a focused field would open its edit menu.
      let start = windows.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: composer.frame.minX + 16, dy: center))
      // Short, held drags: a fling could carry the element past the visible band.
      start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: element.frame.midY > center ? -90 : 90)), withVelocity: .slow, thenHoldForDuration: 0.3)
    }
    XCTAssertTrue(element.isHittable, "Expected a reachable composer control: \(element)", file: file, line: line)
  }
}
