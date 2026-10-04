import Foundation
import ImageIO
import MaroonCore
import Observation
import UIKit

struct SharedMemeFailure: LocalizedError {
  var message: String
  var errorDescription: String? { message }
}

/// A meme a member chose to share with everyone. The server never returns who
/// shared it; only the picture, a short title and its dimensions.
struct SharedMeme: Identifiable, Equatable, Decodable {
  var id: String
  var title: String
  var mime: String
  var width: Int
  var height: Int
  var createdAt: String?
  enum CodingKeys: String, CodingKey { case id, title, mime, width, height, createdAt = "created_at" }
  var aspectRatio: CGFloat { width > 0 && height > 0 ? CGFloat(width) / CGFloat(height) : 1 }
}

/// KLIPY has no upload API, so shared creations live in the app's own private
/// media bucket behind the social edge function (meme.publish/list/read/report).
@Observable @MainActor final class SharedMemeService {
  typealias Transport = @MainActor (String, [String: Any]) async throws -> Data
  struct Page: Decodable {
    var memes: [SharedMeme]
    var hasNext: Bool
    enum CodingKeys: String, CodingKey { case memes, hasNext = "has_next" }
  }
  struct Published: Decodable {
    var memeID: String
    enum CodingKeys: String, CodingKey { case memeID = "meme_id" }
  }
  struct Content: Decodable {
    var mime: String?
    var mediaData: String
    enum CodingKeys: String, CodingKey { case mime, mediaData = "media_data" }
  }
  static let pageSize = 24
  static let maximumBytes = 5_000_000
  private let transport: Transport
  private var generation = 0
  private var page = 0
  private var loadedQuery: String?
  private var cache: [String: Data] = [:]
  private(set) var items: [SharedMeme] = []
  private(set) var loading = false
  private(set) var hasNext = false
  private(set) var error: String?

  init(social: SocialService, fixtureMode: Bool) {
    if fixtureMode { let fixture = SharedMemeFixture.shared; transport = { action, payload in try fixture.respond(action, payload) } }
    else { transport = { action, payload in try await social.sendData(endpoint: "social", action: action, payload: payload) } }
  }
  init(transport: @escaping Transport) { self.transport = transport }

  func cancel() { generation += 1; loading = false }
  func load(query: String, more: Bool = false) async {
    let text = Self.normalizedQuery(query)
    if more && (loading || !hasNext || loadedQuery != text) { return }
    generation += 1; let epoch = generation; loading = true; error = nil
    if !more { items = []; page = 0; hasNext = false; loadedQuery = text }
    let next = more ? page + 1 : 1
    do {
      var payload: [String: Any] = ["page": next]
      if !text.isEmpty { payload["query"] = text }
      let result = try JSONDecoder().decode(Page.self, from: try await transport("meme.list", payload))
      try Task.checkCancellation(); guard generation == epoch else { return }
      let fresh = result.memes.filter { Self.valid($0) }
      if more { items.append(contentsOf: fresh.filter { meme in !items.contains { $0.id == meme.id } }) } else { items = fresh }
      page = next; hasNext = result.hasNext && !fresh.isEmpty; loading = false
    } catch {
      guard generation == epoch else { return }; loading = false
      if !(error is CancellationError) { self.error = error.localizedDescription }
    }
  }
  /// Call only after the person chose to share; the bytes are the composed
  /// still image already prepared for posting (JPEG or PNG, at most 5 MB).
  func publish(_ attachment: MediaAttachment, title: String = "") async throws -> String {
    guard PhotoPolicy.offersSharing(attachment), attachment.data.count <= Self.maximumBytes else {
      throw SharedMemeFailure(message: "Only a still image can be shared as a meme.")
    }
    let payload: [String: Any] = ["data": attachment.data.base64EncodedString(), "title": String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))]
    let result = try JSONDecoder().decode(Published.self, from: try await transport("meme.publish", payload))
    cache[result.memeID] = attachment.data
    return result.memeID
  }
  func media(for meme: SharedMeme) async throws -> Data {
    if let cached = cache[meme.id] { return cached }
    let content = try JSONDecoder().decode(Content.self, from: try await transport("meme.read", ["meme_id": meme.id]))
    guard let bytes = Data(base64Encoded: content.mediaData), !bytes.isEmpty, bytes.count <= Self.maximumBytes else {
      throw SharedMemeFailure(message: "This meme is no longer available.")
    }
    try KlipyNetwork.validateMedia(bytes)
    if cache.count >= 60 { cache.removeAll() }
    cache[meme.id] = bytes
    return bytes
  }
  func report(_ meme: SharedMeme) async throws {
    _ = try await transport("meme.report", ["meme_id": meme.id, "reason": "Shared meme report"])
    items.removeAll { $0.id == meme.id }; cache[meme.id] = nil
  }
  static func normalizedQuery(_ query: String) -> String { String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60)) }
  static func valid(_ meme: SharedMeme) -> Bool {
    !meme.id.isEmpty && meme.id.count <= 64 && meme.title.count <= 80 && ["image/jpeg", "image/png"].contains(meme.mime)
      && meme.width > 0 && meme.height > 0 && meme.width <= 8192 && meme.height <= 8192
  }
}

