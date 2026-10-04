import Foundation
import Observation
import Security
import UIKit
import UserNotifications

struct PushPreferences: Codable, Equatable {
  var enabled = true
  var messages = true
  var games = true
  var calls = true
  var activity = true
}
struct PushDestination: Equatable {
  let kind: String
  let roomID: String?
  let reference: String
  init?(userInfo: [AnyHashable: Any]) {
    guard let value = userInfo["maroon"] as? [String: Any],
          let kind = value["kind"] as? String,
          ["message", "request", "game_invite", "game_turn", "call", "group_call", "activity"].contains(kind),
          let reference = value["reference"] as? String, UUID(uuidString: reference) != nil else { return nil }
    self.kind = kind; self.reference = reference
    self.roomID = (value["room_id"] as? String).flatMap { $0.count <= 160 ? $0 : nil }
  }
}
private struct PushResponse: Decodable {
  var preferences: PushPreferences?
  var registered: Bool?
  var deliveryConfigured: Bool
  enum CodingKeys: String, CodingKey { case preferences, registered; case deliveryConfigured = "delivery_configured" }
}

/// Created without touching Keychain. Tests/fixtures must never call configure.
@Observable @MainActor final class PushService {
  static let shared = PushService()
  private(set) var preferences = PushPreferences()
  private(set) var authorization: UNAuthorizationStatus = .notDetermined
  private(set) var configured = false
  private(set) var registered = false
  private(set) var busy = false
  var error: String?
  var destination: PushDestination?
  private var social: SocialService?
  private var generation = 0
  private var deviceToken: String?
  private var registration: Task<Void, Never>?
  private var installation: PushInstallation?

