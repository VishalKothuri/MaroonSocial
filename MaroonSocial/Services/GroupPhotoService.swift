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
  /// Disk layer behind `GroupPhotoCache`'s authorization-scoped memory layer. Every read is still
  /// authorized by the server; only the bytes of an unchanged photo are not sent again.
  var media: MediaStore?
  var downloader: (URL) async throws -> Data = { try await MediaDownload.fetch($0).data }
  init(social: SocialService, fixtureMode: Bool) {
    media = fixtureMode ? nil : social.media
    transport = { action, payload in
      guard !fixtureMode else { throw SocialServiceError(error: "Group photos require a connected account.", code: "unavailable") }
      return try await social.sendData(endpoint: "group-photos", action: action, payload: payload)
    }
  }
  init(transport: @escaping Transport, media: MediaStore? = nil) { self.transport = transport; self.media = media }
  private struct Response: Decodable { var hasPhoto: Bool?; var mediaData: String?; var saved: Bool?; var attachmentId: String?; var unchanged: Bool?; var url: URL? }
  private func scope(_ room: String, memberKey: String?) -> [String: Any] {
    var value: [String: Any] = ["room_id": room, "scope": memberKey == nil ? "group" : "member"]
    if let memberKey { value["member_key"] = memberKey }
    return value
  }
  func read(room: String, memberKey: String? = nil) async throws -> Data? { try await readPhoto(room:room,memberKey:memberKey)?.data }
  func readPhoto(room: String, memberKey: String? = nil) async throws -> GroupPhotoCache.Photo? {
    try await readPhoto(room: room, memberKey: memberKey, offerKnown: true)
  }
  private func readPhoto(room: String, memberKey: String?, offerKnown: Bool) async throws -> GroupPhotoCache.Photo? {
    let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
    var payload = scope(room, memberKey: memberKey)
    let alias = "group-photo|\(room)|\(memberKey ?? "group")"
    // Offer the photo id this device already holds on disk; the server still authorizes the read.
    if offerKnown, let media, let known = media.alias(alias), await media.local(known) != nil { payload["known_attachment_id"] = known }
    let result = try decoder.decode(Response.self, from: await transport("read", payload))
    guard result.hasPhoto == true else { media?.setAlias(alias, id: nil); return nil }
    guard let id = result.attachmentId else { throw URLError(.badServerResponse) }
    if result.unchanged == true {
      guard id == payload["known_attachment_id"] as? String else { throw URLError(.badServerResponse) }
      if let local = await media?.local(id) { return GroupPhotoCache.Photo(id: id, data: local.data) }
      return try await readPhoto(room: room, memberKey: memberKey, offerKnown: false)
    }
    let data: Data
    if let encoded = result.mediaData, let decoded = Data(base64Encoded: encoded) { data = decoded }
    else if let url = result.url { data = try await downloader(url) }
    else { throw URLError(.badServerResponse) }
    guard data.count <= 350_000 else { throw URLError(.badServerResponse) }
    if let media { await media.store(id, MediaContent(data: data, mime: "image/jpeg")); media.setAlias(alias, id: id) }
    return GroupPhotoCache.Photo(id: id, data: data)
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
