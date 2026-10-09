import CoreImage
import Foundation
import UIKit
import Vision

/// On-device subject lifting for stickers. Nothing leaves the phone and the
/// result keeps its alpha channel until it is composited onto the base image.
enum StickerCutout {
  enum Failure: LocalizedError {
    case noSubject, failed
    var errorDescription: String? {
      switch self {
      case .noSubject: return "No clear subject was found to cut out. The image was kept as it is."
      case .failed: return "The background could not be removed from this image."
      }
    }
  }
  static func cutOut(_ image: CGImage) async throws -> CGImage {
    let worker = Task.detached(priority: .userInitiated) { try subject(of: image) }
    return try await withTaskCancellationHandler(operation: { let value = try await worker.value; try Task.checkCancellation(); return value }, onCancel: { worker.cancel() })
  }
  static func subject(of image: CGImage) throws -> CGImage {
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    let request = VNGenerateForegroundInstanceMaskRequest()
    do { try handler.perform([request]) } catch { throw Failure.failed }
    guard let observation = request.results?.first, !observation.allInstances.isEmpty else { throw Failure.noSubject }
    let buffer: CVPixelBuffer
    do { buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: true) }
    catch { throw Failure.failed }
    let masked = CIImage(cvPixelBuffer: buffer)
    guard masked.extent.width >= 2, masked.extent.height >= 2 else { throw Failure.noSubject }
    let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    guard let output = CIContext(options: [.workingColorSpace: space]).createCGImage(masked, from: masked.extent, format: .RGBA8, colorSpace: space) else { throw Failure.failed }
    return output
  }
}
