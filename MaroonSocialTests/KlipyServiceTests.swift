import XCTest
import ImageIO
import MaroonCore
@testable import MaroonSocial

@MainActor final class KlipyServiceTests: XCTestCase {
  private func response(_ title: String = "Hello", ad: Bool = false) throws -> Data {
    let file: [String: Any] = ["url": "https://static.klipy.com/media.gif?preserve=a%2Bb", "size": 1000, "width": 100, "height": 100]
    var rows: [[String: Any]] = [["id": 123, "slug": "hello", "title": title, "type": "gif", "file": ["sm": ["gif": file]]]]
    if ad { rows.append(["type": "ad", "content": "<div>Provider ad</div>", "height": 75]); rows.append(["id": 124, "title": "Unsupported preserved row", "type": "gif"]) }
    return try JSONSerialization.data(withJSONObject: ["result": true, "data": ["data": rows, "has_next": false]])
  }
  func testSearchEncodesQueryWithoutSocialIdentityAndPreservesResultOrder() throws {
    let req = try KlipyService.searchRequest(key: "unit-only", customerID: "separate-install", query: "hi & q=evil", category: .gifs, page: 2)
    let parts = try XCTUnwrap(URLComponents(url: req.url!, resolvingAgainstBaseURL: false))
    XCTAssertEqual(parts.queryItems?.first { $0.name == "q" }?.value, "hi & q=evil")
    XCTAssertNil(req.value(forHTTPHeaderField: "Authorization")); XCTAssertNil(req.value(forHTTPHeaderField: "X-Social-Token"))
    let result = try KlipyService.decode(response(ad: true), category: .gifs)
    XCTAssertEqual(result.items.count, 3); XCTAssertEqual(result.items[1].adHTML, "<div>Provider ad</div>")
    XCTAssertEqual(result.items[1].adHeight, 75); XCTAssertNil(result.items[2].reference)
    XCTAssertEqual(result.items[0].reference?.url, "https://static.klipy.com/media.gif?preserve=a%2Bb")
  }
  func testStaleSearchAndDismissalNeverReplaceCurrentResults() async throws {
    var pending: [CheckedContinuation<Data, Error>] = []
    let service = KlipyService(key: "unit-only", customerID: "test") { _ in try await withCheckedThrowingContinuation { pending.append($0) } }
    let first = Task { await service.load(query: "old", category: .gifs) }
    while pending.count < 1 { await Task.yield() }
    let second = Task { await service.load(query: "new", category: .gifs) }
    while pending.count < 2 { await Task.yield() }
    pending[1].resume(returning: try response("New")); await second.value
    pending[0].resume(returning: try response("Old")); await first.value
    XCTAssertEqual(service.items.first?.title, "New")
    let third = Task { await service.load(query: "cancel", category: .gifs) }
    while pending.count < 3 { await Task.yield() }
    service.cancel(); pending[2].resume(returning: try response("Cancelled")); await third.value
    XCTAssertTrue(service.items.isEmpty); XCTAssertFalse(service.loading)
  }
  func testUnavailableNeverRequestsProvider() async {
    var requests = 0
    let service = KlipyService(key: nil, customerID: "fixture") { _ in requests += 1; return Data() }
    await service.load(query: "hello", category: .memes)
    XCTAssertFalse(service.available); XCTAssertEqual(requests, 0); XCTAssertNotNil(service.error)
  }
  func testStrictHostSchemeAndRedirectPolicy() {
    for url in ["http://static.klipy.com/x", "https://static.klipy.com.evil.test/x", "https://x@static.klipy.com/x", "https://static.klipy.com:444/x", "https://static.klipy.com/x#evil", "file:///tmp/x", "https://api.klipy.com/x"] { XCTAssertFalse(KlipyNetwork.allowedURL(url, api: false), url) }
    XCTAssertTrue(KlipyNetwork.allowedURL("https://static2.klipy.com/x?keep=a%2Bb", api: false))
    XCTAssertFalse(KlipyNetwork.allowedURL("https://static.klipy.com/x", api: true))
  }
  func testBoundedImageDecoderRejectsInvalidAndOversizedData() throws {
    XCTAssertThrowsError(try KlipyNetwork.validateMedia(Data("<html>not a GIF</html>".utf8)))
    XCTAssertThrowsError(try KlipyNetwork.validateMedia(Data(repeating: 0, count: 5_000_001)))
    let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aZ1sAAAAASUVORK5CYII=")!
    XCTAssertNoThrow(try KlipyNetwork.validateMedia(png))
  }
  func testReferenceUploadHasNoCopiedMediaAndStableNonce() async throws {
    let credentials = SocialCredentialStore(read: { String(repeating: "a", count: 64) }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {})
    var nonces: [String] = []
    let social = SocialService(credentials: credentials) { _, action, payload, _ in
      XCTAssertEqual(action, "attachment.external"); XCTAssertNil(payload["data"])
      nonces.append(try XCTUnwrap(payload["nonce"] as? String))
      XCTAssertEqual((payload["reference"] as? [String: Any])?["url"] as? String, "https://static.klipy.com/media.gif?preserve=a%2Bb")
      return Data(#"{"attachment_id":"saved-reference"}"#.utf8)
    }
    let ref = try XCTUnwrap(KlipyService.decode(response(), category: .gifs).items.first?.reference)
    let media = MediaAttachment(klipy: ref)
    XCTAssertTrue(media.data.isEmpty)
    _ = try await social.upload(media, roomID: "room"); _ = try await social.upload(media, roomID: "room")
    XCTAssertEqual(nonces, [media.id, media.id])
    let old = try JSONDecoder().decode(MediaAttachment.self, from: Data(#"{"id":"old","kind":"image","data":"AA=="}"#.utf8))
    XCTAssertNil(old.klipy)
  }

  func testGridUsesPreviewAspectWhileAttachmentKeepsLargerOriginal() throws {
    let original: [String: Any] = ["url": "https://static.klipy.com/full.jpg?keep=a%2Bb", "size": 9000, "width": 800, "height": 600]
    // A provider thumbnail can use a different crop from the larger original.
    let thumbnail: [String: Any] = ["url": "https://static.klipy.com/thumb.jpg?keep=c%2Bd", "size": 1000, "width": 120, "height": 180]
    let data = try JSONSerialization.data(withJSONObject: ["result": true, "data": ["data": [["id": "photo", "slug": "photo", "title": "Portrait thumbnail", "file": ["md": ["jpg": original], "sm": ["jpg": thumbnail]]]], "has_next": false]])
    let item = try XCTUnwrap(KlipyService.decode(data, category: .memes).items.first)
    XCTAssertEqual(item.reference?.url, original["url"] as? String)
    XCTAssertEqual(item.reference?.previewURL, thumbnail["url"] as? String)
    XCTAssertEqual(item.reference?.size, 9000)
    XCTAssertEqual(item.width, 120); XCTAssertEqual(item.height, 180)
    XCTAssertEqual(item.aspectRatio, 2.0 / 3.0, accuracy: 0.0001)
    var unknown = KlipyService.Item(id: "legacy", title: "No dimensions")
    XCTAssertEqual(unknown.aspectRatio, 1)
    for (width, height) in [(0, 100), (-1, 100), (8193, 100), (4000, 4000), (Int.max, Int.max)] {
      unknown.width = width; unknown.height = height
      XCTAssertEqual(unknown.aspectRatio, 1, "Invalid dimensions must not destabilize layout")
    }
    unknown.width = 640; unknown.height = 360
    XCTAssertEqual(unknown.aspectRatio, 16.0 / 9.0, accuracy: 0.0001)
  }

  func testPaginationPreservesRepeatedProviderRowsWithoutIdentityCollisionsOrQueryMixing() async throws {
    var requests: [URLRequest] = []
    let service = KlipyService(key: "unit-only", customerID: "fixture") { request in
      requests.append(request)
      var object = try XCTUnwrap(JSONSerialization.jsonObject(with: self.response(ad: true)) as? [String: Any])
      var body = try XCTUnwrap(object["data"] as? [String: Any]); body["has_next"] = requests.count == 1; object["data"] = body
      return try JSONSerialization.data(withJSONObject: object)
    }
    await service.load(query: "campus", category: .gifs)
    await service.load(query: "different", category: .gifs, more: true)
    await service.load(query: "campus", category: .memes, more: true)
    XCTAssertEqual(requests.count, 1, "Load more cannot append rows from another query or category")
    await service.load(query: " campus ", category: .gifs, more: true)
    XCTAssertEqual(requests.count, 2)
    XCTAssertEqual(service.items.count, 6)
    XCTAssertEqual(Set(service.items.map(\.id)).count, 6)
    XCTAssertEqual(service.items[0].reference?.id, service.items[3].reference?.id)
    XCTAssertNotNil(service.items[1].adHTML); XCTAssertNotNil(service.items[4].adHTML)
    XCTAssertNil(service.items[2].reference); XCTAssertNil(service.items[5].reference)
    XCTAssertFalse(service.hasNext)
  }

  func testRecentsPersistOnlyReferencesAndDimensionsAndClearWithoutOtherPreferences() throws {
    let suite = "KlipyRecentsTests." + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("unrelated", forKey: "other.preference")
    let recents = KlipyRecents(defaults: defaults)
    let item = try XCTUnwrap(KlipyService.decode(response(), category: .gifs).items.first)
    recents.record(item)
    let stored = try XCTUnwrap(defaults.data(forKey: KlipyRecents.storageKey))
    let records = try XCTUnwrap(JSONSerialization.jsonObject(with: stored) as? [[String: Any]])
    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(Set(records[0].keys), Set(["reference", "width", "height"]))
    let savedReference = try XCTUnwrap(records[0]["reference"] as? [String: Any])
    XCTAssertNil(savedReference["data"]); XCTAssertNil(savedReference["customer_id"])
    let restored = KlipyRecents(defaults: defaults)
    XCTAssertEqual(restored.items.first?.reference, item.reference)
    XCTAssertEqual(restored.items.first?.aspectRatio, item.aspectRatio)
    restored.clear()
    XCTAssertTrue(restored.items.isEmpty); XCTAssertNil(defaults.object(forKey: KlipyRecents.storageKey))
    XCTAssertEqual(defaults.string(forKey: "other.preference"), "unrelated")
  }

  func testRecentsDeduplicatePerCategoryMoveToFrontAndStayBounded() throws {
    let recents = KlipyRecents(defaults: nil)
    let template = try XCTUnwrap(KlipyService.decode(response(), category: .gifs).items.first)
    for i in 0..<32 {
      var item = template; item.reference?.id = "item-\(i)"; item.reference?.title = "Item \(i)"
      recents.record(item)
    }
    XCTAssertEqual(recents.items.count, 30)
    XCTAssertEqual(recents.items.first?.reference?.id, "item-31")
    XCTAssertEqual(recents.items.last?.reference?.id, "item-2")
    var selected = template; selected.reference?.id = "item-5"; selected.reference?.title = "Updated choice"
    recents.record(selected)
    XCTAssertEqual(recents.items.count, 30)
    XCTAssertEqual(recents.items.first?.reference?.id, "item-5")
    XCTAssertEqual(recents.items.first?.title, "Updated choice")
    selected.reference?.category = "static-memes"; recents.record(selected)
    XCTAssertEqual(recents.items.filter { $0.reference?.id == "item-5" }.count, 2)
    XCTAssertEqual(recents.items.first?.reference?.category, "static-memes")
    XCTAssertEqual(Set(recents.items.map(\.id)).count, recents.items.count)
  }

  func testRecentsRejectAdsUntrustedURLsIncompleteDimensionsAndCorruptPersistence() throws {
    let recents = KlipyRecents(defaults: nil)
    let template = try XCTUnwrap(KlipyService.decode(response(), category: .gifs).items.first)
    var ad = template; ad.adHTML = "<div>Ad</div>"; recents.record(ad)
    var unsafe = template; unsafe.reference?.url = "https://example.invalid/private"; recents.record(unsafe)
    unsafe = template; unsafe.reference?.previewURL = "http://static.klipy.com/image.gif"; recents.record(unsafe)
    unsafe = template; unsafe.width = nil; recents.record(unsafe)
    unsafe = template; unsafe.width = Int.max; recents.record(unsafe)
    XCTAssertTrue(recents.items.isEmpty)
    let suite = "KlipyCorruptTests." + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(Data("broken JSON".utf8), forKey: KlipyRecents.storageKey)
    XCTAssertTrue(KlipyRecents(defaults: defaults).items.isEmpty)
    XCTAssertNil(defaults.object(forKey: KlipyRecents.storageKey))
    var legacy = template; legacy.width = nil; legacy.height = nil; recents.record(legacy)
    XCTAssertEqual(recents.items.count, 1, "Old valid references without dimensions remain usable")
    XCTAssertEqual(recents.items[0].aspectRatio, 1)
  }
}
