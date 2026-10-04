import XCTest
@testable import MaroonSocial

@MainActor final class VerificationServiceTests: XCTestCase {
  func testUnconfiguredProviderDoesNotClaimVerifiedOrCreateChallenge() async {
    let service = VerificationService { _, _ in Data(#"{"enabled":false,"verified":false,"message":"Email delivery is not configured."}"#.utf8) }
    await service.refresh()
    XCTAssertEqual(service.status?.enabled, false)
    XCTAssertEqual(service.status?.verified, false)
    XCTAssertNil(service.challengeID)
  }
  func testWrongCodeRetainsChallengeUntilFiveAttempts() async {
    let service = VerificationService { action, _ in
      if action == "confirm" { throw SocialServiceError(error: "Invalid code", code: "invalid_code") }
      return Data(#"{"enabled":true,"verified":false,"challenge_id":"challenge","expires_in":600}"#.utf8)
    }
    _ = await service.request(email: "synthetic@tamu.edu")
    _ = await service.confirm(code: "123456")
    XCTAssertEqual(service.challengeID, "challenge")
    for _ in 0..<4 { _ = await service.confirm(code: "123456") }
    XCTAssertNil(service.challengeID)
    XCTAssertEqual(service.status?.verified, false)
  }
  func testCancelledDelayedRequestCannotReopenChallenge() async {
    let sent = expectation(description: "request sent")
    var release: CheckedContinuation<Data, Never>?
    var cancelled: [String] = []
    let service = VerificationService { action, payload in
      if action == "request" { return await withCheckedContinuation { release = $0; sent.fulfill() } }
      if action == "cancel", let id = payload["challenge_id"] as? String { cancelled.append(id) }
      return Data(#"{"enabled":true,"verified":false}"#.utf8)
    }
    let request = Task { await service.request(email: "synthetic@tamu.edu") }
    await fulfillment(of: [sent], timeout: 2)
    await service.cancel()
    release?.resume(returning: Data(#"{"enabled":true,"verified":false,"challenge_id":"old","expires_in":600}"#.utf8))
    let success = await request.value
    XCTAssertFalse(success)
    XCTAssertNil(service.challengeID)
    XCTAssertEqual(cancelled, ["old"])
  }
  func testExpiredChallengeRequiresNewCodeWithoutSendingGuess() async {
    var confirms = 0
    let service = VerificationService { action, _ in
      if action == "confirm" { confirms += 1 }
      return Data(#"{"enabled":true,"verified":false,"challenge_id":"old","expires_in":-1}"#.utf8)
    }
    _ = await service.request(email: "synthetic@tamu.edu")
    let success = await service.confirm(code: "123456")
    XCTAssertFalse(success)
    XCTAssertNil(service.challengeID)
    XCTAssertEqual(confirms, 0)
  }
}
