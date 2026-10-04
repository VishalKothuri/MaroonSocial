import XCTest
import MaroonCore
@testable import MaroonSocial

@MainActor final class CourseTermsTests: XCTestCase {
  private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
  private func schedule() throws -> CourseTermSchedule {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "CourseTerms", withExtension: "json"))
    return try CourseTermSchedule.decode(Data(contentsOf: url))
  }
  private func response(_ schedule: CourseTermSchedule, now: Date) throws -> Data {
    var result = schedule; result.serverNow = now
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(result)
  }
  func testOfficialDatesAndChicagoOpeningClosingBoundaries() async throws {
    let schedule = try schedule()
    XCTAssertEqual(schedule.terms.filter(\.verified).count, 5)
    let spring = try XCTUnwrap(schedule.term(id: "Spring 2027"))
    XCTAssertEqual(spring.status(at: date("2026-12-01T05:59:59Z")), .locked)
    XCTAssertEqual(spring.status(at: date("2026-12-01T06:00:00Z")), .open)
    XCTAssertEqual(spring.status(at: date("2027-05-12T04:59:59Z")), .open)
    XCTAssertEqual(spring.status(at: date("2027-05-12T05:00:00Z")), .closed)
    let summer = try XCTUnwrap(schedule.term(id: "Summer 2027"))
    XCTAssertEqual(summer.opensAt, date("2027-05-01T05:00:00Z"))
    XCTAssertEqual(summer.endsOn, "2027-08-11") // Includes the later 10-week final exam.
    let fall = try XCTUnwrap(schedule.term(id: "Fall 2026"))
    XCTAssertEqual(fall.opensAt, date("2026-08-01T05:00:00Z"))
    XCTAssertEqual(fall.status(at: date("2026-12-11T06:00:00Z")), .closed)
  }
  func testPurgingUsesOneCalendarMonthAndDoesNotExtendReadAccess() async throws {
    let summer = try XCTUnwrap(try schedule().term(id: "Summer 2026"))
    XCTAssertEqual(summer.purgeAt, date("2026-09-07T05:00:00Z"))
    XCTAssertEqual(summer.status(at: date("2026-09-07T04:59:59Z")), .closed)
    XCTAssertEqual(summer.status(at: date("2026-09-07T05:00:00Z")), .purged)
    XCTAssertEqual(summer.purgeAt!.timeIntervalSince(summer.closesAt!), 31 * 86400)
  }
  func testThreeIndependentSlotsRollImmediatelyAndFutureYearsFailClosed() async throws {
    let schedule = try schedule()
    XCTAssertEqual(schedule.slots(now: date("2026-10-03T12:00:00Z")).map(\.id), ["Fall 2026", "Spring 2027", "Summer 2027"])
    let afterFall = schedule.slots(now: date("2026-12-11T06:00:00Z"))
    XCTAssertEqual(afterFall.map(\.id), ["Spring 2027", "Summer 2027", "Fall 2027"])
    XCTAssertEqual(afterFall.filter { $0.status(at: date("2026-12-11T06:00:00Z")) == .open }.map(\.id), ["Spring 2027"])
    let farFuture = schedule.slots(now: date("2033-10-03T12:00:00Z"))
    XCTAssertEqual(farFuture.count, 3)
    XCTAssertEqual(Set(farFuture.map(\.season)).count, 3)
    XCTAssertTrue(farFuture.allSatisfy { !$0.verified && $0.status(at: date("2033-10-03T12:00:00Z")) == .locked })
  }
  func testUnpublishedCalendarNeverOpensEvenAfterOpeningDate() async throws {
    let term = try XCTUnwrap(try schedule().term(id: "Fall 2027"))
    XCTAssertEqual(term.opensAt, date("2027-08-01T05:00:00Z"))
    XCTAssertFalse(term.verified)
    XCTAssertEqual(term.status(at: date("2027-10-01T05:00:00Z")), .locked)
  }
  func testMalformedMetadataAndDuplicateTermsAreRejected() async throws {
    let data = try response(schedule(), now: date("2026-10-03T12:00:00Z"))
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var terms = try XCTUnwrap(object["terms"] as? [[String: Any]])
    terms[0]["purgeAt"] = "2026-06-05T05:00:00Z"
    object["terms"] = terms
    XCTAssertThrowsError(try CourseTermSchedule.decode(JSONSerialization.data(withJSONObject: object)))
    terms = try XCTUnwrap((JSONSerialization.jsonObject(with: data) as? [String: Any])?["terms"] as? [[String: Any]])
    terms.append(terms[0]); object["terms"] = terms
    XCTAssertThrowsError(try CourseTermSchedule.decode(JSONSerialization.data(withJSONObject: object)))
    object["terms"] = Array(terms.dropLast()); object["serverNow"] = "2026-10-03T12:00:00.123Z"
    XCTAssertNotNil(try CourseTermSchedule.decode(JSONSerialization.data(withJSONObject: object)).serverNow)
  }
  func testTrustedClockExpiresOpenScreenUsingElapsedTimeAndPersistsOffline() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = directory.appending(path: "terms.json")
    let schedule = try schedule(), boundary = date("2026-12-11T06:00:00Z")
    var uptime = 100.0
    let service = CourseTermsService(schedule: schedule, now: boundary.addingTimeInterval(-5000), cacheURL: cache, uptime: { uptime }, automaticClock: false) {
      try self.response(schedule, now: boundary.addingTimeInterval(-1))
    }
    await service.refresh()
    XCTAssertTrue(service.canAccess(term: "Fall 2026"))
    XCTAssertEqual(service.advanceClock(), 1, accuracy: 0.001)
    var notifications = 0; service.onChange = { notifications += 1 }
    uptime += 1
    service.advanceClock()
    XCTAssertFalse(service.canAccess(term: "Fall 2026"))
    XCTAssertEqual(notifications, 1)
    let offline = CourseTermsService(schedule: schedule, now: boundary.addingTimeInterval(-86400), cacheURL: cache, uptime: { uptime }, automaticClock: false) { throw URLError(.notConnectedToInternet) }
    await offline.refresh()
    XCTAssertFalse(offline.canAccess(term: "Fall 2026"))
    XCTAssertEqual(offline.now, boundary)
    XCTAssertNotNil(offline.error)
  }
  func testLateOldResponseCannotReplaceNewerCalendarClock() async throws {
    let schedule = try schedule()
    var pending: CheckedContinuation<Data, Error>?
    var calls = 0
    let service = CourseTermsService(schedule: schedule, now: date("2026-10-03T12:00:00Z"), automaticClock: false) {
      calls += 1
      if calls == 1 { return try await withCheckedThrowingContinuation { pending = $0 } }
      return try self.response(schedule, now: self.date("2026-12-11T06:00:00Z"))
    }
    let old = Task { await service.refresh() }
    while pending == nil { await Task.yield() }
    await service.refresh()
    pending?.resume(returning: try response(schedule, now: date("2026-10-03T12:00:00Z")))
    await old.value
    XCTAssertFalse(service.canAccess(term: "Fall 2026"))
    XCTAssertFalse(service.busy)
  }
}

