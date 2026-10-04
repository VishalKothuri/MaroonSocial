import XCTest
@testable import MaroonSocial

@MainActor final class OrganizationAccessServiceTests:XCTestCase {
  func testEveryMethodMapsToItsClientActionAndForwardsOnlyDocumentedKeys()async throws {
    var calls:[(String,[String:Any])]=[]
    let changed=OrganizationAccessService{action,payload in calls.append((action,payload));return Data(#"{"changed":true,"invitationID":"5ec6c5e6-3fcb-4a9e-9d2d-6a7e3f1a2b3c"}"#.utf8)}
    let id=try await changed.invite(organization:"org",username:" @New_Admin ",kind:.ownership,nonce:"nonce-1")
    XCTAssertEqual(id,"5ec6c5e6-3fcb-4a9e-9d2d-6a7e3f1a2b3c")
    try await changed.revoke(organization:"org",invitation:"inv")
    try await changed.remove(organization:"org",administratorKey:"key")
    try await changed.leave(organization:"org")
    try await changed.accept(invitation:"inv")
    try await changed.decline(invitation:"inv")
    XCTAssertEqual(calls.map{$0.0},["organization.invite","organization.revoke","organization.remove","organization.leave","organization.accept","organization.decline"])
    XCTAssertEqual(calls[0].1["organization_id"]as?String,"org");XCTAssertEqual(calls[0].1["username"]as?String,"new_admin");XCTAssertEqual(calls[0].1["kind"]as?String,"ownership");XCTAssertEqual(calls[0].1["nonce"]as?String,"nonce-1")
    XCTAssertEqual(Set(calls[0].1.keys),["organization_id","username","kind","nonce"])
    XCTAssertEqual(calls[1].1["invitation_id"]as?String,"inv");XCTAssertEqual(Set(calls[1].1.keys),["organization_id","invitation_id"])
    XCTAssertEqual(calls[2].1["administrator_key"]as?String,"key");XCTAssertEqual(Set(calls[2].1.keys),["organization_id","administrator_key"])
    XCTAssertEqual(Set(calls[3].1.keys),["organization_id"])
    XCTAssertEqual(Set(calls[4].1.keys),["invitation_id"]);XCTAssertEqual(Set(calls[5].1.keys),["invitation_id"])
  }
  func testAccessDecodesRolesAdministratorsAndPendingInvitations()async throws {
    var calls:[(String,[String:Any])]=[]
    let service=OrganizationAccessService{action,payload in
      calls.append((action,payload))
      return Data(#"{"organizationID":"org","organizationName":"Aggie Robotics","status":"verified","myRole":"owner","hasOwner":true,"administrators":[{"id":"k1","username":"owner_one","role":"owner","isMe":true},{"id":"k2","username":"helper","role":"admin","isMe":false}],"pending":[{"id":"p1","username":"newbie","kind":"admin","expiresAt":1800000000.5}]}"#.utf8)
    }
    let access=try await service.access(organization:"org")
    XCTAssertEqual(calls.first?.0,"organization.admins");XCTAssertEqual(calls.first?.1["organization_id"]as?String,"org")
    XCTAssertTrue(access.isOwner);XCTAssertTrue(access.hasOwner);XCTAssertEqual(access.administrators.map(\.username),["owner_one","helper"])
    XCTAssertEqual(access.administrators[1].id,"k2");XCTAssertFalse(access.administrators[1].isMe)
    XCTAssertEqual(access.pending.first?.expiresAt,Date(timeIntervalSince1970:1800000000.5));XCTAssertEqual(access.pending.first?.kind,"admin")
    let hidden=OrganizationAccessService{_,_ in Data(#"{"organizationID":"org","organizationName":"Aggie Robotics","status":"verified","myRole":"admin","hasOwner":true,"administrators":[],"pending":[]}"#.utf8)}
    let mine=try await hidden.access(organization:"org");XCTAssertFalse(mine.isOwner);XCTAssertTrue(mine.administrators.isEmpty)
    let mismatched=OrganizationAccessService{_,_ in Data(#"{"organizationID":"other","organizationName":"X","status":"verified","myRole":"owner","hasOwner":true,"administrators":[],"pending":[]}"#.utf8)}
    do{_=try await mismatched.access(organization:"org");XCTFail("Foreign organization payload accepted")}catch{}
  }
  func testIncomingDecodesInvitationsAddressedToMe()async throws {
    var action=""
    let service=OrganizationAccessService{name,payload in action=name;XCTAssertTrue(payload.isEmpty);return Data(#"{"invitations":[{"id":"i1","organizationID":"org","organizationName":"Maroon Makers","kind":"ownership","expiresAt":1800000000}]}"#.utf8)}
    let invitations=try await service.incoming()
    XCTAssertEqual(action,"organization.invitations");XCTAssertEqual(invitations.count,1);XCTAssertEqual(invitations[0].organizationName,"Maroon Makers");XCTAssertEqual(invitations[0].kind,"ownership")
    XCTAssertEqual(invitations[0].expiresAt,Date(timeIntervalSince1970:1800000000))
    XCTAssertEqual(OrganizationInvitationKind.label(for:"ownership"),"Ownership");XCTAssertEqual(OrganizationInvitationKind.admin.title,"Administrator")
  }
  func testMutationsRequireChangedTrueAndNeverAcknowledgeThrownErrors()async throws {
    let unchanged=OrganizationAccessService{_,_ in Data(#"{"changed":false}"#.utf8)}
    do{try await unchanged.revoke(organization:"org",invitation:"inv");XCTFail("changed:false acknowledged")}catch{}
    do{try await unchanged.accept(invitation:"inv");XCTFail("changed:false acknowledged")}catch{}
    do{try await unchanged.leave(organization:"org");XCTFail("changed:false acknowledged")}catch{}
    do{_=try await unchanged.invite(organization:"org",username:"someone",kind:.admin,nonce:"n");XCTFail("changed:false acknowledged")}catch{}
    let missingID=OrganizationAccessService{_,_ in Data(#"{"changed":true}"#.utf8)}
    do{_=try await missingID.invite(organization:"org",username:"someone",kind:.admin,nonce:"n");XCTFail("Invitation without an ID acknowledged")}catch{}
    let failing=OrganizationAccessService{_,_ in throw SocialServiceError(error:"Only the organization owner can manage administrator access.",code:"forbidden")}
    do{try await failing.remove(organization:"org",administratorKey:"k");XCTFail("Thrown error acknowledged")}catch{XCTAssertEqual(error.localizedDescription,"Only the organization owner can manage administrator access.")}
    do{try await failing.decline(invitation:"inv");XCTFail("Thrown error acknowledged")}catch{}
    let offline=OrganizationAccessService{_,_ in throw URLError(.notConnectedToInternet)}
    do{_=try await offline.incoming();XCTFail("Offline read acknowledged")}catch{}
  }
  func testInviteValidatesUsernameLocallyBeforeAnyRequest()async {
    var sent=0
    let service=OrganizationAccessService{_,_ in sent+=1;return Data(#"{"changed":true,"invitationID":"5ec6c5e6-3fcb-4a9e-9d2d-6a7e3f1a2b3c"}"#.utf8)}
    for bad in["ab","has space","way_too_long_for_rule_x","héllo"]{do{_=try await service.invite(organization:"org",username:bad,kind:.admin,nonce:"n");XCTFail("Accepted \(bad)")}catch{}}
    XCTAssertEqual(sent,0)
    XCTAssertTrue(OrganizationAccessService.validUsername("@Good_Name1"));XCTAssertEqual(OrganizationAccessService.normalizedUsername("@Good_Name1 "),"good_name1")
  }
  func testFixtureJourneyInvitesRevokesAndAcceptsWithoutNetwork()async throws {
    let fixture=OrganizationAccessFixture()
    let service=OrganizationAccessService{action,payload in try fixture.respond(action,payload)}
    let org=OrganizationAccessFixture.managedOrganization.id
    let initial=try await service.access(organization:org);XCTAssertTrue(initial.pending.isEmpty);XCTAssertTrue(initial.isOwner)
    let first=try await service.invite(organization:org,username:"new_admin",kind:.admin,nonce:"draft")
    let retried=try await service.invite(organization:org,username:"new_admin",kind:.admin,nonce:"draft")
    XCTAssertEqual(retried,first,"Retrying the same draft must not duplicate")
    do{_=try await service.invite(organization:org,username:"new_admin",kind:.admin,nonce:"other");XCTFail("Duplicate pending invitation accepted")}catch{}
    let pending=try await service.access(organization:org).pending;XCTAssertEqual(pending.map(\.username),["new_admin"])
    try await service.revoke(organization:org,invitation:first)
    let afterRevoke=try await service.access(organization:org);XCTAssertTrue(afterRevoke.pending.isEmpty)
    let incoming=try await service.incoming();XCTAssertEqual(incoming.map(\.organizationName),["Maroon Makers"])
    try await service.accept(invitation:"demo-invitation")
    let remaining=try await service.incoming();XCTAssertTrue(remaining.isEmpty)
    do{try await service.leave(organization:org);XCTFail("Fixture faked an unsupported mutation")}catch{}
  }
}
