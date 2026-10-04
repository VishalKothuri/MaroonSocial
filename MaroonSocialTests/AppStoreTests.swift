import Foundation
import MaroonCore
import XCTest
@testable import MaroonSocial

final class AppStoreTests: XCTestCase {
  @MainActor private func withStore(_ body: (AppStore, URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appending(path: "state.json")
    let store = AppStore(storageURL: file, arguments: [])
    store.enter(username: "test_aggie")
    try body(store, file)
  }

  @MainActor func testUITestStorageNeverUsesPersonalStateFile() {
    let directory = URL(fileURLWithPath: "/tmp/test-storage")
    let personal = AppStore.storageFileURL(arguments: [], directory: directory)
    let fresh = AppStore.storageFileURL(arguments: ["--uitesting"], directory: directory)
    let preserved = AppStore.storageFileURL(arguments: ["--uitesting-preserve"], directory: directory)
    XCTAssertNotEqual(personal, fresh)
    XCTAssertEqual(fresh, preserved)
    XCTAssertEqual(personal.lastPathComponent, "preview-state.json")
  }

  @MainActor func testPersistenceRelaunchAndExplicitUITestReset() throws {
    try withStore { store, file in
      store.joinCourse(Course.catalog[0])
      let preserved = AppStore(storageURL: file, arguments: ["--uitesting", "--uitesting-preserve"])
      XCTAssertEqual(preserved.state.username, "test_aggie")
      XCTAssertEqual(preserved.state.courses.map(\.id), [Course.catalog[0].id])
      XCTAssertEqual(preserved.state.conversations.filter { $0.id == Course.catalog[0].id }.count, 1)
      let fresh = AppStore(storageURL: file, arguments: ["--uitesting"])
      XCTAssertFalse(fresh.state.onboarded)
      XCTAssertTrue(fresh.state.courses.isEmpty)
    }
  }

  @MainActor func testJoiningCourseRepairsMissingRoomWithoutDuplicateMembership() throws {
    try withStore { store, _ in
      let course = Course.catalog[0]
      store.joinCourse(course)
      store.joinCourse(course)
      XCTAssertEqual(store.state.courses.filter { $0.id == course.id }.count, 1)
      XCTAssertEqual(store.state.conversations.filter { $0.id == course.id }.count, 1)
      store.state.conversations.removeAll { $0.id == course.id }
      store.joinCourse(course)
      XCTAssertEqual(store.state.courses.filter { $0.id == course.id }.count, 1)
      XCTAssertEqual(store.state.conversations.filter { $0.id == course.id }.count, 1)
      store.leaveConversation(course.id)
      XCTAssertFalse(store.state.courses.contains { $0.id == course.id })
      XCTAssertFalse(store.state.conversations.contains { $0.id == course.id })
    }
  }

  @MainActor func testParticipantLeavingActivityReopensSpotAndCanRejoin() throws {
    try withStore { store, file in
      let activity = Activity(title: "Study", kind: .study, host: "host", place: "Library",
                              starts: .now.addingTimeInterval(3600), capacity: 2, details: "")
      store.state.activities = [activity]
      store.joinActivity(activity.id)
      XCTAssertEqual(store.state.activities[0].participants, ["host", "test_aggie"])
      store.leaveConversation(activity.id)
      XCTAssertEqual(store.state.activities[0].participants, ["host"])
      XCTAssertFalse(store.state.activities[0].cancelled)
      XCTAssertFalse(store.state.conversations.contains { $0.id == activity.id })
      store.joinActivity(activity.id)
      XCTAssertEqual(store.state.activities[0].participants, ["host", "test_aggie"])
      let loaded = AppStore(storageURL: file, arguments: [])
      XCTAssertEqual(loaded.state.activities[0].participants, ["host", "test_aggie"])
    }
  }

  @MainActor func testHostLeavingCancelsActivityAndDoesNotReopenChatFromStaleValue() throws {
    try withStore { store, _ in
      let activity = Activity(title: "Coffee", kind: .hangout, host: "test_aggie", place: "MSC",
                              starts: .now.addingTimeInterval(3600), capacity: 4, details: "")
      store.state.activities = [activity]
      store.ensureActivityConversation(activity)
      store.leaveConversation(activity.id)
      XCTAssertTrue(store.state.activities[0].cancelled)
      store.ensureActivityConversation(activity)
      store.joinActivity(activity.id)
      XCTAssertFalse(store.state.conversations.contains { $0.id == activity.id })
      XCTAssertNotNil(store.notice)
    }
  }

  @MainActor func testFullAndExpiredActivityCannotCreateConversation() throws {
    try withStore { store, _ in
      let full = Activity(title: "Full", kind: .hangout, host: "host", place: "MSC",
                          starts: .now.addingTimeInterval(3600), capacity: 1, details: "")
      let expired = Activity(title: "Past", kind: .hangout, host: "host", place: "MSC",
                             starts: .now.addingTimeInterval(-3600), capacity: 4, details: "")
      store.state.activities = [full, expired]
      for activity in [full, expired] {
        store.joinActivity(activity.id)
        XCTAssertFalse(store.state.conversations.contains { $0.id == activity.id })
        XCTAssertFalse(store.state.activities.first { $0.id == activity.id }!.participants.contains("test_aggie"))
      }
    }
  }

  @MainActor func testMessageRequestMustBeAcceptedBeforeSending() throws {
    try withStore { store, _ in
      let chat = Conversation(id: "request", title: "Request", request: true)
      store.state.conversations = [chat]
      XCTAssertFalse(store.send(chat.id, text: "hello"))
      XCTAssertTrue(store.state.conversations[0].messages.isEmpty)
      store.state.conversations[0].request = false
      XCTAssertTrue(store.send(chat.id, text: "  hello\n"))
      XCTAssertEqual(store.state.conversations[0].messages.first?.text, "hello")
      XCTAssertEqual(store.state.conversations[0].messages.first?.author, "test_aggie")
    }
  }

  @MainActor func testMessageLimitsAndInvalidAttachmentsKeepHistoryUnchanged() throws {
    try withStore { store, _ in
      let chat = Conversation(id: "chat", title: "Chat")
      store.state.conversations = [chat]
      XCTAssertFalse(store.send(chat.id, text: " \n "))
      XCTAssertFalse(store.send(chat.id, text: String(repeating: "x", count: 4001)))
      XCTAssertFalse(store.send(chat.id, text: "", media: MediaAttachment(kind: .image, data: Data())))
      XCTAssertFalse(store.send(chat.id, text: "", media: MediaAttachment(kind: .gif, data: Data("not a gif".utf8))))
      XCTAssertFalse(store.send(chat.id, text: "", media: MediaAttachment(kind: .image, data: Data(repeating: 0, count: 5_000_001))))
      XCTAssertFalse(store.send("missing", text: "hello"))
      XCTAssertTrue(store.state.conversations[0].messages.isEmpty)
    }
  }

  @MainActor func testValidPhotoOnlyMessageAndGameInvitationPersist() throws {
    try withStore { store, file in
      let chat = Conversation(id: "chat", title: "Chat")
      store.state.conversations = [chat]
      let png = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zl1sAAAAASUVORK5CYII="))
      XCTAssertTrue(store.send(chat.id, text: "", media: MediaAttachment(kind: .image, data: png)))
      XCTAssertTrue(store.send(chat.id, text: "Game invitation", game: "Chess"))
      let loaded = AppStore(storageURL: file, arguments: [])
      XCTAssertEqual(loaded.state.conversations[0].messages.count, 2)
      XCTAssertEqual(loaded.state.conversations[0].messages[0].media?.data, png)
      XCTAssertEqual(loaded.state.conversations[0].messages[1].game, "Chess")
    }
  }

  @MainActor func testFailedSaveRollsBackMembershipAndMessage() throws {
    let missingDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let store = AppStore(storageURL: missingDirectory.appending(path: "state.json"), arguments: [])
    store.state.username = "test_aggie"
    store.state.conversations = [Conversation(id: "chat", title: "Chat")]
    store.joinCourse(Course.catalog[0])
    XCTAssertTrue(store.state.courses.isEmpty)
    XCTAssertFalse(store.state.conversations.contains { $0.id == Course.catalog[0].id })
    XCTAssertFalse(store.send("chat", text: "Keep my draft"))
    XCTAssertTrue(store.state.conversations[0].messages.isEmpty)
    XCTAssertNotNil(store.notice)
  }

  @MainActor func testSavedPostsVotesAndReportsPersistWithCorrectVoteSwitching() throws {
    try withStore { store, file in
      let id = try XCTUnwrap(store.state.posts.first?.id)
      let score = store.state.posts[0].score
      store.vote(id, 1)
      store.vote(id, -1)
      XCTAssertEqual(store.state.posts[0].score, score - 1)
      store.vote(id, -1)
      XCTAssertEqual(store.state.posts[0].score, score)
      store.toggleSave(id)
      store.report(id, reason: "Spam")
      let loaded = AppStore(storageURL: file, arguments: [])
      XCTAssertTrue(loaded.state.posts[0].saved)
      XCTAssertTrue(loaded.state.hiddenPosts.contains(id))
      XCTAssertEqual(loaded.state.reports.last, "\(id): Spam")
    }
  }

  @MainActor func testUsernameValidationAndNormalization() throws {
    try withStore { store, _ in
      store.enter(username: "  OTHER_Aggie  ")
      XCTAssertEqual(store.state.username, "other_aggie")
      store.enter(username: "bad name")
      XCTAssertEqual(store.state.username, "other_aggie")
      XCTAssertNotNil(store.notice)
    }
  }
}