  func configure(social: SocialService) async {
    self.social = social; generation += 1
    let epoch = generation
    authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    guard epoch == generation else { return }
    do { installation = try PushInstallation.loadOrCreate() }
    catch { self.error = error.localizedDescription; return }
    await refresh()
    guard epoch == generation else { return }
    if [.authorized, .provisional, .ephemeral].contains(authorization) { UIApplication.shared.registerForRemoteNotifications() }
  }
  func refresh() async {
    guard let social, let installation else { return }
    let epoch = generation
    do {
      let data = try await social.sendData(endpoint: "push-devices", action: "status", payload: ["installation_id": installation.id, "environment": Bundle.main.object(forInfoDictionaryKey: "APNSEnvironment") as? String ?? ""])
      guard epoch == generation else { return }
      apply(try JSONDecoder().decode(PushResponse.self, from: data)); error = nil
    } catch { if epoch == generation { self.error = error.localizedDescription } }
  }
  func enable() async {
    guard !busy else { return }; busy = true; defer { busy = false }
    let epoch = generation
    do {
      _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
      guard epoch == generation else { return }
      authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
      if [.authorized, .provisional, .ephemeral].contains(authorization) { UIApplication.shared.registerForRemoteNotifications() }
    } catch { if epoch == generation { self.error = error.localizedDescription } }
  }
  func update(_ value: PushPreferences) async {
    guard !busy, let social else { return }; busy = true; defer { busy = false }
    let epoch = generation
    do {
      let bytes = try JSONEncoder().encode(value)
      var payload = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
      payload["environment"] = Bundle.main.object(forInfoDictionaryKey: "APNSEnvironment") as? String ?? ""
      let data = try await social.sendData(endpoint: "push-devices", action: "preferences.set", payload: payload)
      guard epoch == generation else { return }
      apply(try JSONDecoder().decode(PushResponse.self, from: data)); error = nil
    } catch { if epoch == generation { self.error = error.localizedDescription } }
  }
  func received(token: Data) {
    deviceToken = token.map { String(format: "%02x", $0) }.joined()
    registration?.cancel()
    registration = Task { await register() }
  }
  func registrationFailed(_ failure: Error) { error = "This device could not register for notifications: \(failure.localizedDescription)" }
  private func register() async {
    guard let social, installation != nil, let deviceToken else { return }
    let epoch = generation
    guard let environment = Bundle.main.object(forInfoDictionaryKey: "APNSEnvironment") as? String,
          ["sandbox", "production"].contains(environment) else { error = "This build has no push environment configured."; return }
    do {
      let proof = try nextProof()
      let data = try await social.sendData(endpoint: "push-devices", action: "register", payload: ["installation_id": proof.id, "installation_secret": proof.secret, "sequence": proof.sequence, "token": deviceToken, "environment": environment])
      guard epoch == generation, !Task.isCancelled else { return }
      apply(try JSONDecoder().decode(PushResponse.self, from: data)); error = nil
    } catch { if epoch == generation, !Task.isCancelled { self.error = error.localizedDescription } }
  }
  /// Call before account logout/deletion. The installation proof permits cleanup
  /// even after the account session has expired. Failure is surfaced to the owner.
  @discardableResult func unregister() async -> Bool {
    generation += 1
    let pendingRegistration = registration; registration = nil
    let previousSocial = social
    social = nil; registered = false; destination = nil
    guard installation != nil else { return true }
    await pendingRegistration?.value
    do {
      let installation = try nextProof()
      guard let url = Bundle.main.url(forResource: "Backend", withExtension: "json") else { throw URLError(.badURL) }
      let config = try JSONDecoder().decode(BackendConfig.self, from: Data(contentsOf: url))
      var request = URLRequest(url: config.url.appending(path: "functions/v1/push-devices"))
      request.httpMethod = "POST"; request.timeoutInterval = 15
      request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONSerialization.data(withJSONObject: ["action": "unregister", "installation_id": installation.id, "installation_secret": installation.secret, "sequence": installation.sequence])
      let (_, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
      UIApplication.shared.unregisterForRemoteNotifications(); error = nil
      return true
    } catch { social = previousSocial; self.error = "Device notifications could not be disabled yet. Retry before signing out."; return false }
  }
  private func nextProof() throws -> PushInstallation {
    guard var value = installation else { throw URLError(.userAuthenticationRequired) }
    value.sequence += 1; try value.save(); installation = value; return value
  }
  private func apply(_ value: PushResponse) {
    if let preferences = value.preferences { self.preferences = preferences }
    if let registered = value.registered { self.registered = registered }
    configured = value.deliveryConfigured
  }
}

private struct PushInstallation: Codable {
  let id: String
  let secret: String
  var sequence: Int
  func save() throws {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "app.maroonsocial.push", kSecAttrAccount as String: "installation-v1"]
    let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: try JSONEncoder().encode(self)] as CFDictionary)
    guard status == errSecSuccess else { throw ChatCredentialError(status: status) }
  }
  static func loadOrCreate() throws -> Self {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "app.maroonsocial.push", kSecAttrAccount as String: "installation-v1"]
    var lookup = query; lookup[kSecReturnData as String] = true; lookup[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?; let status = SecItemCopyMatching(lookup as CFDictionary, &item)
    if status == errSecSuccess, let data = item as? Data { return try JSONDecoder().decode(Self.self, from: data) }
    guard status == errSecItemNotFound else { throw ChatCredentialError(status: status) }
    var bytes = [UInt8](repeating: 0, count: 32)
    let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    guard randomStatus == errSecSuccess else { throw ChatCredentialError(status: randomStatus) }
    let value = Self(id: UUID().uuidString, secret: bytes.map { String(format: "%02x", $0) }.joined(), sequence: 0)
    var insert = query; insert[kSecValueData as String] = try JSONEncoder().encode(value)
    insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let addStatus = SecItemAdd(insert as CFDictionary, nil)
    guard addStatus == errSecSuccess else { throw ChatCredentialError(status: addStatus) }
    return value
  }
}

final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
  }
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Task { @MainActor in PushService.shared.received(token: deviceToken) }
  }
  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    Task { @MainActor in PushService.shared.registrationFailed(error) }
  }
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // Foreground messages remain in the app; no duplicate banner interrupts typing.
    completionHandler([])
  }
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    let destination = PushDestination(userInfo: response.notification.request.content.userInfo)
    Task { @MainActor in PushService.shared.destination = destination; completionHandler() }
  }
}
