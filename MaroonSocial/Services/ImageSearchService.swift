import Foundation
import ImageIO
import Observation
import UIKit
import UniformTypeIdentifiers

struct ImageSearchFailure: LocalizedError {
  var message: String
  var errorDescription: String? { message }
}

/// Google Programmable Search in image mode. The API key and engine ID live in
/// the gitignored ImageSearch.json (see ImageSearch.example.json); a query
/// carries no account identity, and SafeSearch stays on.
@Observable @MainActor final class ImageSearchService {
  struct Item: Identifiable, Equatable {
    var id: String
    var title: String
    var url: String
    var thumbnailURL: String
    var width: Int
    var height: Int
    var source: String
    var aspectRatio: CGFloat { width > 0 && height > 0 ? CGFloat(width) / CGFloat(height) : 1 }
  }
  struct Page { var items: [Item]; var hasNext: Bool }
  struct Configuration: Decodable, Equatable { var apiKey: String; var searchEngineID: String }
  typealias Transport = @MainActor (URLRequest) async throws -> Data
  static let pageSize = 10
  private let configuration: Configuration?
  private let transport: Transport
  private var generation = 0
  private var start = 1
  private var loadedQuery: String?
  private(set) var items: [Item] = []
  private(set) var loading = false
  private(set) var hasNext = false
  private(set) var error: String?
  var available: Bool { configuration != nil }

  init(configuration: Configuration? = ImageSearchService.configured(), transport: Transport? = nil) {
    self.configuration = configuration
    self.transport = transport ?? { request in try await ImageSearchNetwork.fetch(request, limit: 1_000_000) }
  }
  nonisolated static func configured() -> Configuration? {
    guard let url = Bundle.main.url(forResource: "ImageSearch", withExtension: "json"), let data = try? Data(contentsOf: url),
      let config = try? JSONDecoder().decode(Configuration.self, from: data),
      config.apiKey.range(of: "^[A-Za-z0-9_-]{20,200}$", options: .regularExpression) != nil,
      config.searchEngineID.range(of: "^[A-Za-z0-9_:-]{5,200}$", options: .regularExpression) != nil else { return nil }
    return config
  }
  func cancel() { generation += 1; loading = false }
  func load(query: String, more: Bool = false) async {
    guard let configuration else { error = "Image search is awaiting the app’s search key."; return }
    let text = Self.normalizedQuery(query)
    guard !text.isEmpty else { cancel(); items = []; hasNext = false; error = nil; loadedQuery = nil; return }
    if more && (loading || !hasNext || loadedQuery != text) { return }
    generation += 1; let epoch = generation; loading = true; error = nil
    if !more { items = []; start = 1; hasNext = false; loadedQuery = text }
    let next = more ? start + Self.pageSize : 1
    do {
      let request = try Self.searchRequest(configuration: configuration, query: text, start: next)
      let page = try Self.decode(try await transport(request), start: next)
      try Task.checkCancellation(); guard generation == epoch else { return }
      if more { items.append(contentsOf: page.items) } else { items = page.items }
      start = next; hasNext = page.hasNext; loading = false
    } catch {
      guard generation == epoch else { return }; loading = false
      if !(error is CancellationError) { self.error = error is ImageSearchFailure ? error.localizedDescription : "Image search could not load. Check your connection and retry." }
    }
  }
  static func normalizedQuery(_ query: String) -> String { String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)) }
  static func searchRequest(configuration: Configuration, query: String, start: Int) throws -> URLRequest {
    var parts = URLComponents(); parts.scheme = "https"; parts.host = "www.googleapis.com"; parts.path = "/customsearch/v1"
    parts.queryItems = [
      URLQueryItem(name: "key", value: configuration.apiKey), .init(name: "cx", value: configuration.searchEngineID),
      .init(name: "q", value: normalizedQuery(query)), .init(name: "searchType", value: "image"),
      .init(name: "num", value: String(pageSize)), .init(name: "start", value: String(max(1, min(91, start)))),
      .init(name: "safe", value: "active"),
      .init(name: "fields", value: "items(title,link,displayLink,mime,image(thumbnailLink,width,height)),queries(nextPage)")]
    guard let url = parts.url else { throw ImageSearchFailure(message: "The search could not be prepared.") }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
    request.setValue("MaroonSocial/0.1 (iOS)", forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }
  static func decode(_ bytes: Data, start: Int) throws -> Page {
    guard bytes.count <= 1_000_000, let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw ImageSearchFailure(message: "Image search returned an unreadable response. Please retry.")
    }
    if let failure = root["error"] as? [String: Any] {
      let code = failure["code"] as? Int ?? 0
      throw ImageSearchFailure(message: code == 429 ? "Image search’s daily limit was reached. Try again tomorrow." : code == 403 || code == 400 ? "Image search’s key needs attention." : "Image search could not load. Please retry.")
    }
    let rows = root["items"] as? [[String: Any]] ?? []
    guard rows.count <= 50 else { throw ImageSearchFailure(message: "Image search returned an unreadable response. Please retry.") }
    let allowedMimes = ["", "image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp"]
    let items = rows.enumerated().compactMap { offset, row -> Item? in
      guard let link = row["link"] as? String, ImageSearchNetwork.allowedURL(link), let image = row["image"] as? [String: Any],
        let thumbnail = image["thumbnailLink"] as? String, ImageSearchNetwork.allowedURL(thumbnail),
        let width = image["width"] as? Int, let height = image["height"] as? Int,
        width > 0, height > 0, width <= 20_000, height <= 20_000,
        allowedMimes.contains((row["mime"] as? String ?? "").lowercased()) else { return nil }
      let title = String((row["title"] as? String ?? "Image").prefix(200))
      return Item(id: "\(start):\(offset):\(link)", title: title, url: link, thumbnailURL: thumbnail, width: width, height: height,
        source: String((row["displayLink"] as? String ?? "").prefix(100)))
    }
    let queries = root["queries"] as? [String: Any]
    let hasNext = (queries?["nextPage"] as? [[String: Any]])?.isEmpty == false && start + pageSize <= 91
    return Page(items: items, hasNext: hasNext)
  }
  /// The full picture for a chosen result, decoded into a bounded bitmap.
  static func bitmap(for item: Item) async throws -> CGImage {
    if let fixture = ImageSearchFixture.data(for: item.url) { return try await MediaCompression.thumbnail(fixture) }
    return try await ImageSearchNetwork.image(at: item.url)
  }
  static func thumbnail(for item: Item) async throws -> CGImage {
    if let fixture = ImageSearchFixture.data(for: item.thumbnailURL) ?? ImageSearchFixture.data(for: item.url) { return try await MediaCompression.thumbnail(fixture) }
    guard ImageSearchNetwork.allowedURL(item.thumbnailURL), let url = URL(string: item.thumbnailURL) else { throw ImageSearchFailure(message: "This image address is not supported.") }
    return try await MediaCompression.thumbnail(try await ImageSearchNetwork.fetch(URLRequest(url: url), limit: 600_000))
  }
}

