import XCTest
@testable import MaroonSocial

@MainActor final class SocialServiceTests: XCTestCase {
  @MainActor private final class MemoryCredentials {
    var token: String? = String(repeating: "a", count: 64)
    var pending = false
    var failMarker = false
    var store: SocialCredentialStore {
      SocialCredentialStore(read: { self.token }, save: { self.token = $0 },
        deletionPending: { self.pending }, markDeletionPending: {
          if self.failMarker { throw SocialServiceError(error: "Keychain unavailable", code: "secure_storage") }
          self.pending = true
        }, clear: { self.token = nil; self.pending = false })
    }
  }

  func testLostDeletionAcknowledgementRecoversAfterRelaunchWithoutRegistering() async throws {
    let memory = MemoryCredentials()
    var deletedRemotely = false
    var actions: [String] = []
    let transport: SocialService.Transport = { _, action, _, token in
      actions.append(action)
      XCTAssertEqual(token, String(repeating: "a", count: 64))
      XCTAssertTrue(memory.pending, "Intent must survive before any destructive request is sent")
      if !deletedRemotely { deletedRemotely = true; throw URLError(.timedOut) }
      throw SocialServiceError(error: "This credential is no longer valid", code: "unauthorized")
    }
    let original = SocialService(credentials: memory.store, transport: transport)
    do { try await original.deleteAccount(); XCTFail("Lost acknowledgement should remain pending") } catch {}
    XCTAssertNotNil(memory.token)
    XCTAssertTrue(memory.pending)
    let relaunched = SocialService(credentials: memory.store, transport: transport)
    do { _ = try await relaunched.connect(username: "previous_account"); XCTFail("Should return to onboarding") }
    catch { XCTAssertEqual((error as? SocialServiceError)?.code, "account_deleted") }
    XCTAssertNil(memory.token)
    XCTAssertFalse(memory.pending)
    XCTAssertEqual(actions, ["account.delete", "account.delete"])
  }

