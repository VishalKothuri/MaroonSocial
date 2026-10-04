import XCTest
import MaroonCore
@testable import MaroonSocial

final class MessageRequestScopeTests: XCTestCase {
  func testPostAndReplyScopeCannotCarryUsernameOrAnonymityOverride() {
    for (scope, key, id) in [(MessageRequestScope.post("post-id"), "post_id", "post-id"), (.reply("reply-id"), "comment_id", "reply-id")] {
      let payload = scope.payload(text: " hello ", username: "DO_NOT_DISCLOSE", nonce: "retry-id")
      XCTAssertTrue(scope.anonymous); XCTAssertFalse(scope.requiresUsername)
      XCTAssertEqual(scope.action, "dm.request"); XCTAssertEqual(payload[key] as? String, id)
      XCTAssertNil(payload["username"]); XCTAssertNil(payload["anonymous"])
      XCTAssertEqual(payload["text"] as? String, "hello"); XCTAssertEqual(payload["nonce"] as? String, "retry-id")
      XCTAssertEqual(payload.count, 3)
    }
  }
  func testNamedAndOrganizationRequestsStaySeparate() {
    let named = MessageRequestScope.username
    XCTAssertFalse(named.anonymous); XCTAssertTrue(named.requiresUsername)
    XCTAssertEqual(named.payload(text: "hello", username: " @Aggie ", nonce: "id")["username"] as? String, "aggie")
    let organization = MessageRequestScope.organization("org")
    XCTAssertFalse(organization.anonymous); XCTAssertEqual(organization.action, "organization.message")
    XCTAssertNil(organization.payload(text: "hello", username: "discard", nonce: "id")["username"])
  }
  func testAnonymousParticipantLabelsNeverRevealStalePayloadUsername() {
    XCTAssertEqual(ChatParticipantLabel.name(author: "private_sender", mine: true, anonymous: true), "You")
    XCTAssertEqual(ChatParticipantLabel.name(author: "private_recipient", mine: false, anonymous: true), "Them")
    XCTAssertEqual(ChatParticipantLabel.name(author: "named_aggie", mine: false, anonymous: false), "@named_aggie")
  }
}

final class MessageDraftSnapshotTests: XCTestCase {
  private func draft() -> MessageDraftSnapshot<String> {
    MessageDraftSnapshot(text: "Meet at Evans", media: MediaAttachment(kind: .image, data: Data([1])), replyID: "first-message", photoSelection: "first-photo", nonce: "first-send")
  }
  func testSuccessfulSendClearsSubmittedContentAndRenewsItsNonce() {
    let submitted = draft()
    let result = submitted.completingSend(current: submitted, succeeded: true)
    XCTAssertEqual(result.text, "")
    XCTAssertNil(result.media); XCTAssertNil(result.photoSelection); XCTAssertNil(result.replyID)
    XCTAssertNotEqual(result.nonce, submitted.nonce)
  }
  func testTextEditsAndReplacementAttachmentAndReplySurviveAnEarlierSend() {
    let submitted = draft()
    var edited = submitted
    edited.text = "Meet at the MSC instead"
    edited.media = MediaAttachment(kind: .gif, data: Data([2]))
    edited.photoSelection = nil; edited.replyID = "second-message"
    let result = submitted.completingSend(current: edited, succeeded: true)
    XCTAssertEqual(result.text, edited.text); XCTAssertEqual(result.media, edited.media)
    XCTAssertEqual(result.replyID, edited.replyID)
    XCTAssertNotEqual(result.nonce, submitted.nonce)
  }
  func testPendingPhotoReplacementIsNotCancelledWhenPreviousSendCompletes() {
    let submitted = draft()
    var loading = submitted
    loading.photoSelection = "replacement-still-loading"
    let result = submitted.completingSend(current: loading, succeeded: true)
    XCTAssertEqual(result.text, "", "The already-sent text can clear independently")
    XCTAssertEqual(result.photoSelection, loading.photoSelection, "Retain the picker task until replacement media is ready")
    XCTAssertEqual(result.media, loading.media)
  }
  func testFailedSendPreservesDraftAndReusesNonceOnlyForUnchangedRetry() {
    let submitted = draft()
    let retry = submitted.completingSend(current: submitted, succeeded: false)
    XCTAssertEqual(retry.nonce, submitted.nonce)
    XCTAssertEqual(retry.text, submitted.text); XCTAssertEqual(retry.media, submitted.media)
    var edited = submitted; edited.text = "Changed after send started"
    let changed = submitted.completingSend(current: edited, succeeded: false)
    XCTAssertEqual(changed.text, edited.text); XCTAssertEqual(changed.media, edited.media)
    XCTAssertNotEqual(changed.nonce, submitted.nonce, "Different content must never reuse the original idempotency token")
  }
}
