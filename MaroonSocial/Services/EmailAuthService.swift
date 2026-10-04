import Auth
import Foundation
import Observation
import Security

/// Personal-email login and recovery. It never issues a university mailbox grant.
@Observable @MainActor final class EmailAuthService {
  struct Operations {
    var currentUserID: () -> String?
    var sendCode: (String) async throws -> Void
    var verifyCode: (String, String) async throws -> Void
    var accessToken: () async throws -> String
    var signOut: () async throws -> Void
  }
  typealias Availability = @MainActor () async throws -> Bool
  private let operations: Operations?
  private let availability: Availability
  private(set) var enabled = false
  private(set) var checkedAvailability = false
  private(set) var signedIn = false
  private(set) var busy = false
  private(set) var email = ""
  private(set) var codeSent = false
  private(set) var resendAfter = Date.distantPast
  var error: String?
  private var generation = 0
  private var verificationTask: Task<Void, Error>?
  private var signingOut = false
  var userID: String? { operations?.currentUserID() }

  init(operations: Operations? = nil, availability: Availability? = nil) {
    if let operations { self.operations = operations }
    else if let configURL = Bundle.main.url(forResource: "Backend", withExtension: "json"),
            let data = try? Data(contentsOf: configURL),
            let config = try? JSONDecoder().decode(BackendConfig.self, from: data) {
      let client = AuthClient(configuration: .init(
        url: config.url.appending(path: "auth/v1"), headers: ["apikey": config.publishableKey],
        storageKey: "personal-email-session-v1", localStorage: EmailSessionStorage(),
        autoRefreshToken: true, emitLocalSessionAsInitialSession: false))
      self.operations = Operations(
        currentUserID: { client.currentUser?.id.uuidString },
        sendCode: { try await client.signInWithOTP(email: $0, shouldCreateUser: true) },
        verifyCode: { _ = try await client.verifyOTP(email: $0, token: $1, type: .email) },
        accessToken: { try await client.session.accessToken },
        signOut: {
          // The SDK clears before its network request, but reports Keychain failures
          // only to its logger. Verify removal explicitly before reporting logout.
          try? await client.signOut(scope: .local)
          try EmailSessionStorage().remove(key: "personal-email-session-v1")
          guard client.currentSession == nil else { throw SocialServiceError(error: "Couldn’t clear the secure login session.", code: "secure_storage") }
        })
    } else { self.operations = nil }
    self.availability = availability ?? {
      guard let url = Bundle.main.url(forResource: "Backend", withExtension: "json") else { throw URLError(.badURL) }
      let config = try JSONDecoder().decode(BackendConfig.self, from: Data(contentsOf: url))
      var request = URLRequest(url: config.url.appending(path: "functions/v1/auth-account"))
      request.httpMethod = "POST"; request.timeoutInterval = 15
      request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = Data(#"{"action":"capabilities"}"#.utf8)
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw URLError(.badServerResponse) }
      struct Capabilities: Decodable { var enabled: Bool }
      return try JSONDecoder().decode(Capabilities.self, from: data).enabled
    }
    signedIn = self.operations?.currentUserID() != nil
  }
  static func unavailableForFixtures() -> EmailAuthService {
    EmailAuthService(operations: .init(currentUserID: { nil }, sendCode: { _ in throw URLError(.unsupportedURL) },
      verifyCode: { _, _ in throw URLError(.unsupportedURL) }, accessToken: { throw URLError(.userAuthenticationRequired) }, signOut: {}), availability: { false })
  }
  func checkAvailability() async {
    do { enabled = try await availability(); checkedAvailability = true }
    catch { enabled = false; checkedAvailability = true; self.error = "Couldn’t check email login. Please retry." }
  }
  @discardableResult func requestCode(_ address: String) async -> Bool {
    guard !busy else { return false }
    let address = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard address.count <= 254, address.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil else {
      error = "Enter a valid personal email address."; return false
    }
    guard Date.now >= resendAfter || address != email else { error = "Please wait a minute before requesting another code."; return false }
    busy = true; error = nil; let epoch = generation
    defer { if generation == epoch { busy = false } }
    do {
      let available = try await availability()
      guard epoch == generation else { return false }
      enabled = available; checkedAvailability = true
      guard available, let operations else { throw SocialServiceError(error: "Email login is not available until the app owner finishes email delivery setup.", code: "not_configured") }
      try await operations.sendCode(address)
      guard epoch == generation else { return false }
      email = address; codeSent = true; resendAfter = .now.addingTimeInterval(60)
      return true
    } catch { if epoch == generation { self.error = error.localizedDescription }; return false }
  }
  @discardableResult func verifyCode(_ value: String) async -> Bool {
    guard !busy, codeSent, let operations else { return false }
    let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value.range(of: #"^\d{6}$"#, options: .regularExpression) != nil else { error = "Enter the six-digit code from your email."; return false }
    busy = true; error = nil; let epoch = generation
    defer { if generation == epoch { busy = false } }
    do {
      let address = email
      let task = Task { try await operations.verifyCode(address, value) }
      verificationTask = task
      defer { verificationTask = nil }
      try await task.value
      guard epoch == generation else { return false }
      signedIn = operations.currentUserID() != nil
      guard signedIn else { throw SocialServiceError(error: "The login did not return a session. Request another code.", code: "unauthorized") }
      codeSent = false
      return true
    } catch { if epoch == generation { self.error = error.localizedDescription }; return false }
  }
  func accessToken() async throws -> String {
    guard let operations else { throw SocialServiceError(error: "Email login is unavailable.", code: "not_configured") }
    guard !signingOut else { throw CancellationError() }
    let epoch = generation
    do {
      let value = try await operations.accessToken()
      guard epoch == generation else { throw CancellationError() }
      signedIn = true; return value
    } catch { if epoch == generation { signedIn = operations.currentUserID() != nil }; throw error }
  }
  /// The service endpoint revokes this session first. SDK logout then clears its Keychain copy.
  func signOutLocally() async throws {
    guard !signingOut else { throw CancellationError() }
    generation += 1; signingOut = true; busy = true; codeSent = false; email = ""; error = nil
    defer { signingOut = false; busy = false }
    // OTP verification persists its session inside the SDK. Drain it before
    // removal so a late response cannot restore a session after logout.
    _ = try? await verificationTask?.value
    try await operations?.signOut()
    signedIn = false
  }
  func changeEmail() { guard !busy else { return }; codeSent = false; error = nil }
}

/// Refresh tokens are device-only Keychain items, never UserDefaults or the social cache.
struct EmailSessionStorage: AuthLocalStorage {
  private func query(_ key: String) -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: "app.maroonsocial.email-auth", kSecAttrAccount as String: key]
  }
  func store(key: String, value: Data) throws {
    let match = query(key)
    let updated = SecItemUpdate(match as CFDictionary, [kSecValueData as String: value] as CFDictionary)
    if updated == errSecSuccess { return }
    guard updated == errSecItemNotFound else { throw secureError(updated) }
    var item = match; item[kSecValueData as String] = value
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else { throw secureError(status) }
  }
  func retrieve(key: String) throws -> Data? {
    var match = query(key); match[kSecReturnData as String] = true; match[kSecMatchLimit as String] = kSecMatchLimitOne
    var value: CFTypeRef?
    let status = SecItemCopyMatching(match as CFDictionary, &value)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw secureError(status) }
    return value as? Data
  }
  func remove(key: String) throws {
    let status = SecItemDelete(query(key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw secureError(status) }
  }
  private func secureError(_ status: OSStatus) -> SocialServiceError {
    SocialServiceError(error: "Couldn’t access the secure login session (\(status)). Please use a signed app build.", code: "secure_storage")
  }
}
