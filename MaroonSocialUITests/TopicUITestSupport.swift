import XCTest

extension XCUIApplication {
  /// Fixture mode has topics, so a new post needs one before Send enables. Taps the chip in the
  /// composer's options panel (scrolling the panel back up if needed); a no-op without topics.
  func pickPostTopic(_ slug: String = "aggie_life", file: StaticString = #filePath, line: UInt = #line) {
    let chip = buttons["postTopic-\(slug)"]
    guard chip.waitForExistence(timeout: 3) else { return }
    let panel = scrollViews["postOptions"]
    for _ in 0..<4 where !chip.isHittable { panel.swipeDown(velocity: .slow) }
    for _ in 0..<4 where !chip.isHittable { panel.swipeUp(velocity: .slow) }
    XCTAssertTrue(chip.isHittable, "The topic chip is reachable", file: file, line: line)
    if !chip.isSelected { chip.tap() }
  }
}
