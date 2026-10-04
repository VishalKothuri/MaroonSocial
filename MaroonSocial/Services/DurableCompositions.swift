import Foundation
import MaroonCore
import Observation

struct CompositionDraft: Codable, Equatable, Sendable {
  var text = ""
  var media: MediaAttachment?
  var additionalMedia: [MediaAttachment]? = nil
  var fields: [String: String] = [:]
  var poll: PostPollDraft?
  var nonce = UUID().uuidString
  var hasContent = false
  var updated = Date.distantPast
  var mediaBytes: Int { (media?.data.count ?? 0) + (additionalMedia ?? []).reduce(0) { $0 + $1.data.count } }
}

struct QueuedMessage: Codable, Equatable, Identifiable, Sendable {
  var id: String { nonce }
  let nonce: String
  let roomID: String
  let text: String
  let media: MediaAttachment?
  let replyID: String?
  var attachmentID: String?
  var created = Date.now
  var attempts = 0
  var nextAttempt = Date.distantPast
  var failure: String?
  var requiresRetry = false
}

/// One protected, atomic document per installation cache. Account changes replace
/// its random local owner key; neither credentials nor global member IDs persist.
@Observable @MainActor final class DurableCompositions {
  struct Document: Codable, Sendable {
    var owner: String
    var drafts: [String: CompositionDraft] = [:]
    var queue: [QueuedMessage] = []
  }
  private var file: URL?
  private var document = Document(owner: UUID().uuidString)
  private var tail: Task<Void, Never>?
  private(set) var error: String?
  var owner: String { document.owner }
  var queue: [QueuedMessage] { document.queue }
  var draftKeys: [String] { document.drafts.keys.sorted() }
  func configure(file: URL?, owner: String, reset: Bool = false) {
    self.file = file
    if !reset, let file, let bytes = try? Data(contentsOf: file), bytes.count <= 80_000_000,
      let saved = try? JSONDecoder().decode(Document.self, from: bytes), saved.owner == owner {
      document = saved
    } else { document = Document(owner: owner) }
  }
  func draft(_ key: String) -> CompositionDraft? { document.drafts[key] }
  @discardableResult func saveDraft(_ value: CompositionDraft, key: String, owner expectedOwner: String? = nil) async -> Bool {
    guard expectedOwner == nil || expectedOwner == owner else { return false }
    let operationOwner = owner
    if value.hasContent && storedMediaBytes - (document.drafts[key]?.mediaBytes ?? 0) + value.mediaBytes > 50_000_000 { error = Failure.full.localizedDescription; return false }
    if value.hasContent && document.drafts[key] == nil && document.drafts.count >= 40 {
      error = Failure.full.localizedDescription; return false
    }
    if value.hasContent { var value = value; value.updated = .now; document.drafts[key] = value }
    else { document.drafts.removeValue(forKey: key) }
    do { try await persist(); return operationOwner == owner } catch { if operationOwner == owner { self.error = "Your draft could not be saved on this device. " + error.localizedDescription }; return false }
  }
  func removeDraft(_ key: String, owner expectedOwner: String? = nil) async {
    guard expectedOwner == nil || expectedOwner == owner else { return }
    let operationOwner = owner
    document.drafts.removeValue(forKey:key)
    do { try await persist() } catch { if operationOwner == owner { self.error = error.localizedDescription } }
  }
  func enqueue(_ value: QueuedMessage) async throws {
    let operationOwner = owner
    if let old = document.queue.first(where: { $0.id == value.id }) {
      guard old.roomID == value.roomID, old.text == value.text, old.media == value.media, old.replyID == value.replyID else { throw Failure.conflict }
      return
    }
    guard document.queue.count < 50, storedMediaBytes + (value.media?.data.count ?? 0) <= 50_000_000 else { throw Failure.full }
    document.queue.append(value)
    do { try await persist() } catch { if operationOwner == owner { document.queue.removeAll { $0.id == value.id } }; throw error }
  }
  func update(_ value: QueuedMessage) async throws {
    guard let index = document.queue.firstIndex(where: { $0.id == value.id }) else { return }
    document.queue[index] = value; try await persist()
  }
  func remove(_ id: String) async throws { document.queue.removeAll { $0.id == id }; try await persist() }
  func retry(_ id: String) async throws {
    guard var value = document.queue.first(where: { $0.id == id }) else { return }
    value.requiresRetry = false; value.failure = nil; value.nextAttempt = .distantPast
    try await update(value)
  }
  func reset(owner: String) {
    document = Document(owner: owner); error = nil
    Task { do { try await persist() } catch { if self.owner == owner { self.error = "Local drafts could not be cleared." } } }
  }
  private var storedMediaBytes: Int {
    document.queue.reduce(0) { $0 + ($1.media?.data.count ?? 0) } + document.drafts.values.reduce(0) { $0 + $1.mediaBytes }
  }
  private func persist() async throws {
    guard let file else { return }
    let snapshot = document, previous = tail
    let work = Task.detached(priority: .utility) {
      await previous?.value
      let data = try JSONEncoder().encode(snapshot)
      guard data.count <= 80_000_000 else { throw Failure.full }
      try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: file, options: [.atomic, .completeFileProtection])
      var protected = file; var values = URLResourceValues(); values.isExcludedFromBackup = true; try? protected.setResourceValues(values)
    }
    tail = Task { _ = try? await work.value }
    try await work.value
    if document.owner == snapshot.owner { error = nil }
  }
  enum Failure: LocalizedError { case full, conflict
    var errorDescription: String? { self == .full ? "Your unsent storage is full. Send or remove an older draft or queued message first." : "This send identifier belongs to another draft. Keep the original queued message or remove it before retrying." }
  }
}
