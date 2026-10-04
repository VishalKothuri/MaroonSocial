import CryptoKit
import Foundation
import MaroonCore

enum CompositionIdentity {
  static func image(_ data: Data, identity: String) -> MediaAttachment {
    var attachment = MediaAttachment(kind: .image, data: data)
    attachment.id = identity
    return attachment
  }
  static func signature(_ payload:[String:Any])->String {
    guard let data=try? JSONSerialization.data(withJSONObject:payload,options:[.sortedKeys])else{return ""}
    return SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
  }
  static func requestKey(scope:MessageRequestScope,initialUsername:String)->String {
    switch scope {
    case .post(let id):return "request:post:"+id
    case .reply(let id):return "request:reply:"+id
    case .organization(let id):return "request:organization:"+id
    case .username:return "request:named:"+initialUsername.lowercased().replacingOccurrences(of:"@",with:"").trimmingCharacters(in:.whitespacesAndNewlines)
    }
  }
}