/// Ephemeral, bounded downloads from any HTTPS host a result points at. Every
/// redirect is checked; nothing from the page besides the picture is kept.
enum ImageSearchNetwork {
  static let maximumBytes = 8_000_000
  static func allowedURL(_ value: String) -> Bool {
    guard value.count <= 3000, let parts = URLComponents(string: value), parts.scheme == "https", let host = parts.host, !host.isEmpty,
      parts.user == nil, parts.password == nil, parts.port == nil || parts.port == 443 else { return false }
    return host != "localhost" && !host.hasSuffix(".local") && host.first?.isNumber != true
  }
  static func fetch(_ request: URLRequest, limit: Int) async throws -> Data {
    guard let url = request.url, allowedURL(url.absoluteString) else { throw ImageSearchFailure(message: "This image address is not supported.") }
    let configuration = URLSessionConfiguration.ephemeral; configuration.urlCache = nil; configuration.httpCookieStorage = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData; configuration.timeoutIntervalForRequest = 20; configuration.timeoutIntervalForResource = 40
    let session = URLSession(configuration: configuration, delegate: RedirectGuard(), delegateQueue: nil)
    defer { session.invalidateAndCancel() }
    var prepared = request
    if prepared.value(forHTTPHeaderField: "User-Agent") == nil { prepared.setValue("MaroonSocial/0.1 (iOS)", forHTTPHeaderField: "User-Agent") }
    let (stream, response) = try await session.bytes(for: prepared)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      let status = (response as? HTTPURLResponse)?.statusCode
      throw ImageSearchFailure(message: status == 429 ? "Image search’s daily limit was reached. Try again tomorrow." : status == 403 || status == 400 ? "Image search’s key needs attention." : "This image could not be loaded. Please retry.")
    }
    guard response.expectedContentLength <= limit else { throw ImageSearchFailure(message: "Choose an image smaller than 8 MB.") }
    var data = Data(); data.reserveCapacity(min(max(0, Int(response.expectedContentLength)), limit))
    for try await byte in stream { try Task.checkCancellation(); guard data.count < limit else { throw ImageSearchFailure(message: "Choose an image smaller than 8 MB.") }; data.append(byte) }
    return data
  }
  static func image(at url: String) async throws -> CGImage {
    guard allowedURL(url), let target = URL(string: url) else { throw ImageSearchFailure(message: "This image address is not supported.") }
    let data = try await fetch(URLRequest(url: target), limit: maximumBytes)
    return try await MediaCompression.thumbnail(data)
  }
  final class RedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
      completionHandler(request.url.map { ImageSearchNetwork.allowedURL($0.absoluteString) } == true ? request : nil)
    }
  }
}

