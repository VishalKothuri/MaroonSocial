import ImageIO
import MaroonCore
import UIKit
import XCTest
@testable import MaroonSocial

@MainActor final class ImageEditorTests: XCTestCase {
  private func bitmap(width: Int, height: Int, color: UIColor) -> CGImage {
    let format = UIGraphicsImageRendererFormat(); format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
      color.setFill(); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }.cgImage!
  }
  private func pixel(_ image: CGImage, x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
    var bytes = [UInt8](repeating: 0, count: 4)
    let context = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
    return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]))
  }

  func testExportIsBoundedAndDrawsOverlaysWhereTheCanvasPlacedThem() async throws {
    let base = bitmap(width: 1600, height: 1200, color: .blue)
    XCTAssertEqual(ImageComposer.outputSize(for: base), CGSize(width: 1280, height: 960))
    let sticker = bitmap(width: 100, height: 100, color: .red)
    let items = [
      ImageEditorItem(content: .sticker(original: sticker, cutout: nil, usesCutout: false), center: CGPoint(x: 0.25, y: 0.25)),
      ImageEditorItem(content: .text("HOWDY", colorIndex: 0), center: CGPoint(x: 0.5, y: 0.8)),
    ]
    let rendered = try XCTUnwrap(ImageComposer.render(base: base, items: items).cgImage)
    XCTAssertEqual(rendered.width, 1280); XCTAssertEqual(rendered.height, 960)
    let atSticker = pixel(rendered, x: 320, y: 240)
    XCTAssertGreaterThan(atSticker.r, 200, "The sticker's centre is drawn at a quarter of the width and height: \(atSticker)")
    XCTAssertLessThan(atSticker.b, 80)
    let untouched = pixel(rendered, x: 1200, y: 100)
    XCTAssertGreaterThan(untouched.b, 200, "Areas without overlays keep the base image: \(untouched)")
    let plain = try XCTUnwrap(ImageComposer.render(base: base, items: []).cgImage)
    let textRegion = (560..<720).map { pixel(rendered, x: $0, y: 768) }
    XCTAssertTrue(textRegion.contains { $0.r > 180 && $0.g > 180 }, "White stroked text must change pixels along its baseline")
    XCTAssertEqual(pixel(plain, x: 640, y: 768).b > 200, true)
    let attachment = try await ImageComposer.attachment(base: base, items: items)
    XCTAssertEqual(attachment.kind, .image); XCTAssertNil(attachment.klipy)
    XCTAssertLessThanOrEqual(attachment.data.count, MediaCompression.maximumOutputBytes)
    XCTAssertEqual(Array(attachment.data.prefix(2)), [0xff, 0xd8])
    let source = try XCTUnwrap(CGImageSourceCreateWithData(attachment.data as CFData, nil))
    let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    XCTAssertLessThanOrEqual(properties[kCGImagePropertyPixelWidth] as? Int ?? .max, 1280)
    XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
  }

  func testOverlayGeometryIsProportionalToTheDrawingWidth() {
    let narrow = ImageComposer.textBounds("Group chat energy", width: 500, scale: 1, colorIndex: 0)
    let wide = ImageComposer.textBounds("Group chat energy", width: 1000, scale: 1, colorIndex: 0)
    XCTAssertEqual(wide.width / narrow.width, 2, accuracy: 0.25, "Text keeps its share of the image at any display width")
    let larger = ImageComposer.textBounds("Group chat energy", width: 500, scale: 2, colorIndex: 0)
    XCTAssertGreaterThan(larger.width, narrow.width * 1.6)
    let sticker = bitmap(width: 200, height: 100, color: .green)
    let size = ImageComposer.stickerSize(sticker, width: 1000, scale: 1)
    XCTAssertEqual(size.width, 420, accuracy: 0.5); XCTAssertEqual(size.height, 210, accuracy: 0.5)
    XCTAssertEqual(ImageComposer.stickerSize(sticker, width: 1000, scale: 0.5).width, 210, accuracy: 0.5)
    XCTAssertEqual(ImageComposer.clamped(CGPoint(x: -0.4, y: 1.7)), CGPoint(x: 0, y: 1))
    let frame = ImageEditorView.fittedFrame(for: bitmap(width: 400, height: 200, color: .gray), in: CGSize(width: 300, height: 600))
    XCTAssertEqual(frame, CGRect(x: 0, y: 225, width: 300, height: 150))
  }

  func testCutOutKeepsAlphaOrReportsNoSubjectWithoutCrashing() async {
    let format = UIGraphicsImageRendererFormat(); format.scale = 1
    let image = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 320), format: format).image { context in
      UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 320, height: 320))
      UIColor.black.setFill(); context.cgContext.fillEllipse(in: CGRect(x: 80, y: 60, width: 160, height: 200))
    }.cgImage!
    do {
      let cut = try await StickerCutout.cutOut(image)
      XCTAssertLessThanOrEqual(cut.width, 320); XCTAssertLessThanOrEqual(cut.height, 320)
      XCTAssertTrue([.premultipliedLast, .premultipliedFirst, .last, .first].contains(cut.alphaInfo), "A cut-out keeps an alpha channel: \(cut.alphaInfo.rawValue)")
    } catch let failure as StickerCutout.Failure {
      XCTAssertTrue([.noSubject, .failed].contains(failure), "Synthetic images may have no liftable subject; the failure is a clear message")
      XCTAssertFalse(failure.localizedDescription.isEmpty)
    } catch { XCTFail("Unexpected error \(error)") }
  }

  func testPhotoPolicyWarnsOnceAndOffersSharingOnlyForUserStills() throws {
    let suite = "ImageEditorTests." + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
    let acknowledgement = PhotoPolicy.Acknowledgement.local(defaults, key: "policy")
    let photo = MediaAttachment(kind: .image, data: Data([0xff, 0xd8, 0xff]))
    let gif = MediaAttachment(kind: .gif, data: Data([0x47]))
    let video = MediaAttachment(kind: .video, data: Data([0x00]))
    let klipy = MediaAttachment(klipy: KlipyReference(id: "1", slug: "s", title: "t", category: "static-memes", kind: "image", mime: "image/png", url: "https://static.klipy.com/a.png", previewURL: "https://static.klipy.com/a.png", size: 10))
    XCTAssertTrue(PhotoPolicy.needsWarning(for: photo, using: acknowledgement))
    XCTAssertTrue(PhotoPolicy.needsWarning(for: gif, using: acknowledgement))
    XCTAssertFalse(PhotoPolicy.needsWarning(for: video, using: acknowledgement))
    XCTAssertFalse(PhotoPolicy.needsWarning(for: klipy, using: acknowledgement), "Provider media is not an upload")
    PhotoPolicy.acknowledge(using: acknowledgement)
    XCTAssertFalse(PhotoPolicy.needsWarning(for: photo, using: acknowledgement), "The warning is shown once per device")
    XCTAssertTrue(PhotoPolicy.offersSharing(photo)); XCTAssertFalse(PhotoPolicy.offersSharing(gif)); XCTAssertFalse(PhotoPolicy.offersSharing(klipy))
    XCTAssertEqual(PhotoPolicy.warning, "No PII or human faces can be in the image. Posting them will cause a ban.")
    // --uitesting launches use a separate key and reset it; real preferences stay untouched.
    defaults.set(true, forKey: "maroon.photoPolicyAcknowledged"); defaults.set(true, forKey: "maroon.photoPolicyAcknowledged.uiTests")
    let fresh = PhotoPolicy.Acknowledgement.forApplication(arguments: ["--uitesting"], defaults: defaults)
    XCTAssertFalse(fresh.read()); XCTAssertTrue(defaults.bool(forKey: "maroon.photoPolicyAcknowledged"))
    let preserved = PhotoPolicy.Acknowledgement.forApplication(arguments: ["--uitesting-preserve"], defaults: defaults)
    fresh.write(); XCTAssertTrue(preserved.read())
  }

  func testAttachmentOffersSequencePolicyThenSharingAndNeverSharesProviderMedia() async throws {
    var acknowledged = false
    let acknowledgement = PhotoPolicy.Acknowledgement(read: { acknowledged }, write: { acknowledged = true })
    let offers = AttachmentOffers(acknowledgement: acknowledgement)
    let photo = MediaAttachment(kind: .image, data: Data([0xff, 0xd8, 0xff]))
    offers.arrived(photo)
    XCTAssertTrue(offers.policyWarning); XCTAssertFalse(offers.shareOfferPresented, "The policy alert comes first")
    offers.acknowledgePolicy()
    XCTAssertTrue(acknowledged); XCTAssertFalse(offers.policyWarning)
    XCTAssertTrue(offers.shareOfferPresented, "Then the same image is offered for sharing")
    var published: [String] = []
    let service = SharedMemeService { action, payload in
      published.append(action)
      XCTAssertEqual(payload["title"] as? String, "")
      XCTAssertNotNil(payload["data"] as? String)
      return Data(#"{"meme_id":"m1"}"#.utf8)
    }
    offers.share(using: service)
    XCTAssertFalse(offers.shareOfferPresented)
    for _ in 0..<50 where offers.status?.hasPrefix("Shared") != true { try await Task.sleep(for: .milliseconds(20)) }
    XCTAssertEqual(published, ["meme.publish"])
    XCTAssertEqual(offers.status, "Shared to the meme library. Thanks!")
    offers.arrived(MediaAttachment(kind: .gif, data: Data([0x47])))
    XCTAssertFalse(offers.policyWarning); XCTAssertFalse(offers.shareOfferPresented, "GIFs are never offered as memes")
    offers.arrived(photo); XCTAssertTrue(offers.shareOfferPresented)
    offers.declineSharing(); XCTAssertFalse(offers.shareOfferPresented)
    XCTAssertEqual(published.count, 1, "Declining never publishes")
  }
}
