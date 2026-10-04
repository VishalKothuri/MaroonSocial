import XCTest
import MaroonCore
@testable import MaroonSocial

@MainActor final class AppStoreAccountBoundaryTests: XCTestCase {
  private func snapshot() throws -> Data {
    try JSONSerialization.data(withJSONObject: ["snapshot": ["username":"old_account","nsfwEnabled":true,"karma":99,
      "posts":[],"courses":[],"activities":[],"conversations":[],"ownPostIDs":[],"ownCommentIDs":[],"ownMessageIDs":[],
      "conversationMeta":[],"attachments":[],"organizations":[],"savedEvents":[]]])
  }
  private func makeStore(transport: @escaping SocialService.Transport) -> (AppStore, URL) {
    let file=FileManager.default.temporaryDirectory.appending(path:UUID().uuidString).appending(path:"state.json")
    try? FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
    let credentials=SocialCredentialStore(read:{String(repeating:"a",count:64)},save:{_ in},deletionPending:{false},markDeletionPending:{},clear:{})
    let social=SocialService(credentials:credentials,transport:transport)
    let store=AppStore(storageURL:file,arguments:[],socialService:social)
    store.state.username="old_account";store.state.onboarded=true;store.connected=true
    return (store,file.deletingLastPathComponent())
  }
  private func switchAccount(_ store:AppStore) {
    store.state=LocalState();store.state.username="new_account";store.state.onboarded=true
    store.compositions.reset(owner:"replacement-account")
    store.karma=7;store.nsfwEnabled=false;store.connected=false
    store.notice="New account notice";store.connectionError="New account network state"
    // Another operation may already be running for the replacement account.
    store.busy=true;store.syncing=true
  }
  func testOldMutationResponseCannotReplaceAccountOrClearNewOperationState() async throws {
    let started=expectation(description:"mutation sent")
    var release:CheckedContinuation<Data,Never>?
    let (store,directory)=makeStore { _,action,_,_ in
      XCTAssertEqual(action,"post.save")
      return await withCheckedContinuation { release=$0;started.fulfill() }
    }
    defer {try? FileManager.default.removeItem(at:directory)}
    let work=Task {await store.perform("post.save",["post_id":"old-post","saved":true])}
    await fulfillment(of:[started],timeout:2)
    switchAccount(store)
    release?.resume(returning:try snapshot())
    let result=await work.value
    XCTAssertNil(result)
    XCTAssertEqual(store.state.username,"new_account");XCTAssertEqual(store.karma,7)
    XCTAssertFalse(store.nsfwEnabled);XCTAssertFalse(store.connected)
    XCTAssertTrue(store.busy);XCTAssertEqual(store.notice,"New account notice")
    XCTAssertEqual(store.connectionError,"New account network state")
  }
  func testOldRefreshDeletionErrorCannotResetNewAccount() async throws {
    let started=expectation(description:"refresh sent")
    var release:CheckedContinuation<Data,Error>?
    let (store,directory)=makeStore { _,action,_,_ in
      XCTAssertEqual(action,"snapshot")
      return try await withCheckedThrowingContinuation { release=$0;started.fulfill() }
    }
    defer {try? FileManager.default.removeItem(at:directory)}
    let work=Task {await store.refreshAndWait()}
    await fulfillment(of:[started],timeout:2)
    switchAccount(store)
    release?.resume(throwing:SocialServiceError(error:"Old account deleted",code:"account_deleted"))
    await work.value
    XCTAssertEqual(store.state.username,"new_account");XCTAssertTrue(store.state.onboarded)
    XCTAssertEqual(store.compositions.owner,"replacement-account")
    XCTAssertTrue(store.syncing);XCTAssertEqual(store.connectionError,"New account network state")
  }
  func testOldMutationErrorCannotReplaceNewAccountsNotice() async throws {
    let started=expectation(description:"mutation sent")
    var release:CheckedContinuation<Data,Error>?
    let (store,directory)=makeStore { _,_,_,_ in
      try await withCheckedThrowingContinuation { release=$0;started.fulfill() }
    }
    defer {try? FileManager.default.removeItem(at:directory)}
    let work=Task {await store.perform("comment.create",["post_id":"old-post","text":"old draft"])}
    await fulfillment(of:[started],timeout:2)
    switchAccount(store)
    release?.resume(throwing:URLError(.timedOut))
    let result=await work.value
    XCTAssertNil(result);XCTAssertEqual(store.notice,"New account notice");XCTAssertTrue(store.busy)
  }
}
