import XCTest
@testable import MaroonSocial

@MainActor final class MediaStoreTests: XCTestCase {
  private var directories: [URL] = []
  override func tearDown() async throws {
    for directory in directories { try? FileManager.default.removeItem(at: directory) }
    directories = []
  }
  private func directory() -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "media-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    directories.append(url); return url
  }
  /// Allocated sizes are whole filesystem blocks, so blobs are block multiples.
  private func blob(_ seed: UInt8, blocks: Int = 1) -> MediaContent {
    MediaContent(data: Data(repeating: seed, count: 4096 * blocks), mime: "image/png")
  }
  private func pause() async throws { try await Task.sleep(for: .milliseconds(30)) }

  func testDiskLRUEvictsLeastRecentlyAccessedAndKeepsNewest() async throws {
    let disk = MediaDiskCache(directory: directory(), byteLimit: 3 * 4096)
    for (index, id) in ["a", "b", "c"].enumerated() { await disk.write(id, blob(UInt8(index)), generation: 0); try await pause() }
    let readA = await disk.read("a")
    XCTAssertNotNil(readA, "Reading refreshes a's access date")
    try await pause()
    await disk.write("d", blob(9), generation: 0)
    var present: [String] = []
    for id in ["a", "b", "c", "d"] where await disk.contains(id) { present.append(id) }
    // A trim goes down to the low-water mark (80% of 3 blocks): b and c were the least recently accessed.
    XCTAssertEqual(present, ["a", "d"], "a was read after c was written, so c goes before a")
    let total = await disk.totalBytes()
    let lowWater = await disk.lowWaterMark
    XCTAssertLessThanOrEqual(total, lowWater)
    // Writing several blobs over the cap keeps only the newest ones.
    for index in 0..<6 { await disk.write("n\(index)", blob(UInt8(index)), generation: 0); try await pause() }
    var survivors: [String] = []
    for id in ["a", "d", "n0", "n1", "n2", "n3", "n4", "n5"] where await disk.contains(id) { survivors.append(id) }
    XCTAssertEqual(survivors, ["n4", "n5"])
    // Lowering the cap trims immediately; an item larger than the cap is never written.
    await disk.setByteLimit(4096)
    let afterTrim = await disk.totalBytes()
    XCTAssertLessThanOrEqual(afterTrim, 4096)
    await disk.write("huge", blob(1, blocks: 2), generation: 0)
    let huge = await disk.contains("huge")
    XCTAssertFalse(huge)
  }

  func testCapHoldsAcrossLaunchesAndAFullCacheRescansRarely() async throws {
    let folder = directory()
    // Launch 1 fills the cache exactly to its 3-block cap.
    let first = MediaDiskCache(directory: folder, byteLimit: 3 * 4096)
    for id in ["a", "b", "c"] { await first.write(id, blob(1), generation: 0); try await pause() }
    let launchOne = await first.totalBytes()
    XCTAssertEqual(launchOne, 3 * 4096)
    // Launch 2 starts with no estimate: its first write measures what launch 1 left, so the cap holds.
    let second = MediaDiskCache(directory: folder, byteLimit: 3 * 4096)
    await second.write("d", blob(2), generation: 0)
    let launchTwo = await second.totalBytes()
    XCTAssertLessThanOrEqual(launchTwo, 3 * 4096, "bytes from an earlier launch count against the cap")
    let newest = await second.contains("d"), oldest = await second.contains("a")
    XCTAssertTrue(newest); XCTAssertFalse(oldest)
    // A smaller cap at launch is enforced before any write (MediaStore.shared measures off the main thread).
    let third = MediaDiskCache(directory: folder, byteLimit: 4096)
    await third.measureIfNeeded()
    let launchThree = await third.totalBytes()
    XCTAssertLessThanOrEqual(launchThree, 4096)
    // At the cap, a trim frees down to the low-water mark, so most writes skip the directory scan.
    let full = MediaDiskCache(directory: directory(), byteLimit: 20 * 4096)
    for index in 0..<60 { await full.write("f\(index)", blob(UInt8(index % 200)), generation: 0) }
    let scans = await full.scans
    XCTAssertLessThanOrEqual(scans, 16, "a scan per ~4 writes at most, not one per write over the cap")
    let fullBytes = await full.totalBytes()
    XCTAssertLessThanOrEqual(fullBytes, 20 * 4096)
  }

  func testDiskEntriesKeepMimeAndKlipyFlagAndSurviveANewStore() async throws {
    let folder = directory()
    let first = MediaStore(directory: folder)
    let video = MediaContent(data: Data([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6d, 0x70, 0x34, 0x32]), mime: "video/mp4")
    let klipy = MediaContent(data: Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]), mime: "image/gif", isKlipy: true)
    _ = try await first.content("video") { _ in video }
    _ = try await first.content("klipy") { _ in klipy }
    // Disk copies are written behind the returned bytes.
    await first.flushWrites()
    let relaunched = MediaStore(directory: folder)
    let fromDiskVideo = try await relaunched.content("video") { _ in XCTFail("Disk hit must not fetch"); throw URLError(.badURL) }
    let fromDiskKlipy = try await relaunched.content("klipy") { _ in XCTFail("Disk hit must not fetch"); throw URLError(.badURL) }
    XCTAssertEqual(fromDiskVideo, video); XCTAssertEqual(fromDiskKlipy, klipy)
    XCTAssertEqual(relaunched.networkLoads, 0)
    XCTAssertEqual(relaunched.cached("video"), video, "Disk hits are promoted to memory for synchronous rendering")
    // A view's first render after a relaunch reads the disk synchronously: no spinner pass for a cached file.
    let cold = MediaStore(directory: folder)
    XCTAssertNil(cold.cached("klipy"))
    XCTAssertEqual(cold.peek("klipy"), klipy)
    XCTAssertEqual(cold.cached("klipy"), klipy, "promoted to memory, so later renders do not touch the disk")
    XCTAssertNil(cold.peek("missing"))
    // Never while a wipe is still removing the directory.
    let wiping = MediaStore(directory: folder)
    wiping.wipe()
    XCTAssertNil(wiping.peek("video"))
    await wiping.wipeAndWait()
    XCTAssertNil(wiping.peek("video"))
    // Ids that are not plain UUID-like tokens never become paths.
    XCTAssertEqual(MediaDiskCache.fileName("2f1c0c4e-6a43-4f7b-9d7e-0c1f0a3b2e11"), "2f1c0c4e-6a43-4f7b-9d7e-0c1f0a3b2e11")
    XCTAssertFalse(MediaDiskCache.fileName("../../Library/x").contains("/"))
    XCTAssertFalse(MediaDiskCache.fileName("..").contains("."))
  }

  func testConcurrentLoadsCoalesceIntoOneFetch() async throws {
    let media = MediaStore(directory: directory())
    var fetches = 0
    let fetch: MediaStore.Fetch = { _ in
      fetches += 1
      try await Task.sleep(for: .milliseconds(60))
      return MediaContent(data: Data([1, 2, 3]), mime: "image/png")
    }
    async let first = media.content("one", fetch: fetch)
    async let second = media.content("one", fetch: fetch)
    let values = try await (first, second)
    XCTAssertEqual(values.0.data, Data([1, 2, 3])); XCTAssertEqual(values.1.data, Data([1, 2, 3]))
    XCTAssertEqual(fetches, 1)
    _ = try await media.content("one", fetch: fetch)
    XCTAssertEqual(fetches, 1, "Memory hit")
    // Prefetch skips cached ids and loads each new id once.
    media.prefetch(ids: ["one", "two", "two", "three"], fetch: fetch)
    XCTAssertTrue(media.isLoading("two")); XCTAssertTrue(media.isLoading("three")); XCTAssertFalse(media.isLoading("one"))
    _ = try await media.content("two", fetch: fetch)
    _ = try await media.content("three", fetch: fetch)
    XCTAssertEqual(fetches, 3)
    // A failed load is not cached and a later attempt retries.
    var failures = 0
    do { _ = try await media.content("bad") { _ in failures += 1; throw URLError(.notConnectedToInternet) }; XCTFail() } catch {}
    _ = try await media.content("bad") { _ in failures += 1; return MediaContent(data: Data([4]), mime: nil) }
    XCTAssertEqual(failures, 2)
  }

  func testFirstFramesComeFromTheViewNotFromPrefetch() async throws {
    let media = MediaStore(directory: directory())
    let png = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 20, height: 10)).image { context in UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 10)) }.pngData())
    media.prefetch(ids: ["p"]) { _ in MediaContent(data: png, mime: "image/png") }
    _ = try await media.content("p") { _ in XCTFail("coalesced with the prefetch"); throw URLError(.badURL) }
    try await Task.sleep(for: .milliseconds(50))
    XCTAssertNotNil(media.cached("p"))
    XCTAssertNil(media.firstFrame("p"), "loading (or prefetching) never decodes a bitmap")
    let frame = UIImage(data: png)!
    media.rememberFrame(frame, for: "p")
    XCTAssertTrue(media.firstFrame("p") === frame, "the frame AnimatedMedia decoded is kept for the next row")
    media.rememberFrame(frame, for: "not-loaded")
    XCTAssertNil(media.firstFrame("not-loaded"), "frames are only kept while their bytes are cached")
    media.wipe()
    XCTAssertNil(media.firstFrame("p"))
    media.rememberFrame(frame, for: "p")
    XCTAssertNil(media.firstFrame("p"), "a late frame from the previous identity is dropped")
    await media.wipeAndWait()
  }

  func testWipeDropsMemoryDiskAndInFlightLoads() async throws {
    let media = MediaStore(directory: directory())
    _ = try await media.content("kept") { _ in MediaContent(data: Data([1]), mime: "image/png") }
    let slow = Task { try await media.content("slow") { _ in try await Task.sleep(for: .milliseconds(80)); return MediaContent(data: Data([2]), mime: "image/png") } }
    try await Task.sleep(for: .milliseconds(10))
    await media.wipeAndWait()
    do { _ = try await slow.value; XCTFail("A load from the previous identity must not complete") } catch {}
    XCTAssertNil(media.cached("kept"))
    let keptLocal = await media.local("kept"); XCTAssertNil(keptLocal)
    try await Task.sleep(for: .milliseconds(120))
    let slowLocal = await media.local("slow"); XCTAssertNil(slowLocal, "The interrupted load was not written to disk")
    let bytes = await media.diskBytes(); XCTAssertEqual(bytes, 0)
  }

  func testIdentityChangeWipesTheServiceCache() async throws {
    var reads = 0
    let png = Data([0x89, 0x50, 0x4E, 0x47, 1, 2])
    let media = MediaStore(directory: directory())
    let service = SocialService(credentials: credentials(), transport: { _, action, _, _ in
      XCTAssertEqual(action, "attachment.read"); reads += 1
      return try JSONSerialization.data(withJSONObject: ["attachment_id": "a1", "mime": "image/png", "media_data": png.base64EncodedString()])
    }, media: media)
    _ = try await service.attachmentContent("a1")
    _ = try await service.attachmentContent("a1")
    XCTAssertEqual(reads, 1)
    let before = service.identityRevision
    service.clearCredentialAfterDeletion()
    XCTAssertNotEqual(service.identityRevision, before)
    XCTAssertNil(media.cached("a1"))
    let local = await media.local("a1"); XCTAssertNil(local)
  }

  func testAttachmentReadDecodesInlineBase64AndStoreIssuedURL() async throws {
    let png = Data([0x89, 0x50, 0x4E, 0x47, 9, 9])
    let jpeg = Data([0xFF, 0xD8, 0xFF, 7])
    var actions: [String] = []
    let service = SocialService(credentials: credentials(), transport: { _, action, payload, _ in
      actions.append(action)
      switch payload["attachment_id"] as? String {
      case "inline": return try JSONSerialization.data(withJSONObject: ["attachment_id": "inline", "mime": "image/png", "media_data": png.base64EncodedString()])
      case "remote": return try JSONSerialization.data(withJSONObject: ["attachment_id": "remote", "mime": "image/jpeg", "url": "https://media.example.test/public/remote.jpg", "expires": 1_800_000_000])
      default: return try JSONSerialization.data(withJSONObject: ["attachment_id": "broken", "mime": "image/png"])
      }
    }, media: MediaStore(directory: directory()))
    var downloads: [URL] = []
    service.mediaDownloader = { url in downloads.append(url); return (jpeg, "application/octet-stream") }
    let inline = try await service.attachmentContent("inline")
    XCTAssertEqual(inline.data, png); XCTAssertEqual(inline.mime, "image/png"); XCTAssertFalse(inline.isKlipy)
    XCTAssertTrue(downloads.isEmpty)
    let remote = try await service.attachmentContent("remote")
    XCTAssertEqual(remote.data, jpeg); XCTAssertEqual(remote.mime, "image/jpeg", "The server's mime wins over the HTTP type")
    XCTAssertEqual(downloads, [URL(string: "https://media.example.test/public/remote.jpg")!])
    _ = try await service.attachmentContent("remote")
    XCTAssertEqual(downloads.count, 1, "Cached by attachment id; the URL is never fetched twice")
    do { _ = try await service.attachmentContent("broken"); XCTFail("Neither bytes nor URL") } catch {}
    XCTAssertEqual(actions, ["attachment.read", "attachment.read", "attachment.read"])
  }

  func testMediaDownloadRefusesNonHTTPS() async {
    do { _ = try await MediaDownload.fetch(URL(string: "http://media.example.test/a.png")!); XCTFail() }
    catch { XCTAssertEqual((error as? URLError)?.code, .unsupportedURL) }
  }

  func testMediaDownloadSharesOneSessionAndStopsOversizedBodies() async throws {
    XCTAssertTrue(MediaDownload.session === MediaDownload.session, "one session, so connections are reused")
    XCTAssertNil(MediaDownload.session.configuration.urlCache)
    let configuration = MediaDownload.configuration()
    configuration.protocolClasses = [MediaStubProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let ok = try await MediaDownload.fetch(URL(string: "https://media.example.test/ok.png")!, session: session, maximumBytes: 1000)
    XCTAssertEqual(ok.data, Data(repeating: 7, count: 600)); XCTAssertEqual(ok.mime, "image/png")
    // No Content-Length: the body is cut off once the bytes received pass the limit.
    do { _ = try await MediaDownload.fetch(URL(string: "https://media.example.test/stream.png")!, session: session, maximumBytes: 1000); XCTFail("oversized stream accepted") }
    catch { XCTAssertEqual((error as? URLError)?.code, .dataLengthExceedsMaximum) }
    XCTAssertLessThan(MediaStubProtocol.chunksSent(for: "stream.png"), 40, "stopped early instead of reading the whole body")
    // A declared Content-Length over the limit is refused before the body.
    do { _ = try await MediaDownload.fetch(URL(string: "https://media.example.test/declared.png")!, session: session, maximumBytes: 1000); XCTFail("oversized declaration accepted") }
    catch { XCTAssertEqual((error as? URLError)?.code, .dataLengthExceedsMaximum) }
    do { _ = try await MediaDownload.fetch(URL(string: "https://media.example.test/missing.png")!, session: session, maximumBytes: 1000); XCTFail("404 accepted") }
    catch { XCTAssertEqual((error as? URLError)?.code, .badServerResponse) }
  }

  func testGroupPhotoOffersKnownIdAndReusesDiskBytes() async throws {
    let media = MediaStore(directory: directory())
    let jpeg = Data([0xFF, 0xD8, 0xFF, 1, 2, 3])
    var payloads: [[String: Any]] = []
    var unchanged = false
    let service = GroupPhotoService(transport: { _, payload in
      payloads.append(payload)
      if unchanged, payload["known_attachment_id"] as? String == "photo-1" {
        return try JSONSerialization.data(withJSONObject: ["has_photo": true, "attachment_id": "photo-1", "unchanged": true])
      }
      return try JSONSerialization.data(withJSONObject: ["has_photo": true, "attachment_id": "photo-1", "media_data": jpeg.base64EncodedString()])
    }, media: media)
    let first = try await service.readPhoto(room: "room", memberKey: "peer")
    XCTAssertEqual(first?.data, jpeg); XCTAssertNil(payloads[0]["known_attachment_id"])
    unchanged = true
    let second = try await service.readPhoto(room: "room", memberKey: "peer")
    XCTAssertEqual(second?.data, jpeg); XCTAssertEqual(payloads[1]["known_attachment_id"] as? String, "photo-1")
    XCTAssertEqual(payloads[1]["member_key"] as? String, "peer")
    // Another scope never borrows this scope's id.
    _ = try await service.readPhoto(room: "room")
    XCTAssertNil(payloads[2]["known_attachment_id"])
    // After a wipe nothing is offered and bytes are fetched again.
    await media.wipeAndWait()
    let third = try await service.readPhoto(room: "room", memberKey: "peer")
    XCTAssertEqual(third?.data, jpeg); XCTAssertNil(payloads[3]["known_attachment_id"])
  }

  func testSharedMemeReadAcceptsAStoreIssuedURL() async throws {
    let png = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 20, height: 10)).image { context in UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 10)) }.pngData())
    let service = SharedMemeService { action, _ in
      switch action {
      case "meme.list": return try JSONSerialization.data(withJSONObject: ["memes": [["id": "m1", "title": "Howdy", "mime": "image/png", "width": 20, "height": 10]], "has_next": false])
      case "meme.read": return try JSONSerialization.data(withJSONObject: ["meme_id": "m1", "mime": "image/png", "url": "https://media.example.test/private/m1.png", "expires": 1_800_000_000])
      default: throw SharedMemeFailure(message: "unexpected \(action)")
      }
    }
    var requested: [URL] = []
    service.downloader = { url in requested.append(url); return png }
    await service.load(query: "")
    let bytes = try await service.media(for: service.items[0])
    XCTAssertEqual(bytes, png); XCTAssertEqual(requested.map(\.absoluteString), ["https://media.example.test/private/m1.png"])
  }

  func testAttachmentReplyDecodesOffTheMainActor() async throws {
    let png = Data([0x89, 0x50, 0x4E, 0x47, 1])
    let inline = try JSONSerialization.data(withJSONObject: ["attachment_id": "a", "mime": "image/png", "media_data": png.base64EncodedString()])
    let decoded = try await Task.detached { () -> (AttachmentReply, Bool) in (try AttachmentReply.decode(inline), Self.onMainThread()) }.value
    XCTAssertFalse(decoded.1)
    guard case .bytes(let bytes, let mime) = decoded.0 else { return XCTFail("\(decoded.0)") }
    XCTAssertEqual(bytes, png); XCTAssertEqual(mime, "image/png")
    let remote = try AttachmentReply.decode(JSONSerialization.data(withJSONObject: ["url": "https://media.example.test/public/x.jpg", "mime": "image/jpeg", "expires": 1]))
    guard case .url(let url, "image/jpeg") = remote else { return XCTFail("\(remote)") }
    XCTAssertEqual(url.host, "media.example.test")
    XCTAssertThrowsError(try AttachmentReply.decode(JSONSerialization.data(withJSONObject: ["mime": "image/png", "media_data": "%%%"])))
  }

  nonisolated private static func onMainThread() -> Bool { Thread.isMainThread }
  private func credentials() -> SocialCredentialStore {
    var token: String? = String(repeating: "b", count: 64)
    return SocialCredentialStore(read: { token }, save: { token = $0 }, deletionPending: { false }, markDeletionPending: {}, clear: { token = nil })
  }
}

