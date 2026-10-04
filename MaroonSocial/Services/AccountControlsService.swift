import Foundation
import Observation

struct NamedConnection: Decodable, Identifiable {
  let id: String
  let username: String
  let status: String
  let createdAt: Date
}
struct PrivateBlock: Decodable, Identifiable {
  let id: String
  let label: String
  let createdAt: Date
}
private struct AccountControlsResponse: Decodable {
  let connections: [NamedConnection]?
  let blocks: [PrivateBlock]?
  let notice: String?
}

@Observable @MainActor final class AccountControlsService {
  typealias Transport = @MainActor (String, [String: Any]) async throws -> Data
  private let transport: Transport
  var connections: [NamedConnection] = []
  var blocks: [PrivateBlock] = []
  var busy = false
  var loaded = false
  var error: String?
  var notice: String?
  var exportProgress: String?
  convenience init(social: SocialService) {
    self.init(transport: { action, payload in try await social.sendData(endpoint: "account-controls", action: action, payload: payload) })
  }
  init(transport: @escaping Transport) { self.transport = transport }
  @discardableResult func act(_ action: String, _ payload: [String: Any] = [:]) async -> Bool {
    guard !busy else { return false }
    busy = true; error = nil; notice = nil
    defer { busy = false }
    do {
      let data = try await transport(action, payload)
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      decoder.dateDecodingStrategy = .secondsSince1970
      let response = try decoder.decode(AccountControlsResponse.self, from: data)
      if let value = response.connections { connections = value }
      if let value = response.blocks { blocks = value }
      notice = response.notice
      loaded = true
      return true
    } catch {
      self.error = error.localizedDescription
      if let code = (error as? SocialServiceError)?.code, ["unauthorized", "forbidden"].contains(code) {
        connections = []; blocks = []; loaded = false
      }
      return false
    }
  }
  func exportData() async -> Data? {
    guard !busy else { return nil }
    busy = true; error = nil
    defer { busy = false; exportProgress = nil }
    do {
      var archive: [String: Any] = ["format_version": 1, "exported_at": ISO8601DateFormatter().string(from: .now),
        "scope": "Your account settings, authored content, memberships, preferences, submitted reports and media metadata. Media files, other people's messages, security credentials, verifier hashes and precise locations are excluded."]
      for section in ["account", "posts", "replies", "messages", "memberships", "communities", "activities", "media_metadata", "submitted_reports", "preferences"] {
        exportProgress = section.replacingOccurrences(of: "_", with: " ").capitalized
        var rows: [Any] = []
        var offset = 0
        while true {
          try Task.checkCancellation()
          let data = try await transport("export", ["section": section, "offset": offset])
          guard let page = try JSONSerialization.jsonObject(with: data) as? [String: Any], let value = page["data"], let more = page["has_more"] as? Bool else { throw URLError(.cannotParseResponse) }
          if let pageRows = value as? [Any] { rows += pageRows; archive[section] = rows }
          else { archive[section] = value }
          if !more { break }
          offset += 200
          guard offset <= 100_000 else { throw SocialServiceError(error: "This export is too large to prepare on this device. Contact the app owner for a complete export.", code: "export_limit") }
        }
      }
      return try JSONSerialization.data(withJSONObject: archive, options: [.prettyPrinted, .sortedKeys])
    } catch { self.error = error is CancellationError ? "Export cancelled. No file was saved." : error.localizedDescription; return nil }
  }
}
