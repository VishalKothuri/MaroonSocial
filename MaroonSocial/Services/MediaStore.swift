import Foundation
import UIKit

/// Bytes of one attachment. Attachments are immutable per id, so a cached copy never needs revalidating.
struct MediaContent: Sendable, Equatable {
  let data: Data
  let mime: String?
  var isKlipy = false
}

/// Disk LRU under `Caches/media/<attachmentID>`, capped in bytes and trimmed oldest-accessed first
/// (`.contentAccessDateKey` / `.totalFileAllocatedSizeKey`). Caches is purgeable by the system, which
/// is fine: anything missing is fetched again.
actor MediaDiskCache {
  nonisolated let directory: URL
  private(set) var byteLimit: Int
  private var generation = 0
  /// Running size estimate for this process. `nil` until the directory has been measured, so bytes left
  /// by earlier launches always count against the cap.
  private var estimatedBytes: Int?
  /// A trim goes down to this fraction of the cap, so a full cache rescans once per ~20% of the cap, not per write.
  nonisolated static let lowWaterFraction = 0.8
  var lowWaterMark: Int { Int(Double(byteLimit) * Self.lowWaterFraction) }
  /// Directory scans run by `trim()` (diagnostics and tests).
  private(set) var scans = 0
  private static let attribute = "app.maroonsocial.media"
  private struct Meta: Codable { var mime: String?; var klipy: Bool }

  init(directory: URL, byteLimit: Int) {
    self.directory = directory
    self.byteLimit = byteLimit
  }
  /// Attachment ids are UUIDs; anything else is hashed so no id can name a path outside the directory.
  nonisolated static func fileName(_ id: String) -> String {
    let allowed = !id.isEmpty && id.count <= 80 && id.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || $0 == 45 || $0 == 95 }
    if allowed { return id }
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in id.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
    return "h" + String(hash, radix: 16)
  }
  nonisolated func url(_ id: String) -> URL { directory.appending(path: Self.fileName(id), directoryHint: .notDirectory) }

  func setByteLimit(_ limit: Int) { byteLimit = max(0, limit); trim() }
  func contains(_ id: String) -> Bool { FileManager.default.fileExists(atPath: url(id).path) }

  func read(_ id: String) -> MediaContent? {
    let file = url(id)
    guard let content = Self.load(file) else { return nil }
    touch(file)
    return content
  }
  /// Maps a cached file (no copy) with its stored mime/KLIPY flag. Writes are atomic renames, so a file is
  /// either complete or absent; a mapping stays valid even if a trim unlinks the file afterwards.
  nonisolated static func load(_ file: URL) -> MediaContent? {
    guard let data = try? Data(contentsOf: file, options: .mappedIfSafe), !data.isEmpty else { return nil }
    let meta = meta(file)
    return MediaContent(data: data, mime: meta?.mime ?? sniff(data), isKlipy: meta?.klipy ?? false)
  }
  /// Refreshes the LRU clock for a file that was read without going through `read`.
  func markAccessed(_ id: String) {
    let file = url(id)
    if FileManager.default.fileExists(atPath: file.path) { touch(file) }
  }
  /// Measures what earlier launches left (and trims it to the cap) once per process.
  func measureIfNeeded() { if estimatedBytes == nil { trim() } }
  /// Writes are dropped when they belong to an identity that has since been wiped.
  func write(_ id: String, _ content: MediaContent, generation: Int) {
    guard generation == self.generation, byteLimit > 0, content.data.count <= byteLimit else { return }
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      var excluded = URLResourceValues(); excluded.isExcludedFromBackup = true
      var folder = directory; try? folder.setResourceValues(excluded)
      let file = url(id)
      try content.data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
      if let meta = try? JSONEncoder().encode(Meta(mime: content.mime, klipy: content.isKlipy)) {
        _ = meta.withUnsafeBytes { setxattr(file.path, Self.attribute, $0.baseAddress, meta.count, 0, 0) }
      }
      touch(file)
      if let estimate = estimatedBytes { estimatedBytes = estimate + content.data.count }
      // The first write of a process measures the directory (nil estimate); later ones trim once over the cap.
      if estimatedBytes.map({ $0 > byteLimit }) ?? true { trim() }
    } catch {}
  }
  /// Measures the directory; when it is over the cap, the oldest content-access dates go first until it is
  /// down to the low-water mark.
  func trim() {
    scans += 1
    let keys: [URLResourceKey] = [.contentAccessDateKey, .totalFileAllocatedSizeKey, .fileSizeKey]
    guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else { estimatedBytes = 0; return }
    var entries = files.compactMap { file -> (URL, Date, Int)? in
      guard let values = try? file.resourceValues(forKeys: Set(keys)) else { return nil }
      return (file, values.contentAccessDate ?? .distantPast, values.totalFileAllocatedSize ?? values.fileSize ?? 0)
    }
    var total = entries.reduce(0) { $0 + $1.2 }
    if total > byteLimit {
      let target = lowWaterMark
      entries.sort { $0.1 < $1.1 }
      for (file, _, size) in entries where total > target {
        try? FileManager.default.removeItem(at: file)
        total -= size
      }
    }
    estimatedBytes = total
  }
  func totalBytes() -> Int {
    let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileSizeKey]
    let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))) ?? []
    return files.reduce(0) { total, file in
      let values = try? file.resourceValues(forKeys: keys)
      return total + (values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
    }
  }
  func wipe(generation: Int) {
    self.generation = max(self.generation, generation)
    try? FileManager.default.removeItem(at: directory)
    estimatedBytes = 0
  }
  /// APFS does not reliably bump access dates on read, so the LRU clock is set explicitly.
  private func touch(_ file: URL) {
    var values = URLResourceValues(); values.contentAccessDate = Date()
    var target = file; try? target.setResourceValues(values)
  }
  private static func meta(_ file: URL) -> Meta? {
    let size = getxattr(file.path, attribute, nil, 0, 0, 0)
    guard size > 0, size < 1024 else { return nil }
    var buffer = Data(count: size)
    let read = buffer.withUnsafeMutableBytes { getxattr(file.path, attribute, $0.baseAddress, size, 0, 0) }
    guard read == size else { return nil }
    return try? JSONDecoder().decode(Meta.self, from: buffer)
  }
  static func sniff(_ data: Data) -> String? {
    let head = [UInt8](data.prefix(12))
    if head.count >= 8, head[4...7] == [0x66, 0x74, 0x79, 0x70] { return "video/mp4" }
    if head.starts(with: [0x47, 0x49, 0x46]) { return "image/gif" }
    if head.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
    if head.starts(with: [0xFF, 0xD8]) { return "image/jpeg" }
    return nil
  }
}