/// In-memory stand-in used whenever the app runs on local fixtures, so the
/// share prompt and Community tab work offline with the same JSON shapes.
@MainActor final class SharedMemeFixture {
  static let shared = SharedMemeFixture()
  private var memes: [(meme: SharedMeme, data: Data)] = []
  private var reported: Set<String> = []
  init() {
    for (index, title) in ["Howdy from the quad", "Group chat energy"].enumerated() {
      let width = index == 0 ? 480 : 640, height = index == 0 ? 480 : 360
      let format = UIGraphicsImageRendererFormat(); format.scale = 1
      let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
        UIColor(red: 80 / 255, green: 0, blue: 0, alpha: 1).setFill(); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        UIColor.white.setFill(); context.cgContext.fillEllipse(in: CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
      }
      if let data = image.jpegData(compressionQuality: 0.8) {
        memes.append((SharedMeme(id: "fixture-meme-\(index)", title: title, mime: "image/jpeg", width: width, height: height, createdAt: nil), data))
      }
    }
  }
  func reset() { memes.removeAll { $0.meme.id.hasPrefix("published-") }; reported = [] }
  func respond(_ action: String, _ payload: [String: Any]) throws -> Data {
    switch action {
    case "meme.list":
      let query = (payload["query"] as? String ?? "").lowercased()
      let rows = memes.filter { !reported.contains($0.meme.id) && (query.isEmpty || $0.meme.title.lowercased().contains(query)) }
        .reversed().map { entry -> [String: Any] in ["id": entry.meme.id, "title": entry.meme.title, "mime": entry.meme.mime, "width": entry.meme.width, "height": entry.meme.height] }
      return try JSONSerialization.data(withJSONObject: ["memes": rows, "has_next": false])
    case "meme.publish":
      guard let encoded = payload["data"] as? String, let data = Data(base64Encoded: encoded), !data.isEmpty,
        let source = CGImageSourceCreateWithData(data as CFData, nil),
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
        let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int else {
        throw SharedMemeFailure(message: "Choose a valid JPEG or PNG.")
      }
      let title = String((payload["title"] as? String ?? "").prefix(80))
      let id = "published-\(memes.count + 1)"
      memes.append((SharedMeme(id: id, title: title.isEmpty ? "Shared from a post" : title, mime: data.first == 0x89 ? "image/png" : "image/jpeg", width: width, height: height, createdAt: nil), data))
      return try JSONSerialization.data(withJSONObject: ["meme_id": id])
    case "meme.read":
      guard let id = payload["meme_id"] as? String, let entry = memes.first(where: { $0.meme.id == id }), !reported.contains(id) else {
        throw SharedMemeFailure(message: "This meme is no longer available.")
      }
      return try JSONSerialization.data(withJSONObject: ["meme_id": id, "mime": entry.meme.mime, "media_data": entry.data.base64EncodedString()])
    case "meme.report":
      if let id = payload["meme_id"] as? String { reported.insert(id) }
      return try JSONSerialization.data(withJSONObject: ["ok": true, "removed": true])
    default:
      throw SharedMemeFailure(message: "Unknown meme action.")
    }
  }
}
