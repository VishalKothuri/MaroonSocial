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

  // MARK: Topics
  func testPostTopicDecodesWithAndWithoutTheKey() throws {
    let base = #""id":"p","author":"Aggie","anonymous":true,"community":"Texas A&M","text":"Hi","score":1,"vote":0,"comments":[],"created":100,"saved":false,"acceptsDM":false"#
    XCTAssertNil(try JSONDecoder().decode(Post.self, from: Data("{\(base)}".utf8)).topic, "Servers before topics send no key")
    XCTAssertNil(try JSONDecoder().decode(Post.self, from: Data("{\(base),\"topic\":null}".utf8)).topic, "Deleted posts and posts without a topic send null")
    let tagged = try JSONDecoder().decode(Post.self, from: Data("{\(base),\"topic\":\"sports\"}".utf8))
    XCTAssertEqual(tagged.topic, "sports")
    XCTAssertEqual(try JSONDecoder().decode(Post.self, from: JSONEncoder().encode(tagged)).topic, "sports", "The device cache keeps the topic")
    let untagged = try JSONDecoder().decode(Post.self, from: Data("{\(base)}".utf8))
    XCTAssertFalse(String(decoding: try JSONEncoder().encode(untagged), as: UTF8.self).contains("topic"), "No topic writes no key, so old caches stay byte-identical")
  }
  func testTopicsListRowsDecodeAndActiveDropsMalformedAndDuplicateRows() throws {
    let json = ##"{"topics":[{"slug":"sports","title":"Sports","emoji":"🏈","text_hex":"#FDBA74","fill_hex":"#472D1F","sort_order":5,"recent_count":12},{"slug":"academics","title":"Academics","emoji":"📚","text_hex":"#93C5FD","fill_hex":"#21304C","sort_order":1,"recent_count":0},{"slug":"Bad Slug","title":"Bad","emoji":"x","text_hex":"#000000","fill_hex":"#000000","sort_order":2},{"slug":"sports","title":"Copy","emoji":"x","text_hex":"#000000","fill_hex":"#000000","sort_order":3}]}"##
    struct Payload: Decodable { var topics: [Topic] }
    let topics = try JSONDecoder().decode(Payload.self, from: Data(json.utf8)).topics
    XCTAssertEqual(topics.first?.textHex, "#FDBA74"); XCTAssertEqual(topics.first?.recentCount, 12); XCTAssertEqual(topics.first?.order, 5)
    XCTAssertTrue(topics.allSatisfy(\.active), "topics.list lists active topics only")
    XCTAssertEqual(TopicCatalog.active(topics).map(\.slug), ["academics", "sports"], "Catalog order, valid slugs, first copy wins")
  }
  func testFallbackCatalogHasTheFourteenRowsWithEightLaunchTopics() {
    XCTAssertEqual(TopicCatalog.fallback.count, 14)
    XCTAssertEqual(TopicCatalog.active(TopicCatalog.fallback).map(\.slug), ["academics", "aggie_life", "questions", "housing", "sports", "relationships", "confessions", "memes"])
    for topic in TopicCatalog.fallback {
      XCTAssertTrue(Topic.isValidSlug(topic.slug), topic.slug)
      for hex in [topic.textHex, topic.fillHex] { XCTAssertNotNil(hex.range(of: "^#[0-9A-F]{6}$", options: .regularExpression), hex) }
    }
    XCTAssertEqual(TopicCatalog.display("sports", in: []).emoji, "🏈", "The bundled row colours a slug the server did not describe")
    XCTAssertEqual(TopicCatalog.display("food", in: []).title, "Food", "Reserve rows still draw")
    XCTAssertEqual(TopicCatalog.display("study_group", in: []).title, "Study Group", "An unknown slug gets a neutral row")
  }
  func testQuietTopicsFoldIntoMoreUnlessSelected() {
    let topics = TopicCatalog.active(TopicCatalog.fallback).enumerated().map { index, topic -> Topic in
      var value = topic; value.recentCount = [12, 5, 4, 0, 9, 5, 3, 1][index]; return value
    }
    let folded = TopicCatalog.fold(topics, selected: nil)
    XCTAssertEqual(folded.shown.map(\.slug), ["academics", "aggie_life", "sports", "relationships"], "5 or more posts in 7 days stay tabs")
    XCTAssertEqual(folded.more.map(\.slug), ["questions", "housing", "confessions", "memes"])
    let selected = TopicCatalog.fold(topics, selected: "memes")
    XCTAssertEqual(selected.shown.last?.slug, "memes", "A topic chosen from More is a tab until the member leaves it")
    XCTAssertFalse(selected.more.contains { $0.slug == "memes" })
    XCTAssertEqual(TopicCatalog.fold(TopicCatalog.fallback.map { var value = $0; value.recentCount = nil; return value }, selected: nil).more, [], "No counts: nothing folds")
  }
  func testTopicIsRequiredOnlyWhileTopicsAreAvailable() {
    let catalog = TopicCatalog.active(TopicCatalog.fallback)
    XCTAssertTrue(TopicCatalog.canPublish(topic: nil, topicsAvailable: false, catalog: []), "A server without topics takes posts without one")
    XCTAssertFalse(TopicCatalog.canPublish(topic: nil, topicsAvailable: true, catalog: catalog), "Pick a topic")
    XCTAssertTrue(TopicCatalog.canPublish(topic: "sports", topicsAvailable: true, catalog: catalog))
    XCTAssertFalse(TopicCatalog.canPublish(topic: "food", topicsAvailable: true, catalog: catalog), "Reserve topics are inactive")
    XCTAssertFalse(TopicCatalog.canPublish(topic: "made_up", topicsAvailable: true, catalog: catalog))
    XCTAssertTrue(TopicCatalog.needsGuardrail("confessions")); XCTAssertTrue(TopicCatalog.needsGuardrail("relationships"))
    XCTAssertFalse(TopicCatalog.needsGuardrail("sports")); XCTAssertFalse(TopicCatalog.needsGuardrail(nil))
  }
  func testReportReasonsOfferWrongTopicOnlyForAPostWithATopic() {
    let withTopic = PostReportReason.options(topicsAvailable: true, postHasTopic: true)
    XCTAssertTrue(withTopic.contains(PostReportReason.wrongTopic))
    XCTAssertEqual(withTopic.last, "Something else")
    XCTAssertFalse(PostReportReason.options(topicsAvailable: true, postHasTopic: false).contains(PostReportReason.wrongTopic))
    XCTAssertFalse(PostReportReason.options(topicsAvailable: false, postHasTopic: true).contains(PostReportReason.wrongTopic))
    XCTAssertTrue(withTopic.allSatisfy { (1...500).contains($0.count) }, "The report action stores 1–500 characters")
    XCTAssertEqual(Set(withTopic).count, withTopic.count)
  }
}