/// On-device media cache for attachments: memory (bytes, plus first frames the views already decoded)
/// in front of a disk LRU, one network load per id at a time, prefetch for upcoming feed rows, and a
/// wipe on every identity change. Pure Foundation/UIKit, no third-party dependency.
@MainActor final class MediaStore {
  typealias Fetch = @MainActor (String) async throws -> MediaContent
  nonisolated static let defaultByteLimit = 300 * 1024 * 1024
  static let shared: MediaStore = {
    let arguments = ProcessInfo.processInfo.arguments
    let testing = arguments.contains("--uitesting") || arguments.contains("--uitesting-preserve")
    let store = MediaStore(directory: URL.cachesDirectory.appending(path: testing ? "media-ui-tests" : "media", directoryHint: .isDirectory))
    if arguments.contains("--uitesting") && !arguments.contains("--uitesting-preserve") { store.wipe() }
    store.enforceCapAtLaunch()
    return store
  }()
  /// A private, throwaway store (unit tests and injected services never touch the app's cache).
  static func temporary(byteLimit: Int = defaultByteLimit) -> MediaStore {
    MediaStore(directory: FileManager.default.temporaryDirectory.appending(path: "media-\(UUID().uuidString)", directoryHint: .isDirectory), byteLimit: byteLimit)
  }

  let disk: MediaDiskCache
  private final class Box: NSObject { let content: MediaContent; init(_ content: MediaContent) { self.content = content } }
  private let memory = NSCache<NSString, Box>()
  /// First frames that `AnimatedMedia` already decoded for display, so a re-created row draws at once.
  private let frames = NSCache<NSString, UIImage>()
  private struct Load { let generation: Int; let task: Task<MediaContent, Error> }
  private var loads: [String: Load] = [:]
  private var aliases: [String: String] = [:]
  /// Disk reads issued after a wipe wait for the directory removal, so a wiped file is never served.
  private var wipeTask: Task<Void, Never>?
  /// Wipes whose directory removal has not finished; synchronous disk peeks are skipped meanwhile.
  private var pendingWipes = 0
  /// Disk writes run behind the caller (the bytes are returned first); chained so tests can wait for them.
  private var writeTail: Task<Void, Never>?
  private(set) var generation = 0
  /// Network loads actually started (cache misses); used by tests and diagnostics.
  private(set) var networkLoads = 0