@MainActor final class CourseExpiryCacheTests: XCTestCase {
  func testExpiryRemovesCachedCourseMessagesMetadataAttachmentsAndBadges() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appending(path: "state.json")
    let boundary = ISO8601DateFormatter().date(from: "2026-12-11T06:00:00Z")!
    var uptime = 0.0
    let service = CourseTermsService(now: boundary.addingTimeInterval(-1), uptime: { uptime }, automaticClock: false) { throw URLError(.notConnectedToInternet) }
    let store = AppStore(storageURL: file, arguments: [], courseTermService: service)
    let course = Course("CHEM 107", "Chemistry", term: "Fall 2026")
    store.joinCourse(course)
    store.state.conversations.firstIndex { $0.id == course.id }.map { store.state.conversations[$0].messages = [Message(author: "classmate", text: "Private class note")] }
    store.conversationMeta[course.id] = SocialConversationMeta(id: course.id, kind: "course", status: "active", role: "member", canSend: true, unread: 2, lastRead: 0, pendingOutgoing: false)
    store.attachments = [SocialAttachmentReference(id: "fixture-image", kind: "image", mime: "image/jpeg", size: 100, roomID: course.id)]
    XCTAssertEqual(store.inboxCounts.total, 3) // Two class messages plus the existing demo request.
    service.advanceClock()
    uptime = 1; service.advanceClock()
    XCTAssertFalse(store.state.courses.contains { $0.id == course.id })
    XCTAssertFalse(store.state.conversations.contains { $0.id == course.id })
    XCTAssertNil(store.conversationMeta[course.id])
    XCTAssertTrue(store.attachments.isEmpty)
    XCTAssertEqual(store.inboxCounts.total, 1)
    let sent = await store.sendMessage(roomID: course.id, text: "Too late", media: nil, nonce: UUID().uuidString)
    XCTAssertFalse(sent)
    let saved = try JSONDecoder().decode(LocalState.self, from: Data(contentsOf: file))
    XCTAssertFalse(saved.conversations.contains { $0.id == course.id })
  }
}
