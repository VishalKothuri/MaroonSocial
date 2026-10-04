import Foundation
import Observation

struct VerificationStatus: Decodable {
  var enabled: Bool
  var verified: Bool
  var verifiedAt: Date?
  var expiresAt: Date?
  var challengeID: String?
  var expiresIn: Int?
  var message: String?
  enum CodingKeys: String, CodingKey {
    case enabled, verified, message
    case verifiedAt = "verified_at", expiresAt = "expires_at", challengeID = "challenge_id", expiresIn = "expires_in"
  }
}
/// Mailbox possession verification. Does not assert current university enrollment.
@Observable @MainActor final class VerificationService {
  private(set) var status: VerificationStatus?
  private(set) var busy = false
  private(set) var challengeID: String?
  var error: String?
  var notice: String?
  typealias Transport = @MainActor (String, [String: Any]) async throws -> Data
  private let transport: Transport
  private var generation = 0
  private var expires: Date?
  private var wrongAttempts = 0
  init(social: SocialService) { transport = { action, payload in try await social.sendData(endpoint: "verification", action: action, payload: payload) } }
  init(transport: @escaping Transport) { self.transport = transport }
  func refresh() async {
    await perform("status")
  }
  @discardableResult func request(email: String) async -> Bool {
    await perform("request", ["email": email])
  }
  @discardableResult func confirm(code: String) async -> Bool {
    guard let challengeID else { error = "Request a new code first."; return false }
    guard expires == nil || expires! > .now else { self.challengeID = nil; error = "This code expired. Request a new one."; return false }
    guard code.trimmingCharacters(in: .whitespacesAndNewlines).range(of: "^[0-9]{6}$", options: .regularExpression) != nil else { error = "Enter the six-digit code from your email."; return false }
    return await perform("confirm", ["challenge_id": challengeID, "code": code])
  }
  func cancel() async {
    let id = challengeID
    generation += 1; challengeID = nil; expires = nil; busy = false
    if let id { _ = try? await transport("cancel", ["challenge_id": id]) }
  }
  @discardableResult private func perform(_ action: String, _ payload: [String: Any] = [:]) async -> Bool {
    guard !busy else { return false }
    if action == "request" { generation += 1 }
    let version = generation
    busy = true; error = nil
    defer { if version == generation { busy = false } }
    do {
      let data = try await transport(action, payload)
      let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
      let response = try decoder.decode(VerificationStatus.self, from: data)
      guard version == generation else {
        if action == "request", let id = response.challengeID { _ = try? await transport("cancel", ["challenge_id": id]) }
        return false
      }
      status = response
      if let id = response.challengeID { challengeID = id; expires = .now.addingTimeInterval(Double(response.expiresIn ?? 600)); wrongAttempts = 0 }
      if response.verified { challengeID = nil }
      notice = response.message
      return true
    } catch {
      guard version == generation else { return false }
      if action == "confirm", (error as? SocialServiceError)?.code == "invalid_code" {
        wrongAttempts += 1
        if wrongAttempts >= 5 { challengeID = nil; expires = nil }
      }
      self.error = error.localizedDescription
      return false
    }
  }
}