  init(directory: URL, byteLimit: Int = MediaStore.defaultByteLimit, memoryBytes: Int = 32 * 1024 * 1024, frameBytes: Int = 24 * 1024 * 1024, frameCount: Int = 40) {
    disk = MediaDiskCache(directory: directory, byteLimit: byteLimit)
    memory.totalCostLimit = memoryBytes
    frames.totalCostLimit = frameBytes
    frames.countLimit = frameCount
  }

  /// Synchronous memory hit, so a view that already showed this media renders it without a spinner.
  func cached(_ id: String) -> MediaContent? { memory.object(forKey: id as NSString)?.content }
  /// Synchronous memory-or-disk hit for a first render (e.g. after a relaunch): the file is mapped, not
  /// copied, promoted to memory, and its LRU date refreshed in the background. Skipped while a wipe is
  /// pending, so a wiped file is never shown.
  func peek(_ id: String) -> MediaContent? {
    if let hit = cached(id) { return hit }
    guard pendingWipes == 0, let stored = MediaDiskCache.load(disk.url(id)) else { return nil }
    remember(id, stored)
    let disk = disk
    Task(priority: .utility) { await disk.markAccessed(id) }
    return stored
  }
  /// The first frame `AnimatedMedia` decoded for this attachment, when it is still in memory.
  func firstFrame(_ id: String) -> UIImage? { frames.object(forKey: id as NSString) }
  /// Keeps a frame the view already decoded. Only while the bytes are cached for the current identity
  /// (a wipe drops both), and never decoded here: prefetched media costs no bitmap memory.
  func rememberFrame(_ frame: UIImage, for id: String) {
    guard cached(id) != nil else { return }
    let pixels = frame.size.width * frame.scale * frame.size.height * frame.scale
    frames.setObject(frame, forKey: id as NSString, cost: Int(pixels) * 4)
  }
  func isLoading(_ id: String) -> Bool { loads[id] != nil }

  /// Memory, then disk, then exactly one network load per id; concurrent callers share it.
  func content(_ id: String, fetch: @escaping Fetch) async throws -> MediaContent {
    if let hit = cached(id) { return hit }
    return try await finish(id, start(id, fetch: fetch))
  }
  /// The single in-flight load for `id`, registered synchronously so callers coalesce immediately.
  private func start(_ id: String, fetch: @escaping Fetch) -> Load {
    if let load = loads[id], load.generation == generation { return load }
    let generation = generation
    let disk = disk, wiping = wipeTask
    let task = Task { @MainActor [weak self] () throws -> MediaContent in
      await wiping?.value
      if let stored = await disk.read(id) { return stored }
      self?.networkLoads += 1
      let fetched = try await fetch(id)
      try Task.checkCancellation()
      // The caller gets the bytes now; the disk copy (and any trim) happens behind it.
      self?.persist(id, fetched, generation: generation)
      return fetched
    }
    let load = Load(generation: generation, task: task)
    loads[id] = load
    return load
  }
  private func finish(_ id: String, _ load: Load) async throws -> MediaContent {
    do {
      let value = try await load.task.value
      if loads[id]?.task == load.task { loads[id] = nil }
      // A wipe (account switch) while the load was in flight: the result is not cached or returned.
      guard load.generation == generation else { throw CancellationError() }
      remember(id, value)
      return value
    } catch {
      if loads[id]?.task == load.task { loads[id] = nil }
      throw error
    }
  }
  private func persist(_ id: String, _ content: MediaContent, generation: Int) {
    let disk = disk, previous = writeTail, wiping = wipeTask
    writeTail = Task(priority: .utility) {
      await previous?.value
      await wiping?.value
      await disk.write(id, content, generation: generation)
    }
  }
  /// Waits for every disk write issued so far (tests, and callers that hand the file to another store).
  func flushWrites() async { await writeTail?.value }
  /// Stores bytes that arrived some other way (e.g. a known group photo).
  func store(_ id: String, _ content: MediaContent) async {
    let generation = generation
    remember(id, content)
    await wipeTask?.value
    await disk.write(id, content, generation: generation)
  }
  /// Disk-or-memory lookup without any network.
  func local(_ id: String) async -> MediaContent? {
    if let hit = cached(id) { return hit }
    let generation = generation
    await wipeTask?.value
    guard let stored = await disk.read(id), generation == self.generation else { return nil }
    remember(id, stored)
    return stored
  }
  /// Warms the cache for rows about to scroll in. Already cached or loading ids cost nothing.
  func prefetch(ids: [String], fetch: @escaping Fetch) {
    var seen = Set<String>()
    for id in ids where seen.insert(id).inserted && cached(id) == nil && loads[id] == nil {
      let load = start(id, fetch: fetch)
      Task(priority: .utility) { _ = try? await finish(id, load) }
    }
  }
  /// Account switch / deletion: memory, in-flight loads, aliases and the disk directory all go.
  func wipe() {
    generation += 1
    for load in loads.values { load.task.cancel() }
    loads = [:]; aliases = [:]
    memory.removeAllObjects(); frames.removeAllObjects()
    let generation = generation, disk = disk, previous = wipeTask
    pendingWipes += 1
    wipeTask = Task { [weak self] in
      await previous?.value
      await disk.wipe(generation: generation)
      self?.pendingWipes -= 1
    }
  }
  /// Measures (and trims) what earlier launches left on disk, off the main thread, once per process.
  func enforceCapAtLaunch() {
    let disk = disk, wiping = wipeTask
    Task(priority: .background) { await wiping?.value; await disk.measureIfNeeded() }
  }
  func wipeAndWait() async {
    wipe()
    await wipeTask?.value
  }
  func setByteLimit(_ bytes: Int) async { await disk.setByteLimit(bytes) }
  func diskBytes() async -> Int { await wipeTask?.value; return await disk.totalBytes() }

