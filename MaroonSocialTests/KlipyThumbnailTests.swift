import XCTest
import ImageIO
import MaroonCore
@testable import MaroonSocial

final class KlipyThumbnailTests: XCTestCase {
  private func reference(_ id: String = "one") -> KlipyReference {
    KlipyReference(id: id, slug: id, title: id, category: "gifs", kind: "gif", mime: "image/gif",
      url: "https://static.klipy.com/large/\(id).gif", previewURL: "https://static2.klipy.com/small/\(id).gif?keep=a%2Bb", size: 1000)
  }
  private func imageBytes(width: Int = 32, height: Int = 16, animated: Bool = false) throws -> Data {
    let bytes = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(bytes, (animated ? "com.compuserve.gif" : "public.png") as CFString, animated ? 2 : 1, nil))
    let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    for index in 0..<(animated ? 2 : 1) {
      context.setFillColor(red: index == 0 ? 1 : 0, green: 0, blue: index == 0 ? 0 : 1, alpha: 1)
      context.fill(CGRect(x: 0, y: 0, width: width, height: height))
      CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
    }
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return bytes as Data
  }
  private func eventually(_ condition: @escaping () async -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
    for _ in 0..<500 {
      if await condition() { return }
      try? await Task.sleep(for: .milliseconds(2))
    }
    XCTFail("Asynchronous thumbnail state did not settle", file: file, line: line)
  }

  func testAnimatedInputDecodesOnlyFirstFrameAtBoundedNaturalAspect() throws {
    let bitmap = try KlipyThumbnailDecoder.decode(imageBytes(width: 1600, height: 800, animated: true))
    XCTAssertEqual(bitmap.image.width, 480); XCTAssertEqual(bitmap.image.height, 240)
    XCTAssertLessThanOrEqual(bitmap.cost, 480 * 240 * 8)
    let pixel = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    pixel.draw(bitmap.image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    let rgba = try XCTUnwrap(pixel.data).assumingMemoryBound(to: UInt8.self)
    XCTAssertGreaterThan(rgba[0], 240); XCTAssertLessThan(rgba[2], 10, "The first red frame must be shown, not the second blue frame.")
  }

  func testPreviewURLCacheReuseAndStrictLRUEviction() async throws {
    let bytes = try imageBytes()
    let requests = ThumbnailRequestLog()
    let cost = try KlipyThumbnailDecoder.decode(bytes).cost
    let cache = KlipyThumbnailCache(maximumImages: 2, maximumCost: cost * 2) { url in
      await requests.record(url); return bytes
    }
    _ = try await cache.thumbnail(reference: reference("one"))
    _ = try await cache.thumbnail(reference: reference("two"))
    _ = try await cache.thumbnail(reference: reference("one")) // Refresh the LRU position.
    _ = try await cache.thumbnail(reference: reference("three"))
    _ = try await cache.thumbnail(reference: reference("two")) // Evicted, so loaded again.
    let urls = await requests.urls
    XCTAssertEqual(urls.count, 4)
    XCTAssertEqual(urls.first?.absoluteString, reference().previewURL)
    XCTAssertTrue(urls.allSatisfy { $0.path.contains("/small/") })
    let stats = await cache.statistics()
    XCTAssertEqual(stats.cachedImages, 2); XCTAssertLessThanOrEqual(stats.cachedBytes, cost * 2)
  }

  func testSharedRequestSurvivesOneCancelledWaiter() async throws {
    let loader = ThumbnailControlledLoader()
    let cache = KlipyThumbnailCache { try await loader.load($0) }
    let ref = reference()
    let first = Task { try await cache.thumbnail(reference: ref) }
    let second = Task { try await cache.thumbnail(reference: ref) }
    await eventually { await cache.statistics().waitingCallers == 2 }
    first.cancel()
    await eventually { await cache.statistics().waitingCallers == 1 }
    await loader.completeAll(try imageBytes())
    do { _ = try await first.value; XCTFail("Cancelled waiter returned an image") } catch { XCTAssertTrue(error is CancellationError) }
    _ = try await second.value
    let counts = await loader.counts()
    XCTAssertEqual(counts.started, 1); XCTAssertEqual(counts.cancelled, 0)
  }

  func testConcurrencyLimitAndQueuedCancellationAvoidExtraDownloads() async throws {
    let loader = ThumbnailControlledLoader()
    let cache = KlipyThumbnailCache(maximumConcurrent: 2) { try await loader.load($0) }
    let first = Task { try await cache.thumbnail(reference: self.reference("one")) }
    let second = Task { try await cache.thumbnail(reference: self.reference("two")) }
    await eventually { await loader.counts().started == 2 }
    let queued = Task { try await cache.thumbnail(reference: self.reference("three")) }
    await eventually { await cache.statistics().queuedLoads == 1 }
    queued.cancel()
    await eventually { await cache.statistics().queuedLoads == 0 }
    first.cancel(); second.cancel()
    for task in [first, second, queued] {
      do { _ = try await task.value; XCTFail("Cancelled request returned an image") } catch { XCTAssertTrue(error is CancellationError) }
    }
    await eventually { await cache.statistics().activeLoads == 0 }
    let counts = await loader.counts()
    XCTAssertEqual(counts.started, 2); XCTAssertEqual(counts.cancelled, 2)
    XCTAssertEqual(counts.maximumActive, 2)
  }

  func testFixtureNeverFetchesAndDifferentBytesDoNotReuseStaleImage() async throws {
    let requests = ThumbnailRequestLog()
    let cache = KlipyThumbnailCache { url in await requests.record(url); throw URLError(.notConnectedToInternet) }
    let first = try await cache.thumbnail(reference: reference(), fixtureData: imageBytes(width: 32, height: 16))
    let changed = try await cache.thumbnail(reference: reference(), fixtureData: imageBytes(width: 16, height: 32))
    XCTAssertEqual(first.image.width, 32); XCTAssertEqual(changed.image.width, 16)
    let urls = await requests.urls; XCTAssertTrue(urls.isEmpty)
  }

  func testRejectedAddressesAndInvalidPayloadsNeverEnterCache() async throws {
    let requests = ThumbnailRequestLog()
    let cache = KlipyThumbnailCache { url in await requests.record(url); return Data("not an image".utf8) }
    var invalid = reference(); invalid.previewURL = "https://static.klipy.com.evil.test/media.gif"
    do { _ = try await cache.thumbnail(reference: invalid); XCTFail("Unsafe host accepted") } catch {}
    let before = await requests.urls; XCTAssertTrue(before.isEmpty)
    do { _ = try await cache.thumbnail(reference: reference()); XCTFail("Invalid bytes decoded") } catch {}
    let stats = await cache.statistics(); XCTAssertEqual(stats.cachedImages, 0); XCTAssertEqual(stats.cachedBytes, 0)
    XCTAssertThrowsError(try KlipyThumbnailDecoder.decode(Data(repeating: 0, count: 5_000_001)))
  }
}

private actor ThumbnailRequestLog {
  var urls: [URL] = []
  func record(_ url: URL) { urls.append(url) }
}

private actor ThumbnailControlledLoader {
  private var pending: [UUID: CheckedContinuation<Data, Error>] = [:]
  private var started = 0
  private var cancelled = 0
  private var maximumActive = 0
  func load(_ url: URL) async throws -> Data {
    let id = UUID()
    return try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        if Task.isCancelled { continuation.resume(throwing: CancellationError()); return }
        pending[id] = continuation; started += 1; maximumActive = max(maximumActive, pending.count)
      }
    } onCancel: { Task { await self.cancel(id) } }
  }
  private func cancel(_ id: UUID) {
    guard let continuation = pending.removeValue(forKey: id) else { return }
    cancelled += 1; continuation.resume(throwing: CancellationError())
  }
  func completeAll(_ bytes: Data) {
    let continuations = pending.values; pending = [:]
    for continuation in continuations { continuation.resume(returning: bytes) }
  }
  func counts() -> (started: Int, cancelled: Int, maximumActive: Int) { (started, cancelled, maximumActive) }
}
