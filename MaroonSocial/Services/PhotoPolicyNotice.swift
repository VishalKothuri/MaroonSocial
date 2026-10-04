import Foundation
import MaroonCore

/// Composition policy prompts shared by the post and chat composers. The
/// acknowledgement is per device; UI tests use a separate key that a fresh
/// `--uitesting` launch resets, so the real preference is never touched.
@MainActor enum PhotoPolicy {
  static let warningTitle = "Before you share a photo"
  static let warning = "No PII or human faces can be in the image. Posting them will cause a ban."
  static let shareTitle = "Share this image with other Aggies?"
  static let shareDetail = "It joins everyone’s meme library without your name. Keep people and personal details out of it."

  struct Acknowledgement {
    var read: () -> Bool
    var write: () -> Void
    static func local(_ defaults: UserDefaults = .standard, key: String = "maroon.photoPolicyAcknowledged") -> Self {
      Self(read: { defaults.bool(forKey: key) }, write: { defaults.set(true, forKey: key) })
    }
    static func forApplication(arguments: [String], defaults: UserDefaults = .standard) -> Self {
      let fixtures = arguments.contains("--uitesting") || arguments.contains("--uitesting-preserve")
      guard fixtures else { return .local(defaults) }
      let key = "maroon.photoPolicyAcknowledged.uiTests"
      if arguments.contains("--uitesting"), !arguments.contains("--uitesting-preserve") { defaults.removeObject(forKey: key) }
      return .local(defaults, key: key)
    }
  }
  static let acknowledgement = Acknowledgement.forApplication(arguments: ProcessInfo.processInfo.arguments)

  /// A user-supplied still image or GIF; KLIPY references and videos are not.
  static func isUserImage(_ attachment: MediaAttachment) -> Bool { attachment.klipy == nil && attachment.kind != .video }
  /// True exactly once per device: the first time a user-supplied image is attached.
  static func needsWarning(for attachment: MediaAttachment, using acknowledgement: Acknowledgement = acknowledgement) -> Bool {
    isUserImage(attachment) && !acknowledgement.read()
  }
  static func acknowledge(using acknowledgement: Acknowledgement = acknowledgement) { acknowledgement.write() }
  /// Sharing is offered for every user-supplied still image, whether it was
  /// composed in the editor or attached as picked, never for GIFs or videos.
  static func offersSharing(_ attachment: MediaAttachment) -> Bool { attachment.klipy == nil && attachment.kind == .image && !attachment.data.isEmpty }
}