  /// Scope -> attachment id for media read through an authorizing endpoint (group photos).
  func alias(_ key: String) -> String? { aliases[key] }
  func setAlias(_ key: String, id: String?) { aliases[key] = id }

  private func remember(_ id: String, _ content: MediaContent) {
    memory.setObject(Box(content), forKey: id as NSString, cost: content.data.count)
  }
}

/// Downloads a store-issued media URL (R2 presigned GET or CDN). The app's own cache is the cache:
/// ephemeral session, no URLCache, no cookies, bounded size.
enum MediaDownload {
  static let maximumBytes = 6_000_000
  /// The cache-less configuration every media download uses.
  static func configuration() -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil; configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.timeoutIntervalForRequest = 25; configuration.timeoutIntervalForResource = 60
    return configuration
  }
  /// One session for every media URL, so presigned and CDN downloads reuse connections (and HTTP/2) instead
  /// of paying DNS + TCP + TLS per attachment.
  static let session = URLSession(configuration: configuration())
  static func fetch(_ url: URL, session: URLSession = MediaDownload.session, maximumBytes: Int = MediaDownload.maximumBytes) async throws -> (data: Data, mime: String?) {
    guard url.scheme == "https", url.host != nil else { throw URLError(.unsupportedURL) }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
    request.httpShouldHandleCookies = false
    let (data, response) = try await BoundedDownload(limit: maximumBytes).run(request, in: session)
    guard (200...299).contains(response.statusCode), !data.isEmpty else { throw URLError(.badServerResponse) }
    return (data, response.mimeType)
  }
}

/// A data task that stops as soon as the body is known to exceed `limit` (declared length or bytes
/// received so far), instead of buffering an oversized body first.
private final class BoundedDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  private let limit: Int
  private let lock = NSLock()
  private var body = Data()
  private var response: HTTPURLResponse?
  private var oversized = false
  private var continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>?
  init(limit: Int) { self.limit = limit }

  func run(_ request: URLRequest, in session: URLSession) async throws -> (Data, HTTPURLResponse) {
    let task = session.dataTask(with: request)
    task.delegate = self
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        lock.withLock { self.continuation = continuation }
        task.resume()
      }
    } onCancel: { task.cancel() }
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
    let http = response as? HTTPURLResponse
    let tooLarge = response.expectedContentLength > Int64(limit)
    lock.withLock { self.response = http; if tooLarge { oversized = true } }
    completionHandler(http == nil || tooLarge ? .cancel : .allow)
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    let over = lock.withLock { () -> Bool in
      guard !oversized else { return true }
      if body.count + data.count > limit { oversized = true; body = Data(); return true }
      body.append(data); return false
    }
    if over { dataTask.cancel() }
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    let (continuation, result) = lock.withLock { () -> (CheckedContinuation<(Data, HTTPURLResponse), Error>?, Result<(Data, HTTPURLResponse), Error>) in
      defer { self.continuation = nil }
      if oversized { return (self.continuation, .failure(URLError(.dataLengthExceedsMaximum))) }
      if let error { return (self.continuation, .failure(error)) }
      guard let response else { return (self.continuation, .failure(URLError(.badServerResponse))) }
      return (self.continuation, .success((body, response)))
    }
    continuation?.resume(with: result)
  }
}
