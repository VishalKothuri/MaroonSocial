import Foundation

/// Private administrator access for an organization: who manages it, pending
/// invitations and ownership handoff. Public organization cards never carry this.
struct OrganizationAccess: Decodable, Equatable {
  struct Administrator: Decodable, Identifiable, Equatable { let id: String; let username: String; let role: String; let isMe: Bool }
  struct Pending: Decodable, Identifiable, Equatable { let id: String; let username: String; let kind: String; let expiresAt: Date }
  let organizationID: String
  let organizationName: String
  let status: String
  let myRole: String
  let hasOwner: Bool
  let administrators: [Administrator]
  let pending: [Pending]
  var isOwner: Bool { myRole == "owner" }
}
struct OrganizationInvitation: Decodable, Identifiable, Equatable {
  let id: String; let organizationID: String; let organizationName: String; let kind: String; let expiresAt: Date
}
enum OrganizationInvitationKind: String, CaseIterable, Identifiable {
  case admin, ownership
  var id: String { rawValue }
  /// Picker title while composing an invitation.
  var title: String { self == .admin ? "Administrator" : "Transfer ownership" }
  /// Short label on invitation rows.
  var label: String { self == .admin ? "Administrator" : "Ownership" }
  static func label(for raw: String) -> String { Self(rawValue: raw)?.label ?? raw.capitalized }
}
@MainActor struct OrganizationAccessService {
  typealias Transport = @MainActor (String,[String:Any]) async throws -> Data
  let transport: Transport
  init(social:SocialService, fixtureMode:Bool) {
    if fixtureMode { let fixture=OrganizationAccessFixture.shared; transport = { action,payload in try fixture.respond(action,payload) } }
    else { transport = { action,payload in try await social.sendData(endpoint:"social",action:action,payload:payload) } }
  }
  init(transport:@escaping Transport) { self.transport=transport }
  static func normalizedUsername(_ raw:String)->String { var value=raw.trimmingCharacters(in:.whitespacesAndNewlines).lowercased(); if value.hasPrefix("@") { value.removeFirst() }; return value }
  static func validUsername(_ raw:String)->Bool { normalizedUsername(raw).range(of:"^[a-z0-9_]{3,20}$",options:.regularExpression) != nil }
  private var decoder:JSONDecoder { let decoder=JSONDecoder();decoder.dateDecodingStrategy = .secondsSince1970;return decoder }
  func access(organization:String) async throws -> OrganizationAccess {
    let value=try decoder.decode(OrganizationAccess.self,from:await transport("organization.admins",["organization_id":organization]))
    guard value.organizationID==organization, ["owner","admin"].contains(value.myRole), value.administrators.count<=10 else { throw URLError(.badServerResponse) }
    return value
  }
  func incoming() async throws -> [OrganizationInvitation] {
    struct Response:Decodable { let invitations:[OrganizationInvitation] }
    let value=try decoder.decode(Response.self,from:await transport("organization.invitations",[:])).invitations
    guard value.count<=100 else { throw URLError(.badServerResponse) };return value
  }
  /// Returns the invitation ID. Retrying with the same nonce returns the same ID instead of a duplicate.
  func invite(organization:String,username:String,kind:OrganizationInvitationKind,nonce:String) async throws -> String {
    struct Response:Decodable { let changed:Bool;let invitationID:String? }
    let normalized=Self.normalizedUsername(username)
    guard Self.validUsername(normalized) else { throw SocialServiceError(error:"Enter the account username: 3–20 lowercase letters, numbers or underscores.",code:"invalid") }
    let result=try JSONDecoder().decode(Response.self,from:await transport("organization.invite",["organization_id":organization,"username":normalized,"kind":kind.rawValue,"nonce":nonce]))
    guard result.changed,let id=result.invitationID,UUID(uuidString:id) != nil else { throw URLError(.badServerResponse) };return id
  }
  func revoke(organization:String,invitation:String) async throws { try await mutate("organization.revoke",["organization_id":organization,"invitation_id":invitation]) }
  func remove(organization:String,administratorKey:String) async throws { try await mutate("organization.remove",["organization_id":organization,"administrator_key":administratorKey]) }
  func leave(organization:String) async throws { try await mutate("organization.leave",["organization_id":organization]) }
  func accept(invitation:String) async throws { try await mutate("organization.accept",["invitation_id":invitation]) }
  func decline(invitation:String) async throws { try await mutate("organization.decline",["invitation_id":invitation]) }
  private func mutate(_ action:String,_ payload:[String:Any]) async throws {
    struct Response:Decodable { let changed:Bool }
    guard try JSONDecoder().decode(Response.self,from:await transport(action,payload)).changed else { throw URLError(.badServerResponse) }
  }
}
/// Isolated UI-test fixture: one managed organization plus one incoming invitation, kept in memory for the launch.
@MainActor final class OrganizationAccessFixture {
  static let shared=OrganizationAccessFixture()
  static let managedOrganization=SocialOrganization(id:"demo-org-managed",name:"Aggie Robotics",about:"Build season meetings, outreach and demo days.",status:"verified",followed:true,canManage:true)
  static let invitingOrganization=SocialOrganization(id:"demo-org-inviting",name:"Maroon Makers",about:"Weekly maker nights in the Engineering Innovation Center.",status:"verified",followed:false,canManage:false)
  private var pending:[[String:Any]]=[]
  private var incoming:[[String:Any]]=[["id":"demo-invitation","organizationID":invitingOrganization.id,"organizationName":invitingOrganization.name,"kind":"admin","expiresAt":Date.now.addingTimeInterval(6*86400).timeIntervalSince1970]]
  private var usedNonces:[String:String]=[:]
  func respond(_ action:String,_ payload:[String:Any]) throws -> Data {
    let unavailable=SocialServiceError(error:"Administrator changes are unavailable in this test session.",code:"unavailable")
    var value:[String:Any]
    switch action {
    case "organization.admins":
      guard payload["organization_id"] as? String==Self.managedOrganization.id else { throw unavailable }
      value=["organizationID":Self.managedOrganization.id,"organizationName":Self.managedOrganization.name,"status":"verified","myRole":"owner","hasOwner":true,
             "administrators":[["id":"demo-admin-me","username":"demo_owner","role":"owner","isMe":true],["id":"demo-admin-sage","username":"demo_sage","role":"admin","isMe":false]],"pending":pending]
    case "organization.invitations": value=["invitations":incoming]
    case "organization.invite":
      guard let username=payload["username"] as? String,let nonce=payload["nonce"] as? String,let kind=payload["kind"] as? String else { throw unavailable }
      if let id=usedNonces[nonce] { value=["changed":true,"invitationID":id];break }
      guard username != "demo_owner",username != "demo_sage" else { throw SocialServiceError(error:"Ownership can only be offered to an accepted administrator; existing administrators do not need another invitation.",code:"invalid") }
      guard !pending.contains(where:{ $0["username"] as? String==username && $0["kind"] as? String==kind }) else { throw SocialServiceError(error:"Revoke the existing invitation before sending another.",code:"invalid") }
      let id=UUID().uuidString;usedNonces[nonce]=id
      pending.append(["id":id,"username":username,"kind":kind,"expiresAt":Date.now.addingTimeInterval(7*86400).timeIntervalSince1970]);value=["changed":true,"invitationID":id]
    case "organization.revoke": pending.removeAll { $0["id"] as? String==payload["invitation_id"] as? String };value=["changed":true]
    case "organization.accept","organization.decline": incoming.removeAll { $0["id"] as? String==payload["invitation_id"] as? String };value=["changed":true]
    default: throw unavailable
    }
    return try JSONSerialization.data(withJSONObject:value)
  }
}
