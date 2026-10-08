import XCTest
import MaroonCore
@testable import MaroonSocial

/// The composer's poll (the post text is the question), its tool toggles and the one-time
/// migration of drafts saved with a separate poll question.
@MainActor final class PostComposerTests: XCTestCase {
  private func poll(_ options: [String], hours: Int = 24) -> PostComposerFeatures {
    PostComposerFeatures(pollEnabled: true, poll: PostPollDraft(options: options, durationHours: hours))
  }

  // MARK: Payload and limits

  func testPollPayloadSendsTheTextAsTheQuestionAndAnEmptyBody() throws {
    let features = poll([" Evans ", "MSC"], hours: 72)
    let sent = features.payload(text: "  Best study spot?\n")
    XCTAssertEqual(sent.text, "", "The body goes out empty")
    XCTAssertEqual(sent.poll?.question, "Best study spot?", "The trimmed text is the question")
    XCTAssertEqual(sent.poll?.options, [" Evans ", "MSC"])
    XCTAssertEqual(sent.poll?.durationHours, 72)
    let validated = try features.validate(text: "Best study spot?")
    XCTAssertEqual(validated.text, ""); XCTAssertEqual(validated.poll?.question, "Best study spot?")
    XCTAssertEqual(validated.poll?.options, ["Evans", "MSC"])
    XCTAssertEqual(features.poll.question, "", "The draft never stores a separate question")
    let plain = PostComposerFeatures().payload(text: "  Hello  ")
    XCTAssertEqual(plain.text, "Hello"); XCTAssertNil(plain.poll)
  }
  func testPollTextIsLimitedTo180AndRequired() {
    let features = poll(["A", "B"])
    XCTAssertEqual(features.characterLimit, 180)
    XCTAssertEqual(PostComposerFeatures().characterLimit, 1000)
    XCTAssertNoThrow(try features.validate(text: String(repeating: "q", count: 180)))
    XCTAssertThrowsError(try features.validate(text: String(repeating: "q", count: 181))) { XCTAssertEqual($0 as? PostFeatureError, .invalidQuestion) }
    XCTAssertThrowsError(try features.validate(text: " \n ")) { XCTAssertEqual($0 as? PostFeatureError, .invalidQuestion, "A poll needs its question") }
    XCTAssertNoThrow(try PostComposerFeatures().validate(text: String(repeating: "a", count: 1000)), "Without a poll the limit is 1,000")
    XCTAssertThrowsError(try features.validate(text: " ", hasQuote: true), "A quote repost with a poll follows the same rule")
    XCTAssertNoThrow(try features.validate(text: "Agree?", hasQuote: true))
  }
  func testChoicesNeedTwoToFourDifferentNonEmptyAnswers() {
    for options in [["A", ""], ["A"], ["A", " a "], ["A", String(repeating: "x", count: 81)], ["A", "B", "C", "D", "E"]] {
      XCTAssertThrowsError(try poll(options).validate(text: "Where?"), "\(options)") { XCTAssertEqual($0 as? PostFeatureError, .invalidOptions) }
    }
    XCTAssertNoThrow(try poll(["A", "B", "C", "D"]).validate(text: "Where?"))
    XCTAssertThrowsError(try poll(["A", "B"], hours: 48).validate(text: "Where?")) { XCTAssertEqual($0 as? PostFeatureError, .invalidDuration) }
  }
  func testFixtureStorePublishesThePollWithAnEmptyBody() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = AppStore(storageURL: directory.appending(path: "posts.json"), arguments: []); store.enter(username: "poll_tester")
    let sent = poll(["Library", "Coffee"]).payload(text: "Where should we study?")
    let created = await store.createPost(text: sent.text, anonymous: true, community: .campus, acceptsDM: true, poll: sent.poll)
    XCTAssertTrue(created)
    let post = try XCTUnwrap(store.state.posts.first)
    XCTAssertEqual(post.text, ""); XCTAssertEqual(post.poll?.question, "Where should we study?")
    XCTAssertEqual(post.poll?.options.map(\.text), ["Library", "Coffee"])
  }

  // MARK: Tools

  func testToolRowTogglesAndRemovingClearsTheContent() {
    var features = PostComposerFeatures()
    for tool in PostComposerFeatures.Tool.allCases { XCTAssertFalse(features.isOn(tool)) }
    XCTAssertTrue(features.toggle(.poll)); XCTAssertTrue(features.pollEnabled)
    features.poll.options = ["Evans", "MSC", "Library"]; features.poll.durationHours = 168
    XCTAssertFalse(features.toggle(.poll), "Tapping an active tool turns it off")
    XCTAssertEqual(features.poll, PostPollDraft(), "and clears it")
    XCTAssertTrue(features.toggle(.poll)); XCTAssertEqual(features.poll.options, ["", ""], "Re-enabled, it starts fresh")
    XCTAssertTrue(features.toggle(.link)); features.link = "tamu.edu"
    XCTAssertTrue(features.toggle(.tags)); features.tagsText = "#Campus, study_group"
    XCTAssertEqual(features.tagValues, ["#Campus", "study_group"])
    XCTAssertFalse(features.toggle(.link)); XCTAssertEqual(features.link, "")
    XCTAssertFalse(features.toggle(.tags)); XCTAssertEqual(features.tagsText, "")
    XCTAssertTrue(features.pollEnabled, "Each tool is independent")
    features.enable(.poll); XCTAssertTrue(features.pollEnabled, "Add poll from the collapsed menu never turns it off")
    features.disable(.poll); XCTAssertFalse(features.pollEnabled)
  }
  func testChoicesAddRemoveAndReturnMovesToTheNextChoice() {
    var features = poll(["", ""])
    XCTAssertEqual(features.choiceAfterReturn(from: 0), 1, "Return moves to the next choice")
    XCTAssertNil(features.choiceAfterReturn(from: 1), "An empty last choice adds nothing")
    features.poll.options[1] = "MSC"
    XCTAssertEqual(features.choiceAfterReturn(from: 1), 2, "Return in a filled last choice adds one")
    XCTAssertEqual(features.poll.options.count, 3)
    features.poll.options[2] = "Library"
    XCTAssertEqual(features.choiceAfterReturn(from: 2), 3)
    features.poll.options[3] = "Coffee"
    XCTAssertNil(features.choiceAfterReturn(from: 3), "Never more than four")
    XCTAssertFalse(features.canAddChoice); XCTAssertNil(features.addChoice())
    features.removeChoice(at: 2); XCTAssertEqual(features.poll.options, ["", "MSC", "Coffee"])
    features.removeChoice(at: 2); features.removeChoice(at: 1)
    XCTAssertEqual(features.poll.options.count, 2, "Two choices always stay")
    XCTAssertEqual(features.addChoice(), 2)
  }

  // MARK: Reported problems

  func testIncompleteDraftsReportNothingButBrokenLimitsDo() {
    var features = PostComposerFeatures()
    XCTAssertNil(features.brokenRule(text: ""), "An empty draft is incomplete, not wrong")
    features.toggle(.poll)
    XCTAssertNil(features.brokenRule(text: ""), "A poll just added has no question or choices yet")
    XCTAssertNil(features.brokenRule(text: "Where?"), "Choices still to type")
    features.poll.options = ["Evans", ""]
    XCTAssertNil(features.brokenRule(text: "Where?"))
    XCTAssertEqual(features.brokenRule(text: String(repeating: "q", count: 181)), .invalidQuestion)
    features.poll.options = ["Evans", "evans "]
    XCTAssertEqual(features.brokenRule(text: "Where?"), .invalidOptions, "Duplicate choices")
    XCTAssertEqual(features.brokenRule(text: ""), .invalidOptions, "A duplicate shows even before the question")
    features.poll.options = ["Evans", String(repeating: "c", count: 81)]
    XCTAssertEqual(features.brokenRule(text: "Where?"), .invalidOptions, "An over-long choice")
    features.poll.options = ["Evans", "MSC"]
    XCTAssertNil(features.brokenRule(text: "Where?"))
    features.toggle(.poll)
    XCTAssertEqual(features.brokenRule(text: String(repeating: "t", count: 1001)), .textTooLong)
    features.toggle(.link); features.link = "ftp://example.com"
    XCTAssertEqual(features.brokenRule(text: "Hi"), .invalidLink)
    features.link = ""
    XCTAssertNil(features.brokenRule(text: "Hi"), "An empty link field is left out")
  }

  // MARK: Draft migration

  func testLegacyDraftQuestionWithoutBodyBecomesTheText() {
    let old = PostPollDraft(question: "Best study spot?", options: ["Evans", "MSC"], durationHours: 72)
    let migrated = PostComposerFeatures.migratingLegacyPoll(text: "", pollEnabled: true, poll: old)
    XCTAssertEqual(migrated.text, "Best study spot?")
    XCTAssertTrue(migrated.features.pollEnabled)
    XCTAssertEqual(migrated.features.poll, PostPollDraft(question: "", options: ["Evans", "MSC"], durationHours: 72))
    let again = PostComposerFeatures.migratingLegacyPoll(text: migrated.text, pollEnabled: true, poll: migrated.features.poll)
    XCTAssertEqual(again.text, migrated.text); XCTAssertEqual(again.features, migrated.features, "Migration runs once")
    XCTAssertEqual(PostComposerFeatures.migratingLegacyPoll(text: " \n", pollEnabled: true, poll: old).text, "Best study spot?", "A blank body counts as empty")
  }
  func testLegacyDraftWithBodyAndQuestionThatFitKeepsBothAsTheQuestion() {
    let old = PostPollDraft(question: "Best dining hall?", options: ["Sbisa", "Commons"])
    let migrated = PostComposerFeatures.migratingLegacyPoll(text: "Settle this once and for all", pollEnabled: true, poll: old)
    XCTAssertEqual(migrated.text, "Settle this once and for all\nBest dining hall?", "The old question is kept")
    XCTAssertTrue(migrated.features.pollEnabled)
    XCTAssertEqual(migrated.features.poll.question, "")
    XCTAssertEqual(migrated.features.poll.options, ["Sbisa", "Commons"])
    XCTAssertNoThrow(try migrated.features.validate(text: migrated.text))
    // Exactly 180 together still fits.
    let edge = PostComposerFeatures.migratingLegacyPoll(text: String(repeating: "b", count: 167), pollEnabled: true, poll: PostPollDraft(question: "Old question", options: ["A", "B"]))
    XCTAssertEqual(edge.text.count, 180); XCTAssertTrue(edge.features.pollEnabled)
    XCTAssertTrue(edge.text.hasSuffix("\nOld question"))
  }
  func testLegacyDraftWithBodyThatFitsButNotWithTheQuestionKeepsThePollOff() {
    let old = PostPollDraft(question: "Old question", options: ["A", "B"])
    let body = String(repeating: "b", count: 180)
    let migrated = PostComposerFeatures.migratingLegacyPoll(text: body, pollEnabled: true, poll: old)
    XCTAssertEqual(migrated.text, body + "\nOld question", "Nothing typed is lost")
    XCTAssertFalse(migrated.features.pollEnabled, "Too long together to be a question")
    XCTAssertEqual(migrated.features.poll.question, "")
    XCTAssertEqual(migrated.features.poll.options, ["A", "B"], "The choices wait for a re-added poll")
  }
  func testLegacyDraftWithLongBodyKeepsThePollOffAndAppendsTheQuestion() {
    let old = PostPollDraft(question: "Old question?", options: ["A", "B", "C"])
    let body = String(repeating: "b", count: 181)
    let migrated = PostComposerFeatures.migratingLegacyPoll(text: body, pollEnabled: true, poll: old)
    XCTAssertEqual(migrated.text, body + "\nOld question?", "Nothing typed is lost")
    XCTAssertFalse(migrated.features.pollEnabled, "Too long to be a question, so the poll stays off")
    XCTAssertEqual(migrated.features.poll.options, ["A", "B", "C"], "The choices wait for a re-added poll")
    XCTAssertNoThrow(try migrated.features.validate(text: String(migrated.text.prefix(1000))))
  }
  func testDraftsWithoutALegacyQuestionAreUnchanged() {
    let none = PostComposerFeatures.migratingLegacyPoll(text: "Hello", pollEnabled: false, poll: nil)
    XCTAssertEqual(none.text, "Hello"); XCTAssertEqual(none.features, PostComposerFeatures())
    let current = PostComposerFeatures.migratingLegacyPoll(text: "Where?", pollEnabled: true, poll: PostPollDraft(options: ["A", "B"]))
    XCTAssertEqual(current.text, "Where?"); XCTAssertTrue(current.features.pollEnabled)
    let removed = PostComposerFeatures.migratingLegacyPoll(text: "Body", pollEnabled: false, poll: PostPollDraft(question: "Removed poll", options: ["A", "B"]))
    XCTAssertEqual(removed.text, "Body", "A removed poll's question was never going to be sent")
    XCTAssertFalse(removed.features.pollEnabled); XCTAssertEqual(removed.features.poll.question, "")
  }
}
