import CryptoKit
import ImageIO
import MaroonCore
import SwiftUI

/// Grid previews are deliberately still images, including when Reduce Motion is
/// off. Only the selected attachment preview needs to decode an animation.
struct KlipyThumbnail: View {
  @Environment(\.scenePhase) private var scenePhase
  let reference: KlipyReference
  var fixtureData: Data? = nil
  @State private var image: UIImage?
  @State private var failed = false

  private var requestID: String {
    KlipyThumbnailCache.requestKey(reference: reference, fixtureData: fixtureData)
      + (scenePhase == .active ? ":active" : ":inactive")
  }

  var body: some View {
    ZStack {
      Palette.surface
      if let image {
        Image(uiImage: image).resizable().scaledToFit()
      } else if failed {
        Image(systemName: "photo").font(.title3).foregroundStyle(Palette.secondary)
      }
    }
    .clipped()
    .accessibilityLabel(failed ? "Preview unavailable" : reference.title)
    .task(id: requestID) {
      image = nil; failed = false
      guard scenePhase == .active else { return }
      let identity = requestID
      do {
        let bitmap = try await KlipyThumbnailCache.shared.thumbnail(reference: reference, fixtureData: fixtureData)
        try Task.checkCancellation()
        guard identity == requestID else { return }
        image = UIImage(cgImage: bitmap.image)
      } catch {
        if !Task.isCancelled && identity == requestID { failed = true }
      }
    }
    .onDisappear { image = nil; failed = false }
  }
}

/// CGImage is immutable; construction and decompression happen off the main
/// actor, and the resulting bitmap can safely be displayed by the main actor.
struct KlipyThumbnailBitmap: @unchecked Sendable {
  let image: CGImage
  var cost: Int { image.bytesPerRow * image.height }
}

enum KlipyThumbnailDecoder {
  static let maximumPixelSize = 480

  static func decode(_ data: Data) throws -> KlipyThumbnailBitmap {
    try Task.checkCancellation()
    // This validates the compressed payload and frame metadata without decoding
    // all GIF frames. The single thumbnail call below always uses index zero.
    try KlipyNetwork.validateMedia(data)
    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
        kCGImageSourceShouldCacheImmediately: true,
      ] as CFDictionary), image.width <= maximumPixelSize, image.height <= maximumPixelSize else {
      throw KlipyFailure(message: "This preview is unavailable.")
    }
    try Task.checkCancellation()
    return KlipyThumbnailBitmap(image: image)
  }
}

