import XCTest
@testable import MaroonSocial

@MainActor final class WebPoolSessionStoreTests: XCTestCase {
  private func session(_ token: String) -> WebPoolSession { .init(token: token, endpoint: "https://myxbghfbapbfffkpndwo.supabase.co/functions/v1/web-pool", rules: "maroon-web-pool-3.0.0", expiresAt: Date.now.timeIntervalSince1970 + 3600) }
  func testAccountSwitchDuringCreationNeverPublishesOldCredentialAndRevokesIt() async {
    let store = WebPoolSessionStore(); var owner = "account-a", revoked: [String] = []
    var finish: CheckedContinuation<WebPoolSession, Never>?
    let first = Task { await store.connect(owner: owner, currentOwner: { owner }, create: { await withCheckedContinuation { finish = $0 } }, revoke: { revoked.append($0.token) }) }
    while finish == nil { await Task.yield() }
    owner = "account-b"
    await store.connect(owner: owner, currentOwner: { owner }, create: { self.session("new") }, revoke: { revoked.append($0.token) })
    finish?.resume(returning: session("old")); await first.value
    XCTAssertEqual(store.session?.token, "new"); XCTAssertEqual(store.owner, "account-b")
    XCTAssertEqual(revoked, ["old"]); XCTAssertNil(store.error)
  }
  func testOldRevocationCannotClearNewTableAndDisappearanceClearsImmediately() async {
    let store = WebPoolSessionStore(); var revoke: CheckedContinuation<Void, Never>?
    await store.connect(owner: "a", currentOwner: { "a" }, create: { self.session("old") }, revoke: { _ in })
    store.invalidate { _ in await withCheckedContinuation { revoke = $0 } }
    XCTAssertNil(store.session); XCTAssertNil(store.owner)
    while revoke == nil { await Task.yield() }
    await store.connect(owner: "b", currentOwner: { "b" }, create: { self.session("new") }, revoke: { _ in })
    revoke?.resume(); await Task.yield()
    XCTAssertEqual(store.session?.token, "new"); XCTAssertEqual(store.owner, "b")
  }
  func testAccountChangeBeforeObserverRunsStillRejectsCreatedScope() async {
    let store = WebPoolSessionStore(); var revoked = false
    await store.connect(owner: "old", currentOwner: { "new" }, create: { self.session("old") }, revoke: { _ in revoked = true })
    XCTAssertNil(store.session); XCTAssertTrue(revoked)
  }
}
