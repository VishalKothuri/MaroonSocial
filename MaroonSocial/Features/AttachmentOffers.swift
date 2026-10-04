import MaroonCore
import SwiftUI

/// What happens right after a user-supplied image lands in a draft: the one
/// time policy acknowledgement, then an offer to share it as a meme. Both are
/// view-local prompts so the global notice slot is never overwritten.
@Observable @MainActor final class AttachmentOffers {
  var policyWarning = false
  var shareOffer: MediaAttachment?
  var status: String?
  private var pendingShare: MediaAttachment?
  private var publishing = false
  @ObservationIgnored private let acknowledgement: PhotoPolicy.Acknowledgement
  init(acknowledgement: PhotoPolicy.Acknowledgement = PhotoPolicy.acknowledgement) { self.acknowledgement = acknowledgement }
  var shareOfferPresented: Bool { shareOffer != nil && !policyWarning }

  /// Call once an attachment has been assigned to the draft, never for previews.
  func arrived(_ attachment: MediaAttachment) {
    status = nil
    if PhotoPolicy.needsWarning(for: attachment, using: acknowledgement) {
      pendingShare = PhotoPolicy.offersSharing(attachment) ? attachment : nil
      policyWarning = true
    } else if PhotoPolicy.offersSharing(attachment) {
      shareOffer = attachment
    }
  }
  func acknowledgePolicy() {
    PhotoPolicy.acknowledge(using: acknowledgement)
    policyWarning = false
    if let pending = pendingShare { pendingShare = nil; shareOffer = pending }
  }
  func declineSharing() { shareOffer = nil; pendingShare = nil }
  func share(using service: SharedMemeService) {
    guard let attachment = shareOffer, !publishing else { return }
    shareOffer = nil; publishing = true; status = "Sharing to the meme library…"
    Task {
      defer { publishing = false }
      do {
        _ = try await service.publish(attachment)
        AppHaptics.shared.play(.success); status = "Shared to the meme library. Thanks!"
      } catch {
        AppHaptics.shared.play(.error); status = error.localizedDescription
      }
    }
  }
}

struct AttachmentOffersPresentation: ViewModifier {
  @Bindable var offers: AttachmentOffers
  let service: SharedMemeService
  func body(content: Content) -> some View {
    content
      .alert(PhotoPolicy.warningTitle, isPresented: $offers.policyWarning) {
        Button("I understand") { AppHaptics.shared.play(.selection); offers.acknowledgePolicy() }
      } message: { Text(PhotoPolicy.warning) }
      .confirmationDialog(PhotoPolicy.shareTitle, isPresented: Binding(get: { offers.shareOfferPresented }, set: { if !$0 { offers.declineSharing() } }), titleVisibility: .visible) {
        Button("Share as a meme") { AppHaptics.shared.play(.impact); offers.share(using: service) }
        Button("Not now", role: .cancel) { offers.declineSharing() }
      } message: { Text(PhotoPolicy.shareDetail) }
  }
}

extension View {
  func attachmentOffers(_ offers: AttachmentOffers, service: SharedMemeService) -> some View {
    modifier(AttachmentOffersPresentation(offers: offers, service: service))
  }
}
