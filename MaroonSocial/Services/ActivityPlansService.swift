import Foundation
import ImageIO
import MaroonCore

struct StudySeriesInfo: Decodable {
  struct Occurrence: Decodable, Identifiable { let id: String; let starts: Date; let cancelled: Bool }
  let isSeries: Bool
  let canManage: Bool?
  let seriesID: String?
  let occurrences: [Occurrence]?
  enum CodingKeys: String,CodingKey { case isSeries = "is_series", canManage = "can_manage", seriesID = "series_id", occurrences }
}
@MainActor struct ActivityPlansService {
  typealias Transport = @MainActor (String,[String:Any]) async throws -> Data
  let transport: Transport
  init(social:SocialService, fixtureMode:Bool) {
    transport = { action,payload in
      guard !fixtureMode else { throw SocialServiceError(error:"Publishing and recurring plans require a connected account.",code:"unavailable") }
      return try await social.sendData(endpoint:"activity-plans",action:action,payload:payload)
    }
  }
  init(transport:@escaping Transport) { self.transport=transport }
  func createSeries(_ payload:[String:Any]) async throws -> [String] {
    struct Response:Decodable { let activity_ids:[String] }
    let result=try JSONDecoder().decode(Response.self,from:await transport("series.create",payload))
    guard (2...8).contains(result.activity_ids.count) else { throw URLError(.badServerResponse) }
    return result.activity_ids
  }
  func series(activity:String,cancelFuture:Bool=false) async throws -> StudySeriesInfo {
    let decoder=JSONDecoder();decoder.dateDecodingStrategy = .secondsSince1970
    return try decoder.decode(StudySeriesInfo.self,from:await transport(cancelFuture ? "series.cancel_future":"series.info",["activity_id":activity]))
  }
  func publish(_ payload:[String:Any]) async throws -> String {
    struct Response:Decodable { let activity_id:String }
    let id=try JSONDecoder().decode(Response.self,from:await transport("promotion.create",payload)).activity_id
    guard UUID(uuidString:id) != nil else { throw URLError(.badServerResponse) };return id
  }
  func savePoster(_ data:Data?,activity:String) async throws {
    var payload:[String:Any]=["activity_id":activity];if let data { guard data.count<=2_000_000 else { throw MediaCompression.Failure.exportFailed };payload["data"]=data.base64EncodedString() }
    struct Response:Decodable { let saved:Bool }
    guard try JSONDecoder().decode(Response.self,from:await transport(data == nil ? "poster.remove":"poster.upload",payload)).saved else { throw URLError(.badServerResponse) }
  }
  func poster(activity:String) async throws -> Data? {
    struct Response:Decodable { let has_poster:Bool;let media_data:String? }
    let result=try JSONDecoder().decode(Response.self,from:await transport("poster.read",["activity_id":activity]))
    guard result.has_poster else { return nil }
    guard let encoded=result.media_data,let bytes=Data(base64Encoded:encoded),bytes.count<=2_000_000 else { throw URLError(.badServerResponse) };return bytes
  }
  static func weeklyDates(start:Date,weeks:Int)->[Date] {
    guard (1...8).contains(weeks)else{return[]}
    var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:"America/Chicago")!
    return (0..<weeks).compactMap { calendar.date(byAdding:.day,value:$0*7,to:start) }
  }
  static func preparePoster(_ data:Data) async throws -> MediaAttachment {
    guard data.count<=MediaCompression.maximumInputBytes else{throw MediaCompression.Failure.inputTooLarge}
    let cg=try await Task.detached(priority:.userInitiated){
      guard let source=CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false]as CFDictionary),let image=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:1600]as CFDictionary)else{throw MediaCompression.Failure.unsupported};return image
    }.value
    let media=try await MediaCompression.jpeg(cg)
    guard media.data.count<=2_000_000 else{throw MediaCompression.Failure.exportFailed};return media.attachment
  }
}
