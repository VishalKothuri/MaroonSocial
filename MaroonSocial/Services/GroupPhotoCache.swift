import Foundation
import MaroonCore
import Observation

/// Memory only. Scope authorizations come from the current account snapshot;
/// revoked memberships cannot render a cached image while a request is pending.
@Observable @MainActor final class GroupPhotoCache {
  static let shared = GroupPhotoCache()
  struct Scope:Hashable {
    let owner:String
    let room:String
    let member:String?
    var publicPreview=false
    var revision=0
  }
  struct Photo:Sendable { let id:String; let data:Data }
  private struct Entry { let imageKey:String?; let expires:Date }
  private final class Bytes:NSObject { let data:Data;init(_ data:Data){self.data=data} }
  private let bytes=NSCache<NSString,Bytes>()
  private var entries:[Scope:Entry]=[:]
  private struct Request { let id:UUID;let task:Task<Photo?,Error> }
  private var requests:[Scope:Request]=[:]
  private var owner=""
  private var rooms:Set<String>=[]
  private var members:[String:Set<String>]=[:]
  private(set) var authorizationRevision=0
  init(){bytes.totalCostLimit=8_000_000;bytes.countLimit=32}
  func synchronize(owner:String,conversations:[Conversation],metadata:[String:SocialConversationMeta]) {
    let roomIDs=Set(conversations.map(\.id))
    let covers=Set(metadata.values.filter{$0.kind=="group" && roomIDs.contains($0.id)}.map(\.id))
    var identities:[String:Set<String>]=[:]
    for conversation in conversations where !conversation.request && covers.contains(conversation.id) {
      let roster=metadata[conversation.id]?.members ?? []
      var keys=Set(roster.filter{$0.status=="accepted"}.compactMap(\.memberKey))
      if roster.contains(where:{$0.status=="accepted" && $0.isMe==true}) {keys.insert("self")}
      identities[conversation.id]=keys
    }
    if self.owner != owner { clear();self.owner=owner }
    guard rooms != covers || members != identities else{return}
    let removed=rooms.subtracting(covers)
    rooms=covers;members=identities;authorizationRevision+=1
    for scope in Array(entries.keys) where !allows(scope) || removed.contains(scope.room) {evict(scope)}
    for scope in Array(requests.keys) where !allows(scope) || removed.contains(scope.room) {requests.removeValue(forKey:scope)?.task.cancel()}
  }
  func allows(_ scope:Scope)->Bool {
    guard scope.owner==owner else{return false}
    if let member=scope.member{return members[scope.room]?.contains(member)==true}
    return scope.publicPreview || rooms.contains(scope.room)
  }
  func clear(){for request in requests.values{request.task.cancel()};requests=[:];entries=[:];bytes.removeAllObjects();owner="";rooms=[];members=[:];authorizationRevision+=1}
  private func evict(_ scope:Scope){if let key=entries.removeValue(forKey:scope)?.imageKey{bytes.removeObject(forKey:key as NSString)}}
  func load(_ scope:Scope,now:Date = .now,fetch:@escaping @MainActor ()async throws->Photo?)async throws->Data? {
    guard allows(scope)else{throw URLError(.userAuthenticationRequired)}
    if let entry=entries[scope],entry.expires>now {
      if let key=entry.imageKey,let cached=bytes.object(forKey:key as NSString){return cached.data}
      if entry.imageKey==nil{return nil}
    }
    if let existing=requests[scope]{let photo=try await existing.task.value;guard !existing.task.isCancelled,allows(scope)else{throw URLError(.userAuthenticationRequired)};return photo?.data}
    let requestID=UUID()
    let task=Task {try await fetch()};requests[scope]=Request(id:requestID,task:task)
    do {
      let photo=try await task.value
      if requests[scope]?.id==requestID {requests.removeValue(forKey:scope)}
      guard !task.isCancelled,allows(scope)else{throw URLError(.userAuthenticationRequired)}
      evict(scope)
      let key=photo.map{"\(scope.owner):\(scope.room):\(scope.member ?? "group"):\(scope.revision):\($0.id)"}
      if let photo,let key{bytes.setObject(Bytes(photo.data),forKey:key as NSString,cost:photo.data.count)}
      entries[scope]=Entry(imageKey:key,expires:now.addingTimeInterval(30))
      if entries.count>128,let oldest=entries.min(by:{$0.value.expires<$1.value.expires})?.key{evict(oldest)}
      return photo?.data
    }catch{if requests[scope]?.id==requestID {requests.removeValue(forKey:scope);evict(scope)};throw error}
  }
}
