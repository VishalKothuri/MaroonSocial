import Foundation
import ImageIO
import MaroonCore
import UniformTypeIdentifiers

/// Only user-supplied files pass through this encoder. KLIPY references retain
/// their provider renditions, attribution and reference-only upload path.
enum MediaCompression {
  static let maximumInputBytes = 30_000_000
  static let maximumOutputBytes = 5_000_000
  static let photoTargetBytes = 350_000
  static let maximumPhotoEdge = 1280
  static let maximumGIFFrames = 200
  static let maximumOutputGIFFrames = 80
  static let maximumGIFDecodedPixels: Int64 = 12_000_000
  struct Encoded: Sendable {
    let data: Data
    let animated: Bool
    var attachment: MediaAttachment { MediaAttachment(kind: animated ? .gif : .image, data: data) }
  }
  enum Failure: Error, LocalizedError {
    case unsupported, inputTooLarge, animationTooLarge, exportFailed
    var errorDescription: String? {
      switch self {
      case .unsupported: "Choose a supported photo or GIF."
      case .inputTooLarge: "Choose an original image smaller than 30 MB."
      case .animationTooLarge: "This GIF is too large to prepare safely. Choose a shorter or smaller animation."
      case .exportFailed: "This attachment could not be compressed below 5 MB. Choose a smaller image."
      }
    }
  }
  static func prepare(_ data: Data) async throws -> Encoded {
    let worker = Task.detached(priority: .userInitiated) { try encode(data) }
    return try await withTaskCancellationHandler(operation: { let value = try await worker.value; try Task.checkCancellation(); return value }, onCancel: { worker.cancel() })
  }
  static func jpeg(_ bitmap: CGImage) async throws -> Encoded {
    let worker = Task.detached(priority: .userInitiated) { Encoded(data: try encodeJPEG(bitmap), animated: false) }
    return try await withTaskCancellationHandler(operation: { let value = try await worker.value; try Task.checkCancellation(); return value }, onCancel: { worker.cancel() })
  }
  static func thumbnail(_ data: Data) async throws -> CGImage {
    let worker = Task.detached(priority: .userInitiated) {
      let source = try source(data)
      try Task.checkCancellation()
      return try thumbnail(source, index: 0, edge: maximumPhotoEdge)
    }
    return try await withTaskCancellationHandler(operation: { let value = try await worker.value; try Task.checkCancellation(); return value }, onCancel: { worker.cancel() })
  }
  static func encode(_ data: Data) throws -> Encoded {
    try Task.checkCancellation()
    let source = try source(data)
    let isGIF = CGImageSourceGetType(source).map { UTType($0 as String)?.conforms(to: .gif) == true } ?? false
    if isGIF { return Encoded(data: try encodeGIF(source), animated: true) }
    let bitmap = try thumbnail(source, index: 0, edge: maximumPhotoEdge)
    return Encoded(data: try encodeJPEG(bitmap), animated: false)
  }
  /// Immutable, bounded CGImage frames are safe to pass from the decode worker.
  struct DisplayFrames: @unchecked Sendable {
    let frames: [CGImage]
    let delays: [Double]
    let loopCount: Int?
    var duration: Double { delays.reduce(0, +) }
  }
  static func displayFrames(_ data: Data) throws -> DisplayFrames {
    try Task.checkCancellation()
    let source = try source(data)
    let count = CGImageSourceGetCount(source)
    guard count > 1 else { return DisplayFrames(frames: [try thumbnail(source, index: 0, edge: maximumPhotoEdge)], delays: [0.1], loopCount: nil) }
    // This also handles older uploads/provider GIFs; bounded sampling spans the
    // entire animation instead of silently dropping everything after frame 90.
    guard count <= 2000 else { throw Failure.animationTooLarge }
    let outputCount = min(count, maximumOutputGIFFrames)
    let selected = (0..<outputCount).map { $0 * (count - 1) / (outputCount - 1) }
    var delays: [Double] = [], maximumWidth = 1, maximumHeight = 1
    for index in 0..<count {
      try Task.checkCancellation()
      guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0, width <= 4096, height <= 4096 else { throw Failure.animationTooLarge }
      maximumWidth = max(maximumWidth, width); maximumHeight = max(maximumHeight, height)
      delays.append(try frameDelay(properties))
    }
    var edge = 480
    while edge > 1 {
      let scale = min(1, Double(edge) / Double(max(maximumWidth, maximumHeight)))
      if Int64(ceil(Double(maximumWidth) * scale)) * Int64(ceil(Double(maximumHeight) * scale)) * Int64(outputCount) <= maximumGIFDecodedPixels { break }
      edge -= 1
    }
    var frames: [CGImage] = [], merged: [Double] = []
    for (offset, index) in selected.enumerated() {
      try Task.checkCancellation()
      frames.append(try thumbnail(source, index: index, edge: edge))
      merged.append(delays[index..<(offset + 1 < selected.count ? selected[offset + 1] : count)].reduce(0, +))
    }
    let properties = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
    let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
    return DisplayFrames(frames: frames, delays: merged, loopCount: gif?[kCGImagePropertyGIFLoopCount] as? Int)
  }
  private static func frameDelay(_ properties: [CFString: Any]) throws -> Double {
    let timing = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
    let delay = timing?[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? timing?[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1
    guard delay.isFinite, delay >= 0, delay <= 3600 else { throw Failure.animationTooLarge }
    // A zero/unspecified GIF delay is displayed for 100ms. Normalize before
    // merging sampled intervals so compression and playback share one timeline.
    return delay > 0 ? delay : 0.1
  }
  private static func source(_ data: Data) throws -> CGImageSource {
    guard data.count <= maximumInputBytes else { throw Failure.inputTooLarge }
    guard !data.isEmpty, let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary), CGImageSourceGetCount(source) > 0,
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0, width <= 20_000, height <= 20_000, Int64(width) * Int64(height) <= 120_000_000 else { throw Failure.unsupported }
    return source
  }
  private static func thumbnail(_ source: CGImageSource, index: Int, edge: Int) throws -> CGImage {
    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: edge,
      kCGImageSourceShouldCacheImmediately: true, kCGImageSourceShouldCache: false]
    guard let bitmap = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else { throw Failure.unsupported }
    return bitmap
  }
  /// Keep JPEG quality at 0.64 or above; reduce dimensions before destroying text
  /// edges with very aggressive quantization. The 350KB target is a soft goal.
  static func encodeJPEG(_ image: CGImage) throws -> Data {
    var best: Data?
    for edge in [maximumPhotoEdge, 1120, 960, 800] {
      try Task.checkCancellation()
      let bitmap = try opaqueScaled(image, edge: edge)
      for quality in [0.86, 0.76, 0.68, 0.64] {
        try Task.checkCancellation()
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { throw Failure.exportFailed }
        CGImageDestinationAddImage(destination, bitmap, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.exportFailed }
        let encoded = data as Data
        if best == nil || encoded.count < best!.count { best = encoded }
        if encoded.count <= photoTargetBytes { return encoded }
      }
    }
    guard let best, best.count <= maximumOutputBytes else { throw Failure.exportFailed }
    return best
  }
  private static func opaqueScaled(_ image: CGImage, edge: Int) throws -> CGImage {
    let scale = min(1, Double(edge) / Double(max(image.width, image.height)))
    let width = max(1, Int((Double(image.width) * scale).rounded())), height = max(1, Int((Double(image.height) * scale).rounded()))
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw Failure.exportFailed }
    context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let bitmap = context.makeImage() else { throw Failure.exportFailed }
    return bitmap
  }
  private static func encodeGIF(_ source: CGImageSource) throws -> Data {
    let count = CGImageSourceGetCount(source)
    guard count <= maximumGIFFrames else { throw Failure.animationTooLarge }
    let properties = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
    let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
    let loop = gif?[kCGImagePropertyGIFLoopCount] as? Int
    var delays: [Double] = []
    var maximumWidth = 1, maximumHeight = 1
    for index in 0..<count {
      guard let frame = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let width = frame[kCGImagePropertyPixelWidth] as? Int, let height = frame[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0, width <= 4096, height <= 4096 else { throw Failure.animationTooLarge }
      maximumWidth = max(maximumWidth, width); maximumHeight = max(maximumHeight, height)
      delays.append(try frameDelay(frame))
    }
    let outputCount = min(count, maximumOutputGIFFrames)
    let selected = (0..<outputCount).map { outputCount == 1 ? 0 : $0 * (count - 1) / (outputCount - 1) }
    let mergedDelays = selected.enumerated().map { offset, index in
      delays[index..<(offset + 1 < selected.count ? selected[offset + 1] : count)].reduce(0, +)
    }
    // Output decoded memory remains bounded even when every compressed frame is
    // loaded by the renderer. Keep both endpoints and the animation's full time.
    var maximumEdge = 480
    while maximumEdge > 1 {
      let scale = min(1, Double(maximumEdge) / Double(max(maximumWidth, maximumHeight)))
      let framePixels = Int64(ceil(Double(maximumWidth) * scale)) * Int64(ceil(Double(maximumHeight) * scale))
      if framePixels * Int64(outputCount) <= maximumGIFDecodedPixels { break }
      maximumEdge -= 1
    }
    var best: Data?
    for edge in [maximumEdge, min(360, maximumEdge), min(280, maximumEdge)] {
      try Task.checkCancellation()
      let output = NSMutableData()
      guard let destination = CGImageDestinationCreateWithData(output, UTType.gif.identifier as CFString, outputCount, nil) else { throw Failure.exportFailed }
      if let loop { CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: loop]] as CFDictionary) }
      for (offset, index) in selected.enumerated() {
        try Task.checkCancellation()
        try autoreleasepool {
          let bitmap = try thumbnail(source, index: index, edge: edge)
          CGImageDestinationAddImage(destination, bitmap, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: mergedDelays[offset], kCGImagePropertyGIFUnclampedDelayTime: mergedDelays[offset]]] as CFDictionary)
        }
      }
      guard CGImageDestinationFinalize(destination) else { throw Failure.exportFailed }
      let encoded = output as Data
      if best == nil || encoded.count < best!.count { best = encoded }
      if encoded.count <= 1_500_000 { return encoded }
    }
    guard let best, best.count <= maximumOutputBytes else { throw Failure.exportFailed }
    return best
  }
}