/// Canned responses for `MediaDownload` (no network): a small body, an unbounded stream without a
/// Content-Length, an oversized declared length, and a 404.
final class MediaStubProtocol: URLProtocol, @unchecked Sendable {
  private static let lock = NSLock()
  nonisolated(unsafe) private static var sent: [String: Int] = [:]
  static func chunksSent(for name: String) -> Int { lock.withLock { sent[name] ?? 0 } }
  private var stopped = false
  override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "media.example.test" }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let url = request.url!, name = url.lastPathComponent
    func respond(_ status: Int, _ headers: [String: String]) {
      client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!, cacheStoragePolicy: .notAllowed)
    }
    switch name {
    case "ok.png":
      respond(200, ["Content-Type": "image/png", "Content-Length": "600"])
      client?.urlProtocol(self, didLoad: Data(repeating: 7, count: 600)); client?.urlProtocolDidFinishLoading(self)
    case "declared.png":
      respond(200, ["Content-Type": "image/png", "Content-Length": "5000"])
      client?.urlProtocol(self, didLoad: Data(repeating: 1, count: 5000)); client?.urlProtocolDidFinishLoading(self)
    case "stream.png":
      respond(200, ["Content-Type": "image/png"])
      DispatchQueue.global().async { [self] in
        for _ in 0..<200 {
          if Self.lock.withLock({ stopped }) { return }
          Self.lock.withLock { Self.sent[name, default: 0] += 1 }
          client?.urlProtocol(self, didLoad: Data(repeating: 2, count: 100))
          Thread.sleep(forTimeInterval: 0.002)
        }
        client?.urlProtocolDidFinishLoading(self)
      }
    default:
      respond(404, ["Content-Type": "text/plain"])
      client?.urlProtocol(self, didLoad: Data("missing".utf8)); client?.urlProtocolDidFinishLoading(self)
    }
  }
  override func stopLoading() { Self.lock.withLock { stopped = true } }
}