  func testPendingDeletionRetriesWhenFirstRequestNeverReachedServer() async throws {
    let memory = MemoryCredentials()
    var attempts = 0
    let service = SocialService(credentials: memory.store) { _, action, _, _ in
      XCTAssertEqual(action, "account.delete")
      attempts += 1
      if attempts == 1 { throw URLError(.notConnectedToInternet) }
      return Data(#"{"deleted":true}"#.utf8)
    }
    do { try await service.deleteAccount(); XCTFail() } catch {}
    do { _ = try await service.refresh(); XCTFail() }
    catch { XCTAssertEqual((error as? SocialServiceError)?.code, "account_deleted") }
    XCTAssertEqual(attempts, 2)
    XCTAssertNil(memory.token)
    XCTAssertFalse(memory.pending)
  }

  func testSuspendedDeletionDoesNotClearCredentialOrCreateNewAccount() async throws {
    let memory = MemoryCredentials()
    let service = SocialService(credentials: memory.store) { _, action, _, _ in
      XCTAssertEqual(action, "account.delete")
      throw SocialServiceError(error: "Account suspended", code: "forbidden")
    }
    do { try await service.deleteAccount(); XCTFail() }
    catch { XCTAssertEqual((error as? SocialServiceError)?.code, "forbidden") }
    XCTAssertNotNil(memory.token)
    XCTAssertTrue(memory.pending)
    do { _ = try await service.connect(username: "another_name"); XCTFail() }
    catch { XCTAssertEqual((error as? SocialServiceError)?.code, "forbidden") }
    XCTAssertNotNil(memory.token)
  }

  func testUnauthorizedOrdinaryLoginDoesNotAssumeAccountDeletion() async {
    let memory = MemoryCredentials()
    let service = SocialService(credentials: memory.store) { _, action, _, _ in
      XCTAssertEqual(action, "snapshot")
      throw SocialServiceError(error: "Unauthorized", code: "unauthorized")
    }
    do { _ = try await service.connect(username: "name"); XCTFail() }
    catch { XCTAssertEqual((error as? SocialServiceError)?.code, "unauthorized") }
    XCTAssertNotNil(memory.token)
    XCTAssertFalse(memory.pending)
  }

  func testUnpersistedDeletionIntentNeverStartsRemoteDeletion() async {
    let memory = MemoryCredentials()
    memory.failMarker = true
    var sent = false
    let service = SocialService(credentials: memory.store) { _, _, _, _ in sent = true; return Data() }
    do { try await service.deleteAccount(); XCTFail() }
    catch { XCTAssertEqual((error as? SocialServiceError)?.code, "secure_storage") }
    XCTAssertFalse(sent)
    XCTAssertNotNil(memory.token)
  }

  func testConcurrentDeletionRequestsShareOneRemoteOperation() async throws {
    let memory = MemoryCredentials()
    let sent = expectation(description: "deletion started")
    var release: CheckedContinuation<Data, Never>?
    var requests = 0
    let service = SocialService(credentials: memory.store) { _, _, _, _ in
      requests += 1
      return await withCheckedContinuation { release = $0; sent.fulfill() }
    }
    let first = Task { try await service.deleteAccount() }
    await fulfillment(of: [sent], timeout: 2)
    let second = Task { try await service.deleteAccount() }
    await Task.yield()
    release?.resume(returning: Data(#"{"deleted":true}"#.utf8))
    try await first.value
    try await second.value
    XCTAssertEqual(requests, 1)
    XCTAssertNil(memory.token)
    XCTAssertFalse(memory.pending)
  }
  func testRefreshOfMissingIdentityNeverRegistersReplacementAccount() async {
    let memory = MemoryCredentials(); memory.token = nil
    var requested = false
    let service = SocialService(credentials: memory.store) { _, _, _, _ in requested = true; return Data() }
    do { _ = try await service.connect(username: "cached_username"); XCTFail("Recovery must require explicit sign-in") }
    catch { XCTAssertEqual((error as? SocialServiceError)?.code, "reauthentication_required") }
    XCTAssertFalse(requested)
  }
  func testLostEmailLinkAcknowledgementRetriesSamePairBeforeSnapshot() async throws {
    let memory = MemoryCredentials()
    var linked = false
    var pending = false
    var calls: [String] = []
    var credentials = memory.store
    credentials.linkPending = { pending }
    credentials.markLinkPending = { pending = true }
    credentials.clear = { memory.token = nil; memory.pending = false; pending = false }
    let auth = EmailAuthService(operations: .init(currentUserID: { "email-user" }, sendCode: { _ in }, verifyCode: { _, _ in }, accessToken: { "jwt" }, signOut: {}), availability: { true })
    let transport: SocialService.Transport = { _, action, _, credential in
      calls.append(action)
      if action == "link" {
        XCTAssertEqual(credential, "jwt"); XCTAssertTrue(pending)
        if !linked { linked = true; throw URLError(.timedOut) }
        return Data(#"{"state":"linked"}"#.utf8)
      }
      XCTAssertEqual(action, "snapshot"); XCTAssertEqual(credential, "jwt")
      return Data(#"{}"#.utf8)
    }
    let original = SocialService(credentials: credentials, auth: auth, transport: transport)
    do { _ = try await original.finishEmailLogin(username: "existing", adult: true, linkExisting: true); XCTFail() } catch {}
    XCTAssertNotNil(memory.token); XCTAssertTrue(pending)
    let relaunched = SocialService(credentials: credentials, auth: auth, transport: transport)
    _ = try await relaunched.connect(username: "existing")
    XCTAssertNil(memory.token); XCTAssertFalse(pending)
    XCTAssertEqual(calls, ["link", "link", "snapshot"])
  }
  func testDeletionReceiptCompletesAfterAuthSessionIsGone() async throws {
    let memory = MemoryCredentials(); memory.token = nil; memory.pending = true
    var credentials = memory.store
    credentials.deletionReceipt = { String(repeating: "e", count: 64) }
    let auth = EmailAuthService.unavailableForFixtures()
    var calls: [String] = []
    let service = SocialService(credentials: credentials, auth: auth) { endpoint, action, payload, credential in
      calls.append(action); XCTAssertEqual(endpoint, "auth-account"); XCTAssertNil(credential)
      XCTAssertEqual(payload["receipt"] as? String, String(repeating: "e", count: 64))
      return Data(#"{"deleted":true}"#.utf8)
    }
    do { _ = try await service.connect(username: "deleted"); XCTFail() }
    catch { XCTAssertEqual((error as? SocialServiceError)?.code, "account_deleted") }
    XCTAssertFalse(memory.pending); XCTAssertEqual(calls, ["deletion-status"])
  }

}
