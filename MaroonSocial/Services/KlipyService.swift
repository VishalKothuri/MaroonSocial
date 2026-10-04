import Foundation
import ImageIO
import MaroonCore
import Observation
import UIKit

struct KlipyFailure: LocalizedError {
  var message: String
  var errorDescription: String? { message }
}

/// No social account identifier or credential is sent to KLIPY.
@Observable @MainActor final class KlipyService {
  enum Category: String, CaseIterable, Identifiable { case memes = "static-memes", gifs
    var id: String { rawValue }; var title: String { self == .memes ? "Memes" : "GIFs" }
  }
  struct Item: Identifiable, Equatable {
    var id: String; var title: String; var reference: KlipyReference?
    var adHTML: String?; var adHeight: Double?
    var width: Int?; var height: Int?
    var aspectRatio: CGFloat {
      guard let width, let height, Self.validDimensions(width: width, height: height) else { return 1 }
      return CGFloat(width) / CGFloat(height)
    }
    static func validDimensions(width: Int, height: Int) -> Bool {
      width > 0 && height > 0 && width <= 8192 && height <= 8192 && width * height <= 12_000_000
    }
  }
  struct Page { var items: [Item]; var hasNext: Bool }
  typealias Transport = @MainActor (URLRequest) async throws -> Data
  private let key: String?
  private let customerID: String
  private let transport: Transport
  private var generation = 0
  private var page = 0
  private var loadedQuery: String?
  private var loadedCategory: Category?
  private(set) var items: [Item] = []
  private(set) var loading = false
  private(set) var hasNext = false
  private(set) var error: String?
  var available: Bool { key != nil }
  init(key: String? = KlipyService.configuredKey(), customerID: String? = nil, transport: Transport? = nil) {
    self.key = key.flatMap { $0.isEmpty ? nil : $0 }
    self.customerID = customerID ?? Self.installID()
    self.transport = transport ?? { request in try await KlipyNetwork.fetch(request, api: true, limit: 1_500_000) }
  }
  nonisolated static func configuredKey() -> String? {
    guard let url = Bundle.main.url(forResource: "Klipy", withExtension: "json"),
      let data = try? Data(contentsOf: url), let config = try? JSONDecoder().decode(Configuration.self, from: data),
      config.appKey.range(of: "^[A-Za-z0-9_-]{8,200}$", options: .regularExpression) != nil else { return nil }
    return config.appKey
  }
  private struct Configuration: Decodable { var appKey: String }
  private static func installID() -> String {
    let defaults = UserDefaults.standard
    if let id = defaults.string(forKey: "klipy.install.customer") { return id }
    let id = UUID().uuidString; defaults.set(id, forKey: "klipy.install.customer"); return id
  }
  func cancel() { generation += 1; loading = false }
  func load(query: String, category: Category, more: Bool = false) async {
    guard let key else { error = "KLIPY search is awaiting the app’s library key."; return }
    let normalizedQuery = Self.normalizedQuery(query)
    if more && (loading || !hasNext || loadedQuery != normalizedQuery || loadedCategory != category) { return }
    generation += 1; let epoch = generation; loading = true; error = nil
    if !more { items = []; page = 0; hasNext = false; loadedQuery = normalizedQuery; loadedCategory = category }
    let next = more ? page + 1 : 1
    do {
      let request = try Self.searchRequest(key: key, customerID: customerID, query: query, category: category, page: next)
      let result = try Self.decode(try await transport(request), category: category, page: next)
      try Task.checkCancellation(); guard generation == epoch else { return }
      // Provider order is authoritative. Never merge another library or filter results.
      if more { items.append(contentsOf: result.items) } else { items = result.items }
      page = next; hasNext = result.hasNext; loading = false
    } catch {
      guard generation == epoch else { return }; loading = false
      if !(error is CancellationError) { self.error = error is KlipyFailure ? error.localizedDescription : "KLIPY could not load. Check your connection and retry." }
    }
  }
  func share(_ reference: KlipyReference) async {
    guard let key, let category = Category(rawValue: reference.category) else { return }
    var parts = URLComponents(); parts.scheme = "https"; parts.host = "api.klipy.com"
    parts.path = "/api/v1/\(key)/\(category.rawValue)/share/\(reference.slug)"
    guard let url = parts.url else { return }; var request = URLRequest(url: url)
    request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: ["customer_id": customerID])
    _ = try? await transport(request)
  }
  private static func normalizedQuery(_ query: String) -> String { String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(150)) }
  static func searchRequest(key: String, customerID: String, query: String, category: Category, page: Int) throws -> URLRequest {
    var parts = URLComponents(); parts.scheme = "https"; parts.host = "api.klipy.com"
    let text = normalizedQuery(query)
    parts.path = "/api/v1/\(key)/\(category.rawValue)/\(text.isEmpty ? "trending" : "search")"
    parts.queryItems = [URLQueryItem(name: "page", value: String(max(1, page))), .init(name: "per_page", value: "24"), .init(name: "customer_id", value: customerID), .init(name: "locale", value: "us"), .init(name: "content_filter", value: "high")]
    // Contextual layout hints allow provider ad cards to fit the scrolling picker.
    // No advertising identifier, email, location, or social member ID is supplied.
    parts.queryItems?.append(contentsOf: [.init(name: "ad-os", value: "ios"), .init(name: "ad-min-width", value: "140"), .init(name: "ad-max-width", value: String(Int(UIScreen.main.bounds.width - 32))), .init(name: "ad-min-height", value: "50"), .init(name: "ad-max-height", value: "250")])
    if !text.isEmpty { parts.queryItems?.append(.init(name: "q", value: text)) }
    guard let url = parts.url else { throw KlipyFailure(message: "The search could not be prepared.") }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
    request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS \(UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MaroonSocial/0.1", forHTTPHeaderField: "User-Agent")
    return request
  }
  static func decode(_ bytes: Data, category: Category, page: Int = 1) throws -> Page {
    guard bytes.count <= 1_500_000, let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any], root["result"] as? Bool == true,
      let body = root["data"] as? [String: Any], let rows = body["data"] as? [[String: Any]], rows.count <= 100 else { throw KlipyFailure(message: "KLIPY returned an unreadable response. Please retry.") }
    let items = rows.enumerated().map { offset, row -> Item in
      let providerID = (row["id"] as? String) ?? (row["id"] as? NSNumber)?.stringValue ?? "position-\(offset)"
      // Occurrence IDs keep repeated provider items/ads distinct during pagination.
      let id = "\(category.rawValue):\(page):\(offset):\(providerID)"
      let title = String((row["title"] as? String ?? "KLIPY media").prefix(300))
      if row["type"] as? String == "ad" { return Item(id: id, title: "Advertisement", adHTML: row["content"] as? String, adHeight: row["height"] as? Double) }
      guard let slug = row["slug"] as? String, let files = row["file"] as? [String: Any] else { return Item(id: id, title: title) }
      let formats = category == .gifs ? ["gif"] : ["jpg", "jpeg", "png", "gif"]
      func candidates(sizes: [String]) -> [(String, [String: Any])] {
        var values: [(String, [String: Any])] = []
        for size in sizes {
          if let group = files[size] as? [String: Any] {
            for format in formats { if let file = group[format] as? [String: Any] { values.append((format, file)) } }
          }
        }
        for format in formats { if let file = files[format] as? [String: Any] { values.append((format, file)) } }
        if let url = files["url"] as? String { values.append((URL(string: url)?.pathExtension.lowercased() ?? "jpg", files)) }
        return values
      }
      func valid(_ candidate: (String, [String: Any])) -> Bool {
        let file = candidate.1
        guard formats.contains(candidate.0), let url = file["url"] as? String, KlipyNetwork.allowedURL(url, api: false),
          let size = file["size"] as? Int, size > 0, size <= 5_000_000,
          let width = file["width"] as? Int, let height = file["height"] as? Int else { return false }
        return Item.validDimensions(width: width, height: height)
      }
      // Medium/HD content is attached; the small rendition is only for the grid.
      // Every URL remains exactly as returned by KLIPY, including query strings.
      guard let attachment = candidates(sizes: ["md", "hd", "sm", "xs"]).first(where: valid),
        let url = attachment.1["url"] as? String, let size = attachment.1["size"] as? Int,
        slug.count <= 200, !slug.isEmpty else { return Item(id: id, title: title) }
      let preview = candidates(sizes: ["sm", "xs", "md", "hd"]).first(where: valid) ?? attachment
      let format = attachment.0
      let mime = format == "gif" ? "image/gif" : format == "png" ? "image/png" : "image/jpeg"
      return Item(id: id, title: title, reference: KlipyReference(id: providerID, slug: slug, title: title, category: category.rawValue, kind: format == "gif" ? "gif" : "image", mime: mime, url: url, previewURL: preview.1["url"] as? String ?? url, size: size), width: preview.1["width"] as? Int, height: preview.1["height"] as? Int)
    }
    return Page(items: items, hasNext: body["has_next"] as? Bool ?? false)
  }
}

