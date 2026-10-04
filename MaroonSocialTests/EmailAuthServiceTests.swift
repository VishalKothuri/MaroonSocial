import XCTest
@testable import MaroonSocial

@MainActor final class EmailAuthServiceTests: XCTestCase {
  private final class FakeAuth {
    var user: String?
    var sent: [String] = []
    var verificationFails = false
    var accessTokenCalls = 0
    var operations: EmailAuthService.Operations {
      .init(currentUserID: { self.user }, sendCode: { self.sent.append($0) },
        verifyCode: { _, _ in
          if self.verificationFails { throw SocialServiceError(error: "Invalid or expired code", code: "otp_expired") }
          self.user = "test-auth-user"
        }, accessToken: { self.accessTokenCalls += 1; return "fresh-access-token" }, signOut: { self.user = nil })
    }
  }
  func testUnavailableGateDoesNotSendCode() async {
    let fake = FakeAuth()
    let service = EmailAuthService(operations: fake.operations, availability: { false })
    let sent = await service.requestCode("person@example.org")
    XCTAssertFalse(sent); XCTAssertTrue(fake.sent.isEmpty); XCTAssertFalse(service.codeSent)
    XCTAssertFalse(service.signedIn); XCTAssertNotNil(service.error)
  }
  func testOTPLoginNormalizesEmailAndDoesNotGrantUniversityVerification() async throws {
    let fake = FakeAuth()
    let service = EmailAuthService(operations: fake.operations, availability: { true })
    let sent = await service.requestCode("  Person@Example.ORG  ")
    XCTAssertTrue(sent); XCTAssertEqual(fake.sent, ["person@example.org"])
    XCTAssertTrue(service.codeSent); XCTAssertFalse(service.signedIn)
    let verified = await service.verifyCode("123456")
    XCTAssertTrue(verified); XCTAssertTrue(service.signedIn); XCTAssertFalse(service.codeSent)
    let token = try await service.accessToken()
    XCTAssertEqual(token, "fresh-access-token"); XCTAssertEqual(fake.accessTokenCalls, 1)
  }
  func testWrongCodeKeepsChallengeAndResendCooldown() async {
    let fake = FakeAuth(); fake.verificationFails = true
    let service = EmailAuthService(operations: fake.operations, availability: { true })
    _ = await service.requestCode("person@example.org")
    let deadline = service.resendAfter
    let verified = await service.verifyCode("000000")
    XCTAssertFalse(verified); XCTAssertTrue(service.codeSent); XCTAssertFalse(service.signedIn)
    XCTAssertEqual(service.resendAfter, deadline)
    let resent = await service.requestCode("person@example.org")
    XCTAssertFalse(resent); XCTAssertEqual(fake.sent.count, 1)
  }
  func testDelayedAvailabilityCannotSendAfterSignOut() async throws {
    let fake = FakeAuth()
    let started = expectation(description: "availability started")
    var resume: CheckedContinuation<Bool, Never>?
    let service = EmailAuthService(operations: fake.operations, availability: {
      await withCheckedContinuation { resume = $0; started.fulfill() }
    })
    let request = Task { await service.requestCode("person@example.org") }
    await fulfillment(of: [started], timeout: 2)
    try await service.signOutLocally()
    resume?.resume(returning: true)
    let sent = await request.value
    XCTAssertFalse(sent); XCTAssertTrue(fake.sent.isEmpty); XCTAssertFalse(service.codeSent)
  }
  func testRecoverableSessionIsReadFromProviderAndLogoutClearsIt() async throws {
    let fake = FakeAuth(); fake.user = "restored-user"
    let service = EmailAuthService(operations: fake.operations, availability: { false })
    XCTAssertTrue(service.signedIn)
    try await service.signOutLocally()
    XCTAssertFalse(service.signedIn); XCTAssertNil(fake.user)
  }
  func testLogoutWaitsForLateOTPAndThenRemovesItsSession() async throws {
    let fake = FakeAuth()
    let started = expectation(description: "verification started")
    var resume: CheckedContinuation<Void, Never>?
    var operations = fake.operations
    operations.verifyCode = { _, _ in
      await withCheckedContinuation { resume = $0; started.fulfill() }
      fake.user = "late-session"
    }
    let service = EmailAuthService(operations: operations, availability: { true })
    _ = await service.requestCode("person@example.org")
    let verification = Task { await service.verifyCode("123456") }
    await fulfillment(of: [started], timeout: 2)
    let logout = Task { try await service.signOutLocally() }
    await Task.yield()
    resume?.resume()
    let accepted = await verification.value
    try await logout.value
    XCTAssertFalse(accepted); XCTAssertFalse(service.signedIn); XCTAssertNil(fake.user)
  }
  func testTokenRefreshCannotReturnTokenAfterLogout() async throws {
    let fake = FakeAuth(); fake.user = "previous-session"
    let started = expectation(description: "refresh started")
    var resume: CheckedContinuation<String, Never>?
    var operations = fake.operations
    operations.accessToken = { await withCheckedContinuation { resume = $0; started.fulfill() } }
    let service = EmailAuthService(operations: operations, availability: { true })
    let refresh = Task { try await service.accessToken() }
    await fulfillment(of: [started], timeout: 2)
    try await service.signOutLocally()
    resume?.resume(returning: "stale-access-token")
    do { _ = try await refresh.value; XCTFail("Stale token escaped after logout") } catch is CancellationError {} catch { XCTFail("Unexpected error") }
    XCTAssertFalse(service.signedIn)
  }
  func testFixtureAuthNeverRestoresSessionAndAlwaysDisablesDelivery() async {
    let service = EmailAuthService.unavailableForFixtures()
    await service.checkAvailability()
    XCTAssertFalse(service.enabled); XCTAssertFalse(service.signedIn); XCTAssertNil(service.userID)
  }

}
