import XCTest
import MaroonCore
@testable import MaroonSocial

/// Community guidelines: the snapshot status, gating before a send, the server's `guidelines:`
/// refusal, acceptance and the one retry, and a server without guidelines.
@MainActor final class GuidelinesTests: XCTestCase {
  /// Results recorded by sends that run in their own tasks.
  private final class Log { var results: [Bool] = []; var finished = 0 }
  private var directories: [URL] = []
  override func tearDown() {
    directories.forEach { try? FileManager.default.removeItem(at: $0) }
    directories = []
    super.tearDown()
  }
  private static let refusal = SocialServiceError(error: "Review and accept the community guidelines to post.", code: "guidelines")
  private func credentials() -> SocialCredentialStore {
    SocialCredentialStore(read: { String(repeating: "a", count: 64) }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {})
  }
  private func snapshot(guidelines: Any? = nil, resourceID: String? = nil, conversations: [[String: Any]] = [], meta: [[String: Any]] = []) throws -> Data {
    var value: [String: Any] = ["username": "rules_tester", "nsfwEnabled": false, "posts": [], "courses": [], "activities": [],
      "conversations": conversations, "ownPostIDs": [], "ownCommentIDs": [], "ownMessageIDs": [], "conversationMeta": meta,
      "attachments": [], "organizations": [], "savedEvents": [], "serverNow": 500]
    if let guidelines { value["guidelines"] = guidelines }
    var body: [String: Any] = ["snapshot": value]
    if let resourceID { body["resource_id"] = resourceID }
    return try JSONSerialization.data(withJSONObject: body)
  }
  private func file() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    directories.append(directory)
    return directory.appending(path: "social-cache.json")
  }
  private func networkStore(_ transport: @escaping SocialService.Transport) throws -> AppStore {
    let store = AppStore(storageURL: try file(), arguments: [], socialService: SocialService(credentials: credentials(), transport: transport))
    store.state.username = "rules_tester"; store.state.onboarded = true; store.connected = true
    return store
  }
  private static let unaccepted: [String: Any] = ["required": 1, "accepted": NSNull(), "accepted_at": NSNull()]
  private static let accepted: [String: Any] = ["required": 1, "accepted": 1, "accepted_at": "2026-10-07T15:04:05Z"]

  func testSnapshotStatusDecodesAndDecidesTheGate() async throws {
    var status: Any? = Self.unaccepted
    let store = try networkStore { [self] _, _, _, _ in try snapshot(guidelines: status) }
    await store.refresh()
    XCTAssertEqual(store.guidelines, GuidelinesStatus(required: 1, accepted: nil, acceptedAt: nil))
    XCTAssertTrue(store.guidelinesRequired)
    status = Self.accepted
    await store.refresh()
    XCTAssertFalse(store.guidelinesRequired)
    XCTAssertEqual(store.guidelines?.acceptedAt, Date(timeIntervalSince1970: 1_791_385_445))
    XCTAssertEqual(GuidelinesSettingsView.status(store.guidelines).prefix(29), "Accepted version 1 on Oct 7, ")
    // A version bump asks again.
    status = ["required": 2, "accepted": 1, "accepted_at": "2026-10-07T15:04:05Z"]
    await store.refresh()
    XCTAssertTrue(store.guidelinesRequired); XCTAssertEqual(GuidelinesSettingsView.status(store.guidelines), "Not accepted yet")
    // Today's live server: no field, nothing gated.
    status = nil
    await store.refresh()
    XCTAssertNil(store.guidelines); XCTAssertFalse(store.guidelinesRequired)
    XCTAssertEqual(GuidelinesSettingsView.status(nil), "Version \(GuidelinesVersion)")
    // A malformed field reads as a server without guidelines instead of failing the snapshot.
    status = "yes"
    await store.refresh()
    XCTAssertNil(store.guidelines); XCTAssertNil(store.connectionError)
  }

  func testAcceptedAtParsesPostgresAndISOForms() {
    XCTAssertEqual(GuidelinesStatus.date("2026-10-07T15:04:05Z"), Date(timeIntervalSince1970: 1_791_385_445))
    XCTAssertEqual(GuidelinesStatus.date("2026-10-07T15:04:05.250Z")!.timeIntervalSince1970, 1_791_385_445.25, accuracy: 0.001)
    XCTAssertEqual(GuidelinesStatus.date("2026-10-07T15:04:05.123456+00:00")!.timeIntervalSince1970, 1_791_385_445, accuracy: 1)
    XCTAssertNil(GuidelinesStatus.date("yesterday"))
  }

  /// A server without the field gates nothing before a send; only its `guidelines:` answer opens the
  /// sheet. Accepting sends `guidelines.accept {version}` and the send runs again, once.
  func testRefusalOpensTheSheetAndAcceptingRetriesTheSendOnce() async throws {
    var accepted = false
    var creates = 0
    var acceptPayloads: [[String: Any]] = []
    let store = try networkStore { [self] _, action, payload, _ in
      switch action {
      case "snapshot": return try snapshot()
      case "post.create":
        creates += 1
        guard accepted else { throw Self.refusal }
        return try snapshot(resourceID: "new-post")
      case "guidelines.accept":
        acceptPayloads.append(payload); accepted = true
        return try snapshot()
      default: return Data("{}".utf8)
      }
    }
    await store.refresh()
    XCTAssertFalse(store.guidelinesRequired, "A server without guidelines gates nothing locally")
    let gate = GuidelinesGate()
    let log = Log()
    func send() {
      guard !gate.intercept(store, retry: send) else { return }
      Task { @MainActor in
        var posted = false
        let refused = await gate.run(store, retry: send) {
          posted = await store.createPost(text: "First post", anonymous: true, community: .campus, acceptsDM: true)
        }
        if !refused { log.results.append(posted) }
      }
    }
    send()
    for _ in 0..<100 where !gate.presented { try await Task.sleep(for: .milliseconds(10)) }
    XCTAssertTrue(gate.presented, "The refusal opens the sheet")
    XCTAssertNil(store.notice, "No alert on top of the sheet")
    XCTAssertEqual(creates, 1); XCTAssertTrue(log.results.isEmpty)
    // "I agree".
    let failure = await store.acceptGuidelines()
    XCTAssertNil(failure)
    XCTAssertEqual(acceptPayloads.first?["version"] as? Int, 1)
    XCTAssertFalse(store.guidelinesRequired)
    gate.agreed(); XCTAssertFalse(gate.presented)
    gate.dismissed()
    for _ in 0..<100 where log.results.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
    XCTAssertEqual(log.results, [true], "The send ran again once and succeeded")
    XCTAssertEqual(creates, 2)
  }

  func testASecondRefusalAfterAcceptingShowsAnAlertInsteadOfLooping() async throws {
    var creates = 0
    let store = try networkStore { [self] _, action, _, _ in
      switch action {
      case "snapshot", "guidelines.accept": return try snapshot()
      case "post.create": creates += 1; throw Self.refusal
      default: return Data("{}".utf8)
      }
    }
    await store.refresh()
    let gate = GuidelinesGate()
    let log = Log()
    func send() {
      guard !gate.intercept(store, retry: send) else { return }
      Task { @MainActor in
        _ = await gate.run(store, retry: send) { _ = await store.createPost(text: "Again", anonymous: true, community: .campus, acceptsDM: true) }
        log.finished += 1
      }
    }
    send()
    for _ in 0..<100 where log.finished < 1 { try await Task.sleep(for: .milliseconds(10)) }
    XCTAssertTrue(gate.presented)
    _ = await store.acceptGuidelines(); gate.agreed(); gate.dismissed()
    for _ in 0..<100 where log.finished < 2 { try await Task.sleep(for: .milliseconds(10)) }
    XCTAssertEqual(creates, 2)
    XCTAssertFalse(gate.presented, "No second sheet")
    XCTAssertEqual(store.notice, Self.refusal.error)
  }

  func testRefusalOutsideAGateIsAnAlert() async throws {
    let store = try networkStore { [self] _, action, _, _ in
      if action == "comment.create" { throw Self.refusal }
      return try snapshot(guidelines: Self.accepted)
    }
    await store.refresh()
    XCTAssertFalse(store.guidelinesRequired)
    let replied = await store.createComment(postID: "p", text: "Hi", anonymous: true)
    XCTAssertFalse(replied)
    XCTAssertEqual(store.notice, Self.refusal.error)
    XCTAssertTrue(store.guidelinesRequired, "The refusal says this member has not accepted the required version")
  }

  /// A server that reports the status gates before the request goes out.
  func testKnownUnacceptedStatusInterceptsBeforeAnyRequest() async throws {
    var requests: [String] = []
    let store = try networkStore { [self] _, action, _, _ in
      requests.append(action)
      return try snapshot(guidelines: Self.unaccepted)
    }
    await store.refresh()
    let gate = GuidelinesGate()
    var retried = 0
    XCTAssertTrue(gate.intercept(store, retry: { retried += 1 }))
    XCTAssertTrue(gate.presented)
    gate.declined(); gate.dismissed()
    XCTAssertEqual(retried, 0, "Not now keeps the draft and sends nothing")
    XCTAssertEqual(requests, ["snapshot"])
  }

  func testAcceptFailureStaysInTheSheet() async throws {
    let store = try networkStore { [self] _, action, _, _ in
      if action == "guidelines.accept" { throw SocialServiceError(error: "That version of the guidelines isn't available.", code: "invalid") }
      return try snapshot(guidelines: Self.unaccepted)
    }
    await store.refresh()
    let failure = await store.acceptGuidelines()
    XCTAssertEqual(failure, "That version of the guidelines isn't available.")
    XCTAssertTrue(store.guidelinesRequired); XCTAssertNil(store.notice)
  }

  /// "I agree" accepts only a version this build shows, and never one above the server's requirement.
  func testAcceptedVersionIsOneThisBuildShowsAndTheServerAllows() async throws {
    // A build carrying version 2 against a server still requiring 1 accepts 1 (2 would be refused).
    XCTAssertEqual(AppStore.guidelinesVersion(toAccept: 1, build: 2), 1)
    // A build carrying version 1 against a server requiring 2 sends nothing: the app must update.
    XCTAssertNil(AppStore.guidelinesVersion(toAccept: 2, build: 1))
    XCTAssertEqual(AppStore.guidelinesVersion(toAccept: 1, build: 1), 1)
    XCTAssertEqual(AppStore.guidelinesVersion(toAccept: nil, build: 2), 2, "No server status: the build's version")
    var accepts: [Int] = []
    let newer: [String: Any] = ["required": GuidelinesVersion + 1, "accepted": NSNull(), "accepted_at": NSNull()]
    var status: [String: Any] = newer
    let store = try networkStore { [self] _, action, payload, _ in
      if action == "guidelines.accept" { accepts.append(payload["version"] as? Int ?? -1) }
      return try snapshot(guidelines: status)
    }
    await store.refresh()
    XCTAssertTrue(store.guidelinesNeedAppUpdate)
    let failure = await store.acceptGuidelines()
    XCTAssertEqual(failure, AppStore.guidelinesUpdateCopy); XCTAssertEqual(accepts, [], "Nothing is sent for text this build never showed")
    XCTAssertTrue(store.guidelinesRequired)
    status = Self.unaccepted
    await store.refresh()
    XCTAssertFalse(store.guidelinesNeedAppUpdate)
    _ = await store.acceptGuidelines()
    XCTAssertEqual(accepts, [1])
  }

  /// A snapshot read before the acceptance landed does not ask again in this session.
  func testAnOlderSnapshotAfterAcceptingDoesNotAskAgain() async throws {
    // Every snapshot here was read before the acceptance; only the accept answer knows about it.
    let store = try networkStore { [self] _, action, _, _ in
      if action == "guidelines.accept" { return try snapshot(guidelines: Self.accepted) }
      return try snapshot(guidelines: Self.unaccepted)
    }
    await store.refresh()
    XCTAssertTrue(store.guidelinesRequired)
    _ = await store.acceptGuidelines()
    await store.refresh()
    XCTAssertFalse(store.guidelinesRequired)
  }

  /// A chat message refused for the guidelines leaves the outbox (the composer keeps it and sends it
  /// again after "I agree") instead of waiting there as failed.
  func testRefusedChatMessageLeavesTheOutboxAndOpensTheSheet() async throws {
    var sends = 0
    let room: [String: Any] = ["id": "room-1", "title": "Them", "subtitle": "", "messages": [], "request": false, "anonymous": true]
    let meta: [String: Any] = ["id": "room-1", "kind": "dm", "status": "active", "role": "member", "canSend": true, "unread": 0, "lastRead": 0, "pendingOutgoing": false]
    let store = try networkStore { [self] _, action, _, _ in
      if action == "room.send" { sends += 1; throw Self.refusal }
      return try snapshot(conversations: [room], meta: [meta])
    }
    await store.refresh()
    let gate = GuidelinesGate()
    let nonce = UUID().uuidString
    var sent = true
    let refused = await gate.run(store, retry: {}) {
      sent = await store.sendMessage(roomID: "room-1", text: "Hello", media: nil, nonce: nonce)
    }
    XCTAssertTrue(refused); XCTAssertFalse(sent); XCTAssertEqual(sends, 1)
    XCTAssertTrue(gate.presented); XCTAssertNil(store.notice)
    XCTAssertFalse(store.compositions.queue.contains { $0.id == nonce })
  }

  func testFixtureStartsAcceptedUnlessAskedAndAcceptsLocally() async throws {
    let accepted = AppStore(storageURL: try file(), arguments: [])
    XCTAssertFalse(accepted.guidelinesRequired)
    XCTAssertEqual(accepted.guidelines?.accepted, GuidelinesVersion)
    let fresh = AppStore(storageURL: try file(), arguments: [AppStore.guidelinesUnacceptedArgument])
    XCTAssertTrue(fresh.guidelinesRequired)
    let failure = await fresh.acceptGuidelines()
    XCTAssertNil(failure); XCTAssertFalse(fresh.guidelinesRequired)
    XCTAssertNotNil(fresh.guidelines?.acceptedAt)
  }

  func testSupportContactAndFullTextAreTheOnesTheSiteServes() {
    XCTAssertEqual(SupportContact.email, "support@maroonsocial.chat")
    XCTAssertEqual(SupportContact.mailURL.absoluteString, "mailto:support@maroonsocial.chat")
    XCTAssertEqual(CommunityGuidelines.fullTextURL.absoluteString, "https://maroonsocial.chat/guidelines.html")
    XCTAssertEqual(CommunityGuidelines.version, 1)
    XCTAssertTrue(CommunityGuidelines.points.contains { $0.title.contains("988") })
  }
}
