import Foundation
import ImageIO
import Observation

@Observable @MainActor final class GroupPhotoRevision {
  static let shared = GroupPhotoRevision()
  private(set) var value = 0
  func changed() { value += 1 }
}

@MainActor struct GroupPhotoService {
  typealias Transport = @MainActor (String, [String: Any]) async throws -> Data
  let transport: Transport
  init(social: SocialService, fixtureMode: Bool) {
    transport = { action, payload in
      guard !fixtureMode else { throw SocialServiceError(error: "Group photos require a connected account.", code: "unavailable") }
      return try await social.sendData(endpoint: "group-photos", action: action, payload: payload)
    }
  }
  init(transport: @escaping Transport) { self.transport = transport }
  private struct Response: Decodable { var hasPhoto: Bool?; var mediaData: String?; var saved: Bool?; var attachmentId: String? }
  private func scope(_ room: String, memberKey: String?) -> [String: Any] {
    var value: [String: Any] = ["room_id": room, "scope": memberKey == nil ? "group" : "member"]
    if let memberKey { value["member_key"] = memberKey }
    return value
  }
  func read(room: String, memberKey: String? = nil) async throws -> Data? { try await readPhoto(room:room,memberKey:memberKey)?.data }
  func readPhoto(room: String, memberKey: String? = nil) async throws -> GroupPhotoCache.Photo? {
    let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
    let result = try decoder.decode(Response.self, from: await transport("read", scope(room, memberKey: memberKey)))
    guard result.hasPhoto == true else { return nil }
    guard let encoded = result.mediaData, let data = Data(base64Encoded: encoded), data.count <= 350_000 else { throw URLError(.badServerResponse) }
    guard let id=result.attachmentId else{throw URLError(.badServerResponse)}
    return GroupPhotoCache.Photo(id:id,data:data)
  }
  func save(_ data: Data?, room: String, memberKey: String? = nil) async throws {
    var payload = scope(room, memberKey: memberKey)
    if let data { guard data.count <= 350_000 else { throw MediaCompression.Failure.exportFailed }; payload["data"] = data.base64EncodedString() }
    let result = try JSONDecoder().decode(Response.self, from: await transport(data == nil ? "remove" : "upload", payload))
    guard result.saved == true else { throw URLError(.badServerResponse) }
    GroupPhotoRevision.shared.changed()
  }
  static func prepare(_ data: Data) async throws -> Data {
    guard data.count <= MediaCompression.maximumInputBytes else { throw MediaCompression.Failure.inputTooLarge }
    let bitmap = try await Task.detached(priority: .userInitiated) {
      guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache:false] as CFDictionary),
        let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:512] as CFDictionary) else { throw MediaCompression.Failure.unsupported }
      return image
    }.value
    let result = try await MediaCompression.jpeg(bitmap)
    guard result.data.count <= 350_000 else { throw MediaCompression.Failure.exportFailed }
    return result.data
  }
}
