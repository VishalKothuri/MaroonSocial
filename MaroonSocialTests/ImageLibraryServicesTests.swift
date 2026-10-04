import ImageIO
import MaroonCore
import UIKit
import XCTest
@testable import MaroonSocial

@MainActor final class ImageLibraryServicesTests: XCTestCase {
  private func googleResponse(links: [String], nextPage: Bool = true) throws -> Data {
    let items = links.map { link -> [String: Any] in
      ["title": "Result", "link": link, "displayLink": "example.edu", "mime": "image/jpeg",
       "image": ["thumbnailLink": "https://encrypted-tbn0.gstatic.com/thumb", "width": 640, "height": 480]]
    }
    var root: [String: Any] = ["items": items]
    if nextPage { root["queries"] = ["nextPage": [["startIndex": 11]]] }
    return try JSONSerialization.data(withJSONObject: root)
  }

  func testImageSearchRequestUsesImageModeSafeSearchAndCarriesNoIdentity() throws {
    let config = ImageSearchService.Configuration(apiKey: "unit-only-key-000000000000", searchEngineID: "engine:1")
    let request = try ImageSearchService.searchRequest(configuration: config, query: "  campus & q=evil ", start: 11)
    let parts = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
    XCTAssertEqual(parts.host, "www.googleapis.com"); XCTAssertEqual(parts.path, "/customsearch/v1")
    let query = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    XCTAssertEqual(query["q"], "campus & q=evil"); XCTAssertEqual(query["searchType"], "image")
    XCTAssertEqual(query["safe"], "active"); XCTAssertEqual(query["start"], "11"); XCTAssertEqual(query["num"], "10")
    XCTAssertEqual(query["cx"], "engine:1")
    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization")); XCTAssertNil(request.value(forHTTPHeaderField: "X-Social-Token"))
  }

  func testImageSearchDecodeKeepsOnlyHTTPSPicturesAndReportsQuota() throws {
    let page = try ImageSearchService.decode(try googleResponse(links: ["https://example.edu/a.jpg", "http://example.edu/plain.jpg", "https://user:pw@example.edu/b.jpg", "https://example.edu/c.png"]), start: 1)
    XCTAssertEqual(page.items.map(\.url), ["https://example.edu/a.jpg", "https://example.edu/c.png"], "Plain HTTP and credentialed links are dropped")
    XCTAssertTrue(page.hasNext); XCTAssertEqual(page.items[0].aspectRatio, 640.0 / 480.0, accuracy: 0.001)
    XCTAssertFalse(try ImageSearchService.decode(try googleResponse(links: ["https://example.edu/a.jpg"]), start: 91).hasNext, "The provider caps paging at 100 results")
    let quota = try JSONSerialization.data(withJSONObject: ["error": ["code": 429, "message": "Quota exceeded"]])
    XCTAssertThrowsError(try ImageSearchService.decode(quota, start: 1)) { error in
      XCTAssertEqual((error as? ImageSearchFailure)?.message, "Image search’s daily limit was reached. Try again tomorrow.")
    }
    XCTAssertFalse(ImageSearchNetwork.allowedURL("https://localhost/x.png"))
    XCTAssertFalse(ImageSearchNetwork.allowedURL("https://10.0.0.1/x.png"))
    XCTAssertTrue(ImageSearchNetwork.allowedURL("https://images.example.edu/x.png?size=large"))
  }

  func testImageSearchUnavailableNeverRequestsAndStaleResultsNeverWin() async throws {
    var requests = 0
    let unavailable = ImageSearchService(configuration: nil) { _ in requests += 1; return Data() }
    await unavailable.load(query: "campus")
    XCTAssertEqual(requests, 0); XCTAssertFalse(unavailable.available); XCTAssertNotNil(unavailable.error)
    var pending: [CheckedContinuation<Data, Error>] = []
    let config = ImageSearchService.Configuration(apiKey: "unit-only-key-000000000000", searchEngineID: "engine")
    let service = ImageSearchService(configuration: config) { _ in try await withCheckedThrowingContinuation { pending.append($0) } }
    let first = Task { await service.load(query: "old") }
    while pending.count < 1 { await Task.yield() }
    let second = Task { await service.load(query: "new") }
    while pending.count < 2 { await Task.yield() }
    pending[1].resume(returning: try googleResponse(links: ["https://example.edu/new.jpg"])); await second.value
    pending[0].resume(returning: try googleResponse(links: ["https://example.edu/old.jpg"])); await first.value
    XCTAssertEqual(service.items.map(\.url), ["https://example.edu/new.jpg"])
    await service.load(query: "   ")
    XCTAssertTrue(service.items.isEmpty, "A blank query clears results without a request")
  }

