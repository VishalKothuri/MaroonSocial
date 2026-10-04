import ImageIO
import MaroonCore
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import MaroonSocial

@MainActor final class MemeRendererTests: XCTestCase {
  func testOriginalTemplatesExportRealJPEGWithBoundedDimensionsAndNoMetadata() throws {
    for template in MemeTemplate.allCases {
      let attachment = try MemeRenderer.attachment(photo: nil, template: template, top: "When the exam is tomorrow", bottom: "And the group chat finally wakes up")
      XCTAssertEqual(attachment.kind, .image)
      XCTAssertLessThanOrEqual(attachment.data.count, MemeRenderer.maximumBytes)
      XCTAssertEqual(Array(attachment.data.prefix(2)), [0xff, 0xd8])
      let source = try XCTUnwrap(CGImageSourceCreateWithData(attachment.data as CFData, nil))
      let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
      XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 1200)
      XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 1200)
      XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
      XCTAssertEqual(CGImageSourceGetCount(source), 1)
      let blank = try MemeRenderer.attachment(photo: nil, template: template, top: "", bottom: "")
      XCTAssertNotEqual(attachment.data, blank.data, "Captions must be present in the exported pixels")
    }
  }
  func testPhotoDecodeCorrectsOrientationAndExportStripsLocation() throws {
    let format = UIGraphicsImageRendererFormat(); format.scale = 1
    let image = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200), format: format).image { context in UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 300, height: 200)) }
    let tagged = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(tagged, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), [kCGImagePropertyOrientation: 6, kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 30.6, kCGImagePropertyGPSLatitudeRef: "N", kCGImagePropertyGPSLongitude: 96.3, kCGImagePropertyGPSLongitudeRef: "W"]] as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    let decoded = try MemeRenderer.photo(from: tagged as Data)
    XCTAssertEqual(decoded.imageOrientation, .up)
    XCTAssertLessThan(decoded.size.width, decoded.size.height)
    let output = try MemeRenderer.attachment(photo: decoded, template: .maroon, top: "Photo meme", bottom: "No location data")
    let source = try XCTUnwrap(CGImageSourceCreateWithData(output.data as CFData, nil))
    let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    XCTAssertNil(props[kCGImagePropertyGPSDictionary])
    XCTAssertLessThanOrEqual(props[kCGImagePropertyPixelWidth] as? Int ?? Int.max, 1200)
    XCTAssertLessThanOrEqual(props[kCGImagePropertyPixelHeight] as? Int ?? Int.max, 1200)
  }
  func testLongCaptionsAndInvalidImageCannotProduceUnboundedAttachments() throws {
    XCTAssertThrowsError(try MemeRenderer.photo(from: Data("not an image".utf8)))
    XCTAssertThrowsError(try MemeRenderer.image(photo: nil, template: .maroon, top: String(repeating: "a", count: 161), bottom: ""))
    let output = try MemeRenderer.attachment(photo: nil, template: .midnight, top: String(repeating: "Long caption ", count: 12), bottom: String(repeating: "🙂", count: 160))
    XCTAssertLessThanOrEqual(output.data.count, 5_000_000)
    XCTAssertNotNil(UIImage(data: output.data))
  }
}