/// Ephemeral, bounded downloads. Every redirect is checked before following it.
enum KlipyNetwork {
  static let maximumBytes = 5_000_000
  static func allowedURL(_ value: String, api: Bool) -> Bool {
    guard value.count <= 3000, let parts = URLComponents(string: value), parts.scheme == "https", let host = parts.host,
      parts.user == nil, parts.password == nil, parts.fragment == nil, parts.port == nil || parts.port == 443 else { return false }
    return api ? host == "api.klipy.com" : ["static.klipy.com", "static1.klipy.com", "static2.klipy.com"].contains(host)
  }
  static func fetch(_ request: URLRequest, api: Bool, limit: Int) async throws -> Data {
    guard let url = request.url, allowedURL(url.absoluteString, api: api) else { throw KlipyFailure(message: "This media address is not supported.") }
    let delegate = RedirectGuard(api: api)
    let configuration = URLSessionConfiguration.ephemeral; configuration.urlCache = nil; configuration.httpCookieStorage = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData; configuration.timeoutIntervalForRequest = 20; configuration.timeoutIntervalForResource = 35
    let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    defer { session.invalidateAndCancel() }
    var prepared = request
    if prepared.value(forHTTPHeaderField: "User-Agent") == nil { prepared.setValue("MaroonSocial/0.1 (iOS)", forHTTPHeaderField: "User-Agent") }
    prepared.setValue(api ? "application/json" : "image/gif,image/png,image/jpeg", forHTTPHeaderField: "Accept")
    let (stream, response) = try await session.bytes(for: prepared)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
      let final = response.url, allowedURL(final.absoluteString, api: api) else {
      let status = (response as? HTTPURLResponse)?.statusCode
      throw KlipyFailure(message: status == 429 ? "KLIPY’s request limit was reached. Try again later." : status == 401 || status == 403 ? "KLIPY’s app key needs attention." : "KLIPY could not load this content. Please retry.")
    }
    guard response.expectedContentLength <= limit else { throw KlipyFailure(message: "Choose media smaller than 5 MB.") }
    var data = Data(); data.reserveCapacity(min(max(0, Int(response.expectedContentLength)), limit))
    for try await byte in stream { try Task.checkCancellation(); guard data.count < limit else { throw KlipyFailure(message: "Choose media smaller than 5 MB.") }; data.append(byte) }
    return data
  }
  static func media(_ reference: KlipyReference, preview: Bool = false) async throws -> Data {
    guard reference.provider == "klipy", reference.size > 0, reference.size <= maximumBytes,
      let url = URL(string: preview ? reference.previewURL : reference.url) else { throw KlipyFailure(message: "This KLIPY attachment is unavailable.") }
    let data = try await fetch(URLRequest(url: url), api: false, limit: maximumBytes)
    try validateMedia(data)
    return data
  }
  static func validateMedia(_ data: Data) throws {
    guard !data.isEmpty, data.count <= maximumBytes, let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
      let type = CGImageSourceGetType(source) as String?, ["public.jpeg", "public.png", "com.compuserve.gif"].contains(type) else { throw KlipyFailure(message: "This item is not a supported photo or GIF.") }
    let count = CGImageSourceGetCount(source); guard count > 0, count <= 80 else { throw KlipyFailure(message: "Choose a shorter GIF (up to 80 frames).") }
    var pixels = 0; var duration = 0.0
    for index in 0..<count {
      guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
        let width = props[kCGImagePropertyPixelWidth as String] as? Int, let height = props[kCGImagePropertyPixelHeight as String] as? Int,
        width > 0, height > 0, width <= 8192, height <= 8192 else { throw KlipyFailure(message: "This image is damaged or too large.") }
      pixels += width * height
      if let gif = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
        duration += max(0.02, (gif[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double) ?? (gif[kCGImagePropertyGIFDelayTime as String] as? Double) ?? 0.1)
      }
      guard pixels <= 12_000_000, duration <= 15 else { throw KlipyFailure(message: "Choose a smaller image or a GIF shorter than 15 seconds.") }
    }
  }
  final class RedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let api: Bool
    init(api: Bool) { self.api = api }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
      completionHandler(request.url.map { KlipyNetwork.allowedURL($0.absoluteString, api: api) } == true ? request : nil)
    }
  }
}