/// A strict, memory-only LRU. Unlike NSCache's advisory cost limit, this cache
/// never retains more than its configured decoded-byte or image-count budget.
/// Identical visible requests share one load, and the last disappearing waiter
/// cancels its download. A cancelled worker retains its slot until it exits.
actor KlipyThumbnailCache {
  typealias Loader = @Sendable (URL) async throws -> Data
  static let shared = KlipyThumbnailCache()

  struct Statistics: Sendable {
    let cachedImages: Int
    let cachedBytes: Int
    let activeLoads: Int
    let queuedLoads: Int
    let waitingCallers: Int
  }
  private struct Cached {
    let bitmap: KlipyThumbnailBitmap
    var accessed: UInt64
  }
  private struct Job {
    let key: String
    let url: URL
    let fixtureData: Data?
    var waiters: [UUID: CheckedContinuation<KlipyThumbnailBitmap, Error>]
    var task: Task<Void, Never>?
  }
  private let loader: Loader
  private let maximumImages: Int
  private let maximumCost: Int
  private let maximumConcurrent: Int
  private var cache: [String: Cached] = [:]
  private var cacheCost = 0
  private var clock: UInt64 = 0
  private var jobs: [UUID: Job] = [:]
  private var jobForKey: [String: UUID] = [:]
  private var queue: [UUID] = []
  private var activeLoads = 0

  init(maximumImages: Int = 64, maximumCost: Int = 24_000_000, maximumConcurrent: Int = 4,
    loader: @escaping Loader = { url in
      try await KlipyNetwork.fetch(URLRequest(url: url), api: false, limit: KlipyNetwork.maximumBytes)
    }) {
    self.maximumImages = max(0, maximumImages)
    self.maximumCost = max(0, maximumCost)
    self.maximumConcurrent = min(8, max(1, maximumConcurrent))
    self.loader = loader
  }

  nonisolated static func requestKey(reference: KlipyReference, fixtureData: Data?) -> String {
    let source = fixtureData.map { "fixture:" + SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() } ?? "network"
    return reference.provider + ":" + reference.previewURL + ":" + source
  }

  func thumbnail(reference: KlipyReference, fixtureData: Data? = nil) async throws -> KlipyThumbnailBitmap {
    try Task.checkCancellation()
    guard reference.provider == "klipy", KlipyNetwork.allowedURL(reference.previewURL, api: false),
      let url = URL(string: reference.previewURL) else { throw KlipyFailure(message: "This preview address is not supported.") }
    let key = Self.requestKey(reference: reference, fixtureData: fixtureData)
    if var cached = cache[key] {
      clock &+= 1; cached.accessed = clock; cache[key] = cached
      return cached.bitmap
    }
    let waiter = UUID()
    return try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        if Task.isCancelled { continuation.resume(throwing: CancellationError()); return }
        if let id = jobForKey[key], jobs[id] != nil {
          jobs[id]?.waiters[waiter] = continuation
        } else {
          let id = UUID()
          jobs[id] = Job(key: key, url: url, fixtureData: fixtureData, waiters: [waiter: continuation])
          jobForKey[key] = id; queue.append(id)
        }
        startQueuedJobs()
      }
    } onCancel: {
      Task { await self.cancel(waiter: waiter, key: key) }
    }
  }

  func statistics() -> Statistics {
    Statistics(cachedImages: cache.count, cachedBytes: cacheCost, activeLoads: activeLoads, queuedLoads: queue.count,
      waitingCallers: jobs.values.reduce(0) { $0 + $1.waiters.count })
  }

  private func startQueuedJobs() {
    while activeLoads < maximumConcurrent && !queue.isEmpty {
      let id = queue.removeFirst()
      guard let job = jobs[id] else { continue }
      activeLoads += 1
      let loader = loader
      jobs[id]?.task = Task.detached(priority: .utility) {
        let result: Result<KlipyThumbnailBitmap, Error>
        do {
          try Task.checkCancellation()
          let data: Data
          if let fixture = job.fixtureData { data = fixture }
          else { data = try await loader(job.url) }
          try Task.checkCancellation()
          result = .success(try KlipyThumbnailDecoder.decode(data))
        } catch { result = .failure(error) }
        await self.finish(id: id, result: result)
      }
    }
  }

  private func cancel(waiter: UUID, key: String) {
    guard let id = jobForKey[key], var job = jobs[id], let continuation = job.waiters.removeValue(forKey: waiter) else { return }
    continuation.resume(throwing: CancellationError())
    jobs[id] = job
    guard job.waiters.isEmpty else { return }
    jobForKey.removeValue(forKey: key)
    if let task = job.task { task.cancel() }
    else { jobs.removeValue(forKey: id); queue.removeAll { $0 == id } }
  }

  private func finish(id: UUID, result: Result<KlipyThumbnailBitmap, Error>) {
    guard let job = jobs.removeValue(forKey: id) else { return }
    activeLoads -= 1
    if jobForKey[job.key] == id { jobForKey.removeValue(forKey: job.key) }
    if !job.waiters.isEmpty, case .success(let bitmap) = result { remember(bitmap, key: job.key) }
    for continuation in job.waiters.values { continuation.resume(with: result) }
    startQueuedJobs()
  }

  private func remember(_ bitmap: KlipyThumbnailBitmap, key: String) {
    guard maximumImages > 0, bitmap.cost <= maximumCost else { return }
    if let previous = cache.removeValue(forKey: key) { cacheCost -= previous.bitmap.cost }
    while cache.count >= maximumImages || cacheCost + bitmap.cost > maximumCost {
      guard let oldest = cache.min(by: { $0.value.accessed < $1.value.accessed }) else { break }
      cacheCost -= oldest.value.bitmap.cost; cache.removeValue(forKey: oldest.key)
    }
    clock &+= 1; cache[key] = Cached(bitmap: bitmap, accessed: clock); cacheCost += bitmap.cost
  }
}