  func testSharedMemeServiceTalksToTheSocialEndpointWithBoundedShapes() async throws {
    var actions: [(String, [String: Any])] = []
    let png = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).image { context in UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 40, height: 30)) }.pngData())
    let service = SharedMemeService { action, payload in
      actions.append((action, payload))
      switch action {
      case "meme.list":
        return try JSONSerialization.data(withJSONObject: ["memes": [
          ["id": "m1", "title": "Howdy", "mime": "image/png", "width": 40, "height": 30, "created_at": "2026-10-04T23:00:00Z"],
          ["id": "bad", "title": "Nope", "mime": "text/html", "width": 40, "height": 30]], "has_next": true])
      case "meme.read": return try JSONSerialization.data(withJSONObject: ["meme_id": "m1", "mime": "image/png", "media_data": png.base64EncodedString()])
      case "meme.publish": return Data(#"{"meme_id":"m2"}"#.utf8)
      case "meme.report": return Data(#"{"ok":true,"removed":false}"#.utf8)
      default: throw SharedMemeFailure(message: "unexpected \(action)")
      }
    }
    await service.load(query: "  howdy  ")
    XCTAssertEqual(service.items.map(\.id), ["m1"], "Rows with unsupported mimes are dropped")
    XCTAssertTrue(service.hasNext); XCTAssertNil(service.error)
    XCTAssertEqual(actions[0].1["query"] as? String, "howdy"); XCTAssertEqual(actions[0].1["page"] as? Int, 1)
    let bytes = try await service.media(for: service.items[0])
    XCTAssertEqual(bytes, png)
    _ = try await service.media(for: service.items[0])
    XCTAssertEqual(actions.filter { $0.0 == "meme.read" }.count, 1, "Bytes are cached per session")
    let id = try await service.publish(MediaAttachment(kind: .image, data: png), title: String(repeating: "x", count: 100))
    XCTAssertEqual(id, "m2")
    let publish = try XCTUnwrap(actions.first { $0.0 == "meme.publish" }?.1)
    XCTAssertEqual((publish["title"] as? String)?.count, 80); XCTAssertEqual(publish["data"] as? String, png.base64EncodedString())
    try await service.report(service.items[0])
    XCTAssertTrue(service.items.isEmpty)
    let klipy = MediaAttachment(klipy: KlipyReference(id: "1", slug: "s", title: "t", category: "static-memes", kind: "image", mime: "image/png", url: "https://static.klipy.com/a.png", previewURL: "https://static.klipy.com/a.png", size: 10))
    do { _ = try await service.publish(klipy); XCTFail("Provider media cannot be re-shared") } catch {}
    do { _ = try await service.publish(MediaAttachment(kind: .gif, data: png)); XCTFail("GIFs are not memes here") } catch {}
    XCTAssertEqual(actions.filter { $0.0 == "meme.publish" }.count, 1)
  }

  func testSharedMemeFixtureRoundTripsAPublishedImage() async throws {
    let fixture = SharedMemeFixture()
    let service = SharedMemeService { action, payload in try fixture.respond(action, payload) }
    await service.load(query: "")
    XCTAssertEqual(service.items.count, 2)
    let format = UIGraphicsImageRendererFormat(); format.scale = 1
    let jpeg = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 64, height: 48), format: format).image { context in UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 64, height: 48)) }.jpegData(compressionQuality: 0.8))
    let id = try await service.publish(MediaAttachment(kind: .image, data: jpeg), title: "Blue test")
    await service.load(query: "blue")
    XCTAssertEqual(service.items.map(\.id), [id]); XCTAssertEqual(service.items[0].width, 64)
    let bytes = try await service.media(for: service.items[0])
    XCTAssertEqual(bytes, jpeg)
    try await service.report(service.items[0])
    await service.load(query: "blue")
    XCTAssertTrue(service.items.isEmpty, "A reported fixture meme disappears like a removed one")
  }
}
