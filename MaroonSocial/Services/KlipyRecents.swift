import Foundation
import MaroonCore
import Observation

/// Local attachment choices only: no image bytes, search history or social identity.
@Observable @MainActor final class KlipyRecents {
  static let shared = KlipyRecents()
  static let storageKey = "klipy.recent.attachments.v1"
  private let defaults: UserDefaults?
  private var entries: [Entry] = []
  private(set) var items: [KlipyService.Item] = []
  private struct Entry: Codable {
    var reference: KlipyReference
    var width: Int?
    var height: Int?
    var identity: String { reference.category + ":" + reference.id }
    var item: KlipyService.Item {
      KlipyService.Item(id: "recent:" + identity, title: reference.title, reference: reference, width: width, height: height)
    }
  }
  init(defaults: UserDefaults? = .standard) {
    self.defaults = defaults
    if let data = defaults?.data(forKey: Self.storageKey), data.count <= 256_000,
      let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
      var seen: Set<String> = []
      entries = Array(decoded.filter { Self.valid($0) && seen.insert($0.identity).inserted }.prefix(30))
      items = entries.map(\.item)
    } else if defaults?.object(forKey: Self.storageKey) != nil {
      defaults?.removeObject(forKey: Self.storageKey)
    }
  }
  /// Call after the user chooses Attach, never just for a search or preview.
  func record(_ item: KlipyService.Item) {
    guard item.adHTML == nil, let reference = item.reference else { return }
    let entry = Entry(reference: reference, width: item.width, height: item.height)
    guard Self.valid(entry) else { return }
    entries.removeAll { $0.identity == entry.identity }
    entries.insert(entry, at: 0); entries = Array(entries.prefix(30))
    items = entries.map(\.item)
    if let data = try? JSONEncoder().encode(entries), data.count <= 256_000 { defaults?.set(data, forKey: Self.storageKey) }
  }
  func clear() { entries = []; items = []; defaults?.removeObject(forKey: Self.storageKey) }

  private static func valid(_ entry: Entry) -> Bool {
    let reference = entry.reference
    guard reference.provider == "klipy", KlipyService.Category(rawValue: reference.category) != nil,
      !reference.id.isEmpty, reference.id.count <= 200, !reference.slug.isEmpty, reference.slug.count <= 200,
      reference.title.count <= 300, reference.size > 0, reference.size <= KlipyNetwork.maximumBytes,
      KlipyNetwork.allowedURL(reference.url, api: false), KlipyNetwork.allowedURL(reference.previewURL, api: false),
      (reference.kind == "gif" && reference.mime == "image/gif") || (reference.kind == "image" && ["image/jpeg", "image/png"].contains(reference.mime)) else { return false }
    if let width = entry.width, let height = entry.height { return KlipyService.Item.validDimensions(width: width, height: height) }
    return entry.width == nil && entry.height == nil
  }
}