/// Explicit, offline UI-test results. Normal launches never substitute these
/// pictures for provider results or use a real search key.
@MainActor enum ImageSearchFixture {
  static var enabled: Bool {
    #if DEBUG
    let arguments = ProcessInfo.processInfo.arguments
    return arguments.contains("--uitesting") && arguments.contains("--uitesting-images")
    #else
    return false
    #endif
  }
  static func service() -> ImageSearchService {
    guard enabled else { return ImageSearchService(configuration: nil) }
    #if DEBUG
    return ImageSearchService(configuration: .init(apiKey: "offline-fixture-key-00000000", searchEngineID: "fixture")) { request in
      let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "q" }?.value ?? ""
      let rows: [[String: Any]] = entries.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || query.lowercased() == "campus" }.map { entry in
        ["title": entry.title, "link": url(for: entry), "displayLink": "images.maroon.test", "mime": "image/png",
         "image": ["thumbnailLink": url(for: entry), "width": entry.width, "height": entry.height]]
      }
      return try JSONSerialization.data(withJSONObject: ["items": rows, "queries": [:]])
    }
    #else
    return ImageSearchService(configuration: nil)
    #endif
  }
  static func data(for url: String) -> Data? {
    guard enabled else { return nil }
    #if DEBUG
    guard let entry = entries.first(where: { Self.url(for: $0) == url }) else { return nil }
    return media[entry.id]
    #else
    return nil
    #endif
  }
  #if DEBUG
  private struct Entry { let id: String, title: String, width: Int, height: Int, hue: CGFloat }
  private static let entries = [
    Entry(id: "fixture-tower", title: "Campus tower", width: 480, height: 640, hue: 0.0),
    Entry(id: "fixture-desk", title: "Study desk", width: 640, height: 400, hue: 0.58),
    Entry(id: "fixture-mascot", title: "Mascot sticker", width: 400, height: 400, hue: 0.12),
    Entry(id: "fixture-field", title: "Kyle Field sunset", width: 640, height: 360, hue: 0.9)
  ]
  private static func url(for entry: Entry) -> String { "https://images.maroon.test/__maroon_uitest__/" + entry.id + ".png" }
  private static let media: [String: Data] = {
    var values: [String: Data] = [:]
    for entry in entries {
      let format = UIGraphicsImageRendererFormat(); format.scale = 1
      let image = UIGraphicsImageRenderer(size: CGSize(width: entry.width, height: entry.height), format: format).image { context in
        UIColor(hue: entry.hue, saturation: 0.25, brightness: 0.95, alpha: 1).setFill()
        context.fill(CGRect(x: 0, y: 0, width: entry.width, height: entry.height))
        UIColor(hue: entry.hue, saturation: 0.9, brightness: 0.55, alpha: 1).setFill()
        let inset = CGFloat(min(entry.width, entry.height)) * 0.22
        context.cgContext.fillEllipse(in: CGRect(x: inset, y: inset, width: CGFloat(entry.width) - 2 * inset, height: CGFloat(entry.height) - 2 * inset))
      }
      if let data = image.pngData() { values[entry.id] = data }
    }
    return values
  }()
  #endif
}
