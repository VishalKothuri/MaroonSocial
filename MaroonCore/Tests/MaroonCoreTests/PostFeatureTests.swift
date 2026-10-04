import XCTest
@testable import MaroonCore

final class PostFeatureTests: XCTestCase {
  func testLegacyPostAndNewPollRoundTripUseTheirDecoderDateStrategy() throws {
    let old = Data(#"{"id":"legacy","author":"Aggie","anonymous":true,"community":"Texas A&M","text":"Old post","score":1,"vote":0,"comments":[],"created":100,"saved":false,"acceptsDM":false}"#.utf8)
    let decoded = try JSONDecoder().decode(Post.self, from: old)
    XCTAssertNil(decoded.poll); XCTAssertNil(decoded.linkURL); XCTAssertNil(decoded.tags)
    var post = decoded
    post.poll = PostPoll(question: "Library or coffee?", options: [.init(id: "a", text: "Library"), .init(id: "b", text: "Coffee")], endsAt: Date(timeIntervalSince1970: 2_000_000_000))
    post.linkURL = "https://tamu.edu"; post.tags = ["campus"]
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
    XCTAssertEqual(try decoder.decode(Post.self, from: encoder.encode(post)), post)
    XCTAssertEqual(try JSONDecoder().decode(Post.self, from: JSONEncoder().encode(post)), post, "Local caches use the default date strategy.")
  }
  func testPollAndLinkOnlyPostsNormalizeWithoutMakingTagsOnlyValid() throws {
    let link = try PostFeatureRules.validate(text: " \n", linkURL: " tamu.edu/academics ", tags: ["#Campus", "campus", " study_group "])
    XCTAssertEqual(link.text, ""); XCTAssertEqual(link.linkURL, "https://tamu.edu/academics"); XCTAssertEqual(link.tags, ["campus", "study_group"])
    let poll = try PostFeatureRules.validate(text: "", poll: PostPollDraft(question: " Where? ", options: [" Library ", " Coffee "], durationHours: 72))
    XCTAssertEqual(poll.poll?.question, "Where?"); XCTAssertEqual(poll.poll?.options, ["Library", "Coffee"])
    XCTAssertThrowsError(try PostFeatureRules.validate(text: "", tags: ["campus"]))
    XCTAssertThrowsError(try PostFeatureRules.validate(text: String(repeating: "a", count: 1001), linkURL: "tamu.edu"))
    XCTAssertNoThrow(try PostFeatureRules.validate(text: String(repeating: "a", count: 1000)))
  }
  func testUnsafeMalformedAndOversizedLinksAreRejected() throws {
    for value in ["javascript:alert(1)", "ftp://tamu.edu/file", "https://person:password@tamu.edu", "https://person@tamu.edu", "https://", "https://tamu.edu/a b", "https://tamu.edu/\nfoo", "https://tamu.edu/\u{0000}", "https://tamu.edu/" + String(repeating: "x", count: 2048)] {
      XCTAssertThrowsError(try PostFeatureRules.normalizeLink(value), value)
    }
    XCTAssertEqual(try PostFeatureRules.normalizeLink("http://tamu.edu/path?q=1#part"), "http://tamu.edu/path?q=1#part")
    XCTAssertNil(try PostFeatureRules.normalizeLink(" \n"))
  }
  func testTagsAreBoundedASCIIAndDeduplicatedAfterCanonicalization() throws {
    XCTAssertEqual(try PostFeatureRules.normalizeTags(["#Study", "STUDY", "12_ag"]), ["study", "12_ag"])
    for values in [[""], ["#"], ["with-dash"], ["café"], ["two words"], [String(repeating: "x", count: 25)], ["a", "b", "c", "d", "e", "f"]] {
      XCTAssertThrowsError(try PostFeatureRules.normalizeTags(values))
    }
    XCTAssertEqual(try PostFeatureRules.normalizeTags(["a", "b", "c", "d", "e", "#A"]).count, 5)
  }
  func testPollValidationRejectsDuplicateEmptyLongAndOutOfRangeAnswers() {
    let bad: [PostPollDraft] = [
      .init(question: " ", options: ["A", "B"]), .init(question: String(repeating: "?", count: 181), options: ["A", "B"]),
      .init(question: "Where?", options: ["Library", " library "]), .init(question: "Where?", options: ["Library", " "]),
      .init(question: "Where?", options: ["One"]), .init(question: "Where?", options: ["A", "B", "C", "D", "E"]),
      .init(question: "Where?", options: [String(repeating: "x", count: 81), "B"]), .init(question: "Where?", options: ["A", "B"], durationHours: 48),
    ]
    for draft in bad { XCTAssertThrowsError(try PostFeatureRules.validate(text: "Body", poll: draft)) }
    for hours in [24, 72, 168] {
      XCTAssertNoThrow(try PostFeatureRules.validate(text: "", poll: .init(question: String(repeating: "q", count: 180), options: [String(repeating: "a", count: 80), "B", "C", "D"], durationHours: hours)))
    }
  }
  func testPollVoteChangesDoNotInflateCountsAndDeadlineIsExclusive() {
    let deadline = Date(timeIntervalSince1970: 1000)
    var poll = PostPoll(question: "Where?", options: [.init(id: "a", text: "A", votes: 2), .init(id: "b", text: "B", votes: 3)], endsAt: deadline, totalVotes: 5)
    XCTAssertTrue(poll.select("a", now: deadline.addingTimeInterval(-1)))
    XCTAssertEqual(poll.options.map(\.votes), [3, 3]); XCTAssertEqual(poll.totalVotes, 6)
    XCTAssertTrue(poll.select("a", now: deadline.addingTimeInterval(-1))); XCTAssertEqual(poll.totalVotes, 6)
    XCTAssertTrue(poll.select("b", now: deadline.addingTimeInterval(-1))); XCTAssertEqual(poll.options.map(\.votes), [2, 4]); XCTAssertEqual(poll.totalVotes, 6)
    let before = poll
    XCTAssertFalse(poll.select("missing", now: deadline.addingTimeInterval(-1)))
    XCTAssertFalse(poll.select("a", now: deadline)); XCTAssertEqual(poll, before)
  }
}
