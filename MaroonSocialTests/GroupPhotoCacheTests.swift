import XCTest
import MaroonCore
@testable import MaroonSocial

@MainActor final class GroupPhotoCacheTests:XCTestCase {
  private func setup(_ cache:GroupPhotoCache,owner:String="owner",accepted:Bool=true,includePeer:Bool=true) {
    var chat=Conversation(id:"room",title:"Group",subtitle:"");chat.request = !accepted
    var members=[SocialGroupMember(username:"Alias",role:"owner",status:"accepted",memberKey:"mine",avatar:"gold",isMe:true)]
    if includePeer{members.append(SocialGroupMember(username:"Peer alias",role:"member",status:"accepted",memberKey:"peer",avatar:"sage",isMe:false))}
    let meta=SocialConversationMeta(id:"room",kind:"group",status:"active",role:"owner",canSend:accepted,unread:0,lastRead:0,pendingOutgoing:false,members:accepted ? members:[])
    cache.synchronize(owner:owner,conversations:[chat],metadata:["room":meta])
  }
  func testIdenticalVisibleAvatarsCoalesceAndCacheByPhotoRevision()async throws {
    let cache=GroupPhotoCache();setup(cache)
    let scope=GroupPhotoCache.Scope(owner:"owner",room:"room",member:"peer")
    var fetches=0
    let fetch:@MainActor ()async throws->GroupPhotoCache.Photo?={fetches+=1;try await Task.sleep(for:.milliseconds(25));return .init(id:"photo-v1",data:Data([1]))}
    async let first=cache.load(scope,fetch:fetch)
    async let second=cache.load(scope,fetch:fetch)
    let values=try await(first,second);XCTAssertEqual(values.0,Data([1]));XCTAssertEqual(values.1,Data([1]));XCTAssertEqual(fetches,1)
    _=try await cache.load(scope,fetch:fetch);XCTAssertEqual(fetches,1)
    var changed=scope;changed.revision=1
    _=try await cache.load(changed,fetch:fetch);XCTAssertEqual(fetches,2)
  }
  func testMembershipRemovalAndAccountSwitchImmediatelyRejectCachedIdentity()async throws {
    let cache=GroupPhotoCache();setup(cache)
    let scope=GroupPhotoCache.Scope(owner:"owner",room:"room",member:"peer")
    _=try await cache.load(scope){.init(id:"private",data:Data([1]))}
    setup(cache,includePeer:false);XCTAssertFalse(cache.allows(scope))
    do{_=try await cache.load(scope){XCTFail("Revoked identity triggered network");return nil};XCTFail("Revoked cache read") }catch{}
    setup(cache,owner:"new-owner");XCTAssertFalse(cache.allows(scope))
    let other=GroupPhotoCache.Scope(owner:"new-owner",room:"room",member:"peer")
    var called=false;_=try await cache.load(other){called=true;return nil};XCTAssertTrue(called)
  }
  func testPendingInviteMayReadCoverButNeverMemberPhoto() {
    let cache=GroupPhotoCache();setup(cache,accepted:false)
    XCTAssertTrue(cache.allows(.init(owner:"owner",room:"room",member:nil)))
    XCTAssertFalse(cache.allows(.init(owner:"owner",room:"room",member:"peer")))
    XCTAssertFalse(cache.allows(.init(owner:"owner",room:"private",member:nil)))
    XCTAssertTrue(cache.allows(.init(owner:"owner",room:"public",member:nil,publicPreview:true)))
  }
  func testInFlightRevocationCannotRestoreImageEvenIfTransportIgnoresCancellation()async throws {
    let cache=GroupPhotoCache();setup(cache)
    let scope=GroupPhotoCache.Scope(owner:"owner",room:"room",member:"peer")
    var started=false
    let task=Task{try await cache.load(scope){started=true;try? await Task.sleep(for:.milliseconds(100));return .init(id:"late",data:Data([1]))}}
    while !started{await Task.yield()}
    setup(cache,includePeer:false)
    do{_=try await task.value;XCTFail("Revoked response restored an image")}catch{}
    XCTAssertFalse(cache.allows(scope))
  }
  func testRemovedPublicRoomCoverMustReauthorizeInsteadOfReturningCachedPixels()async throws {
    let cache=GroupPhotoCache();setup(cache)
    let scope=GroupPhotoCache.Scope(owner:"owner",room:"room",member:nil,publicPreview:true)
    _=try await cache.load(scope){.init(id:"cover",data:Data([1]))}
    let previous=cache.authorizationRevision
    cache.synchronize(owner:"owner",conversations:[],metadata:[:])
    XCTAssertGreaterThan(cache.authorizationRevision,previous)
    var fetched=false
    do{_=try await cache.load(scope){fetched=true;throw URLError(.userAuthenticationRequired)};XCTFail("Stale public cover returned after removal")}catch{}
    XCTAssertTrue(fetched)
  }

}
