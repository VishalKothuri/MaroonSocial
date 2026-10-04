import AVFoundation
import CoreTransferable
import Foundation
import MaroonCore
import UniformTypeIdentifiers
import UIKit

struct PickedVideo: Transferable {
  let url: URL
  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .movie) { file in
      let size = try file.file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size > 0, size <= VideoCompression.maximumInputBytes else { throw VideoCompression.Failure.tooLarge }
      let destination = FileManager.default.temporaryDirectory.appendingPathComponent("maroon-video-source-" + UUID().uuidString).appendingPathExtension("mov")
      try FileManager.default.copyItem(at: file.file, to: destination)
      return Self(url: destination)
    }
  }
}

enum VideoCompression {
  static let maximumInputBytes = 100_000_000
  static let maximumOutputBytes = 5_000_000
  static let maximumDuration = 60.0
  enum Failure: LocalizedError {
    case tooLarge, duration, unsupported, output
    var errorDescription: String? { switch self {
      case .tooLarge: "Choose a video smaller than 100 MB."
      case .duration: "Choose a video up to 60 seconds long."
      case .unsupported: "This video could not be prepared. Choose another clip."
      case .output: "This clip is still larger than 5 MB after compression. Trim it and try again."
    } }
  }
  static func prepare(_ url: URL) async throws -> MediaAttachment {
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard size > 0, size <= maximumInputBytes else { throw Failure.tooLarge }
    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration).seconds
    guard duration.isFinite, duration > 0, duration <= maximumDuration else { throw Failure.duration }
    let tracks = try await asset.loadTracks(withMediaType: .video)
    guard tracks.count == 1 else { throw Failure.unsupported }
    // Exporting the source asset can copy its QuickTime user-data metadata even
    // when exportSession.metadata is empty. A fresh composition carries only
    // audiovisual samples and the display transform, never source location tags.
    let composition = AVMutableComposition()
    let range = CMTimeRange(start: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))
    for type in [AVMediaType.video, .audio] {
      let sourceTracks = try await asset.loadTracks(withMediaType: type)
      guard let source = sourceTracks.first else { continue }
      guard let destination = composition.addMutableTrack(withMediaType: type, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw Failure.unsupported }
      try destination.insertTimeRange(range, of: source, at: .zero)
      if type == .video { destination.preferredTransform = try await source.load(.preferredTransform) }
    }
    for preset in [AVAssetExportPreset1280x720, AVAssetExportPreset640x480] {
      try Task.checkCancellation()
      guard let session = AVAssetExportSession(asset: composition, presetName: preset) else { continue }
      let output = FileManager.default.temporaryDirectory.appendingPathComponent("maroon-video-export-" + UUID().uuidString).appendingPathExtension("mp4")
      defer { try? FileManager.default.removeItem(at: output) }
      session.shouldOptimizeForNetworkUse = true
      session.metadata = []
      do {
        try await session.export(to: output, as: .mp4)
        try Task.checkCancellation()
        let bytes = try Data(contentsOf: output, options: .mappedIfSafe)
        guard bytes.count <= maximumOutputBytes else { continue }
        let thumbnail = try await thumbnail(output)
        var result = MediaAttachment(kind: .video, data: bytes)
        result.thumbnail = thumbnail; result.duration = duration
        return result
      } catch is CancellationError { session.cancelExport(); throw CancellationError() }
      catch { if Task.isCancelled { session.cancelExport(); throw CancellationError() } }
    }
    throw Failure.output
  }
  static func thumbnail(_ url: URL) async throws -> Data {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    generator.appliesPreferredTrackTransform = true; generator.maximumSize = CGSize(width: 480, height: 480)
    let result = try await generator.image(at: .zero)
    guard let data = UIImage(cgImage: result.image).jpegData(compressionQuality: 0.75) else { throw Failure.unsupported }
    return data
  }
}
