import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import MaroonSocial

@MainActor final class MediaCompressionTests: XCTestCase {
  private func bitmap(width: Int = 80, height: Int = 40, color: UIColor = .red) throws -> CGImage {
    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
    return try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
      color.setFill(); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }.cgImage)
  }
  private func encode(_ image: CGImage, type: UTType = .jpeg, properties: [CFString: Any] = [:]) throws -> Data {
    let output = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination)); return output as Data
  }
  private func properties(_ data: Data) throws -> [CFString: Any] {
    let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
  }
  /// Minimal valid 1×1 GIF frames use alternating red/blue global palette
  /// indices. Building the blocks directly avoids encoder frame coalescing.
  private func tinyGIF(delays: [UInt16]) -> Data {
    var bytes = Array("GIF89a".utf8) + [1, 0, 1, 0, 0x80, 0, 0, 255, 0, 0, 0, 0, 255]
    for (index, delay) in delays.enumerated() {
      bytes += [0x21, 0xf9, 4, 4, UInt8(delay & 255), UInt8(delay >> 8), 0, 0]
      bytes += [0x2c, 0, 0, 0, 0, 1, 0, 1, 0, 0]
      bytes += [2, 2, index.isMultiple(of: 2) ? 0x44 : 0x4c, 1, 0]
    }
    bytes.append(0x3b); return Data(bytes)
  }
  private func rgb(_ image: CGImage) throws -> [UInt8] {
    var pixel = [UInt8](repeating: 0, count: 4)
    try pixel.withUnsafeMutableBytes { bytes in
      let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
      context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    return Array(pixel.prefix(3))
  }
  func testLargeOriginalIsCompressedInsteadOfRejectedAndStaysReadableSize() async throws {
    // Deterministic high-entropy PNG exceeds the old 5MB input gate.
    let width = 1800, height = 1200
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    var random: UInt32 = 17
    for index in pixels.indices where index % 4 != 3 {
      random = random &* 1664525 &+ 1013904223; pixels[index] = UInt8(truncatingIfNeeded: random >> 24)
    }
    let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
    let image = try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    let source = try encode(image, type: .png)
    XCTAssertGreaterThan(source.count, 5_000_000)
    let result = try await MediaCompression.prepare(source)
    XCTAssertFalse(result.animated); XCTAssertLessThanOrEqual(result.data.count, 350_000)
    let props = try properties(result.data)
    let outputWidth = try XCTUnwrap(props[kCGImagePropertyPixelWidth] as? Int)
    XCTAssertLessThanOrEqual(outputWidth, 1280); XCTAssertGreaterThanOrEqual(outputWidth, 800)
    XCTAssertNotNil(UIImage(data: result.data))
  }
  func testOrientationIsAppliedAndLocationAndCaptureMetadataAreRemoved() async throws {
    let input = try encode(bitmap(width: 300, height: 150), properties: [
      kCGImagePropertyOrientation: 6,
      kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 30.6, kCGImagePropertyGPSLatitudeRef: "N"],
      kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:10:03 12:34:56"],
      kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFArtist: "Private owner"]])
    let result = try await MediaCompression.prepare(input)
    let props = try properties(result.data)
    XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 150)
    XCTAssertEqual(props[kCGImagePropertyPixelHeight] as? Int, 300)
    XCTAssertNil(props[kCGImagePropertyGPSDictionary])
    let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
    XCTAssertNil(exif?[kCGImagePropertyExifDateTimeOriginal])
    XCTAssertTrue(Set((exif ?? [:]).keys).isSubset(of: [kCGImagePropertyExifColorSpace, kCGImagePropertyExifPixelXDimension, kCGImagePropertyExifPixelYDimension]), "Only generated color/dimension fields may remain.")
    XCTAssertNil((props[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFArtist])
  }
  func testGIFKeepsDistinctFramesTimingAndLoopCountAfterSanitizing() async throws {
    let output = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, UTType.gif.identifier as CFString, 2, nil))
    CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 3]] as CFDictionary)
    for (color, delay) in [(UIColor.red, 0.12), (UIColor.blue, 0.37)] {
      CGImageDestinationAddImage(destination, try bitmap(width: 900, height: 600, color: color), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: delay, kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
    }
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    let result = try await MediaCompression.prepare(output as Data)
    XCTAssertTrue(result.animated); XCTAssertLessThan(result.data.count, 1_500_000)
    let source = try XCTUnwrap(CGImageSourceCreateWithData(result.data as CFData, nil))
    XCTAssertEqual(CGImageSourceGetCount(source), 2)
    let global = try XCTUnwrap(CGImageSourceCopyProperties(source, nil) as? [CFString: Any])
    XCTAssertEqual((global[kCGImagePropertyGIFDictionary] as? [CFString: Any])?[kCGImagePropertyGIFLoopCount] as? Int, 3)
    var frames: [Data] = []
    for index in 0..<2 {
      let frame = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, index, nil))
      XCTAssertLessThanOrEqual(max(frame.width, frame.height), 480)
      frames.append(try XCTUnwrap(frame.dataProvider?.data) as Data)
      let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any])
      let timing = try XCTUnwrap(props[kCGImagePropertyGIFDictionary] as? [CFString: Any])
      XCTAssertEqual(try XCTUnwrap(timing[kCGImagePropertyGIFUnclampedDelayTime] as? Double), [0.12, 0.37][index], accuracy: 0.011)
      XCTAssertNil(props[kCGImagePropertyGPSDictionary])
    }
    XCTAssertNotEqual(frames[0], frames[1], "A compressed GIF must remain animated, not repeat a still frame.")
  }
  func testLongGIFSamplingIncludesEndAndPreservesFullTimelineWithinDisplayBudget() async throws {
    let data = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, 120, nil))
    CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 2]] as CFDictionary)
    let red = try bitmap(width: 900, height: 600), blue = try bitmap(width: 900, height: 600, color: .blue)
    for index in 0..<120 {
      let delay = index == 60 ? 0.37 : 0.02
      CGImageDestinationAddImage(destination, index == 119 ? blue : red,
        [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay]] as CFDictionary)
    }
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    let compressed = try await MediaCompression.prepare(data as Data)
    let source = try XCTUnwrap(CGImageSourceCreateWithData(compressed.data as CFData, nil))
    let count = CGImageSourceGetCount(source)
    XCTAssertLessThanOrEqual(count, 80); XCTAssertGreaterThan(count, 1)
    let display = try MediaCompression.displayFrames(compressed.data)
    XCTAssertEqual(display.frames.count, count, "Every exported frame must be displayed; no truncated remainder.")
    XCTAssertEqual(display.duration, 119 * 0.02 + 0.37, accuracy: 0.015)
    XCTAssertEqual(display.loopCount, 2)
    XCTAssertLessThanOrEqual(display.frames.reduce(0) { $0 + $1.width * $1.height }, 12_000_000)
    XCTAssertNotEqual(try XCTUnwrap(display.frames.first?.dataProvider?.data) as Data, try XCTUnwrap(display.frames.last?.dataProvider?.data) as Data)
    // Older uncompressed >90-frame uploads use the same bounded whole-timeline
    // selection at display time, so their final frame is not silently lost.
    let legacy = try MediaCompression.displayFrames(data as Data)
    XCTAssertEqual(legacy.frames.count, 80); XCTAssertEqual(legacy.duration, display.duration, accuracy: 0.015)
    XCTAssertEqual(legacy.loopCount, 2)
    XCTAssertLessThanOrEqual(legacy.frames.reduce(0) { $0 + $1.width * $1.height }, 12_000_000)
    XCTAssertNotEqual(try XCTUnwrap(legacy.frames.first?.dataProvider?.data) as Data, try XCTUnwrap(legacy.frames.last?.dataProvider?.data) as Data)
  }
  func testMixedZeroDelaysKeepTheSameDurationWhenMoreThan80FramesAreSampled() async throws {
    let input = tinyGIF(delays: (0..<120).map { [UInt16(0), 2, 7][$0 % 3] })
    let source = try XCTUnwrap(CGImageSourceCreateWithData(input as CFData, nil))
    XCTAssertEqual(CGImageSourceGetCount(source), 120)
    let original = try MediaCompression.displayFrames(input)
    XCTAssertEqual(original.duration, 7.6, accuracy: 0.015)
    let compressed = try await MediaCompression.prepare(input)
    let output = try MediaCompression.displayFrames(compressed.data)
    XCTAssertEqual(output.frames.count, 80)
    XCTAssertEqual(output.duration, original.duration, accuracy: 0.015)
  }
  func testNativeGIFUsesUnequalFrameTimingStopsAtEndAndHonorsPause() async throws {
    let data = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, 2, nil))
    CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 1]] as CFDictionary)
    for (color, delay) in [(UIColor.red, 0.2), (UIColor.blue, 0.3)] {
      CGImageDestinationAddImage(destination, try bitmap(color: color), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay]] as CFDictionary)
    }
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    let encoded = try MediaCompression.displayFrames(data as Data)
    XCTAssertEqual(encoded.loopCount, 1, "Fixture explicitly requests one repeat after the initial play.")
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    let window = UIWindow(windowScene: scene); let controller = UIViewController(); window.rootViewController = controller
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 160, height: 80)); controller.view.addSubview(imageView); window.isHidden = false
    let coordinator = AnimatedMedia.Coordinator()
    defer { coordinator.stop(imageView); window.isHidden = true }
    coordinator.display(data as Data, in: imageView, animate: true)
    for _ in 0..<100 {
      if imageView.layer.animation(forKey: AnimatedMedia.Coordinator.animationKey) != nil { break }
      try await Task.sleep(for: .milliseconds(10))
    }
    let animation = try XCTUnwrap(imageView.layer.animation(forKey: AnimatedMedia.Coordinator.animationKey) as? CAKeyframeAnimation)
    XCTAssertEqual(animation.duration, 0.5, accuracy: 0.015)
    XCTAssertEqual(animation.keyTimes?[1].doubleValue ?? 0, 0.4, accuracy: 0.02)
    try await Task.sleep(for: .milliseconds(280))
    let middle = try XCTUnwrap(imageView.layer.presentation()?.contents) as! CGImage
    try await Task.sleep(for: .milliseconds(850))
    let ended = try XCTUnwrap(imageView.layer.presentation()?.contents) as! CGImage
    let middleRGB = try rgb(middle), endedRGB = try rgb(ended)
    XCTAssertGreaterThan(Int(middleRGB[2]) - Int(middleRGB[0]), 180, "The second frame should be blue after the initial 200ms red frame.")
    XCTAssertGreaterThan(Int(endedRGB[2]) - Int(endedRGB[0]), 180, "After both finite iterations, the GIF stays blue rather than restarting red.")
    coordinator.display(data as Data, in: imageView, animate: false)
    XCTAssertNil(imageView.layer.animation(forKey: AnimatedMedia.Coordinator.animationKey))
    XCTAssertTrue(imageView.image === coordinator.firstFrame)
    coordinator.display(data as Data, in: imageView, animate: true)
    XCTAssertNotNil(imageView.layer.animation(forKey: AnimatedMedia.Coordinator.animationKey))
  }
  func testInvalidOversizedAndExcessiveFrameInputsAreBounded() async throws {
    for input in [Data("invalid".utf8), Data(repeating: 0, count: 30_000_001)] {
      do { _ = try await MediaCompression.prepare(input); XCTFail("Invalid input was accepted") } catch {}
    }
    let data = tinyGIF(delays: Array(repeating: 10, count: 201))
    let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    XCTAssertEqual(CGImageSourceGetCount(source), 201, "The input must actually contain more than the supported 200 frames.")
    do { _ = try await MediaCompression.prepare(data); XCTFail("Unbounded frame count was accepted") }
    catch { XCTAssertTrue(error is MediaCompression.Failure) }
  }
  func testUndecodableAnimationFallsBackToFirstFrameAndInvalidDataShowsUnavailable() async throws {
    let data = tinyGIF(delays: Array(repeating: 10, count: 2001))
    let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    XCTAssertEqual(CGImageSourceGetCount(source), 2001)
    let imageView = AnimatedMedia.MediaImageView(frame: CGRect(x: 0, y: 0, width: 160, height: 100))
    let coordinator = AnimatedMedia.Coordinator()
    defer { coordinator.stop(imageView) }
    coordinator.display(data, in: imageView, animate: true)
    for _ in 0..<100 { if imageView.image != nil { break }; try await Task.sleep(for: .milliseconds(10)) }
    XCTAssertNotNil(imageView.image, "Unsupported animation length still offers its readable first frame.")
    XCTAssertNil(imageView.layer.animation(forKey: AnimatedMedia.Coordinator.animationKey))
    XCTAssertEqual(imageView.accessibilityLabel, "Still image preview. Animation unavailable.")
    coordinator.display(Data("not an image".utf8), in: imageView, animate: true)
    let label = try XCTUnwrap(imageView.subviews.compactMap { $0 as? UILabel }.first)
    for _ in 0..<100 { if !label.isHidden { break }; try await Task.sleep(for: .milliseconds(10)) }
    XCTAssertFalse(label.isHidden); XCTAssertEqual(label.text, "Attachment unavailable")
    XCTAssertNil(imageView.image)
  }
  func testCancelledExportCannotReturnAnAttachment() async throws {
    let input = try encode(bitmap())
    let task = Task { try await MediaCompression.prepare(input) }
    task.cancel()
    do { _ = try await task.value; XCTFail("Cancelled export returned bytes") }
    catch { XCTAssertTrue(error is CancellationError) }
  }
}
