import XCTest
@testable import MaroonSocial

@MainActor final class AppHapticsTests: XCTestCase {
  func testDefaultsEnabledPersistsOnlyChangesAndRespectsDisabledPreference() {
    var value: Bool?
    var writes: [Bool] = []
    var events: [AppHaptics.Event] = []
    let preferences = AppHaptics.Preferences(readEnabled: { value }, writeEnabled: { value = $0; writes.append($0) })
    let haptics = AppHaptics(preferences: preferences, isActive: { true }, feedback: { events.append($0) })
    XCTAssertTrue(haptics.enabled); XCTAssertTrue(writes.isEmpty)
    haptics.enabled = false; haptics.enabled = false
    XCTAssertFalse(haptics.play(.selection)); XCTAssertTrue(events.isEmpty); XCTAssertEqual(writes, [false])
    let relaunched = AppHaptics(preferences: preferences, isActive: { true }, feedback: { events.append($0) })
    XCTAssertFalse(relaunched.enabled); XCTAssertFalse(relaunched.play(.success))
    relaunched.enabled = true
    XCTAssertTrue(relaunched.play(.selection)); XCTAssertEqual(writes, [false, true]); XCTAssertEqual(events, [.selection])
  }
  func testOnlyIdenticalRapidFeedbackIsCoalescedWithoutLosingMeaningfulOutcome() {
    var time: TimeInterval = 100
    var events: [AppHaptics.Event] = []
    let haptics = AppHaptics(preferences: .init(readEnabled: { true }, writeEnabled: { _ in }), clock: { time }, isActive: { true }, feedback: { events.append($0) })
    XCTAssertTrue(haptics.play(.selection))
    time += 0.03; XCTAssertFalse(haptics.play(.selection))
    XCTAssertTrue(haptics.play(.success), "A confirmed outcome is distinct from a selection.")
    time += 0.03; XCTAssertTrue(haptics.play(.success), "Separate confirmed outcomes are never dropped by the tap coalescer.")
    time += 0.13; XCTAssertTrue(haptics.play(.success))
    XCTAssertEqual(events, [.selection, .success, .success, .success])
  }
  func testInactiveRequestsStaySilentAndDoNotConsumeTheNextInteraction() {
    var active = false
    var events: [AppHaptics.Event] = []
    let haptics = AppHaptics(preferences: .init(readEnabled: { true }, writeEnabled: { _ in }), clock: { 100 }, isActive: { active }, feedback: { events.append($0) })
    XCTAssertFalse(haptics.play(.impact)); active = true
    XCTAssertTrue(haptics.play(.impact)); active = false
    XCTAssertFalse(haptics.play(.error)); XCTAssertEqual(events, [.impact])
  }
  func testAllSemanticEventsReachTheInjectedSinkAndPreferenceToggleDoesNotBuzz() {
    var events: [AppHaptics.Event] = []
    let haptics = AppHaptics(preferences: .init(readEnabled: { true }, writeEnabled: { _ in }), isActive: { true }, feedback: { events.append($0) })
    let semantics: [AppHaptics.Event] = [.selection, .impact, .success, .warning, .error]
    semantics.forEach { XCTAssertTrue(haptics.play($0)) }
    haptics.enabled = false; haptics.enabled = true
    XCTAssertEqual(events, semantics, "The native settings toggle already owns its control feedback.")
  }
  func testLocalPreferenceSurvivesASeparateStoreWithoutChangingUnrelatedDefaults() {
    let suite = "AppHapticsTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("keep", forKey: "unrelated")
    let first = AppHaptics(preferences: .local(defaults), isActive: { true }, feedback: { _ in })
    first.enabled = false
    let second = AppHaptics(preferences: .local(defaults), isActive: { true }, feedback: { _ in XCTFail("Disabled preference emitted feedback") })
    XCTAssertFalse(second.play(.selection)); XCTAssertEqual(defaults.string(forKey: "unrelated"), "keep")
  }
  func testUITestPreferenceResetAndPreservationNeverTouchRealPreference() {
    let suite = "AppHapticsTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let real = AppHaptics.Preferences.forApplication(arguments: [], defaults: defaults)
    real.writeEnabled(false)
    let fresh = AppHaptics.Preferences.forApplication(arguments: ["--uitesting"], defaults: defaults)
    XCTAssertNil(fresh.readEnabled(), "A reset fixture starts with the enabled default.")
    fresh.writeEnabled(false)
    let preserved = AppHaptics.Preferences.forApplication(arguments: ["--uitesting-preserve"], defaults: defaults)
    XCTAssertEqual(preserved.readEnabled(), false)
    let both = AppHaptics.Preferences.forApplication(arguments: ["--uitesting", "--uitesting-preserve"], defaults: defaults)
    XCTAssertEqual(both.readEnabled(), false, "Preserve wins when both launch flags are present.")
    let reset = AppHaptics.Preferences.forApplication(arguments: ["--uitesting"], defaults: defaults)
    XCTAssertNil(reset.readEnabled()); XCTAssertEqual(real.readEnabled(), false)
  }

}
