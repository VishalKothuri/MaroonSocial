import AVFoundation
import CoreVideo
import XCTest
@testable import MaroonSocial

final class VideoCompressionTests: XCTestCase {
  private func video(lastFrame: Double = 0.5) async throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 240])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240])
    writer.add(input)
    let metadata = AVMutableMetadataItem(); metadata.identifier = .quickTimeMetadataLocationISO6709; metadata.value = "+30.0000-096.0000/" as NSString; writer.metadata = [metadata]
    XCTAssertTrue(writer.startWriting()); writer.startSession(atSourceTime: .zero)
    for (index, time) in [0.0, lastFrame].enumerated() {
      var buffer: CVPixelBuffer?
      XCTAssertEqual(CVPixelBufferCreate(nil, 320, 240, kCVPixelFormatType_32ARGB, nil, &buffer), kCVReturnSuccess)
      let frame = try XCTUnwrap(buffer)
      CVPixelBufferLockBaseAddress(frame, [])
      memset(CVPixelBufferGetBaseAddress(frame), index == 0 ? 40 : 180, CVPixelBufferGetBytesPerRow(frame) * CVPixelBufferGetHeight(frame))
      CVPixelBufferUnlockBaseAddress(frame, [])
      for _ in 0..<300 where !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(10)) }
      XCTAssertTrue(input.isReadyForMoreMediaData)
      XCTAssertTrue(adaptor.append(frame, withPresentationTime: CMTime(seconds: time, preferredTimescale: 600)))
    }
    input.markAsFinished(); await writer.finishWriting()
    XCTAssertEqual(writer.status, .completed, writer.error?.localizedDescription ?? "")
    return url
  }
  func testRealVideoTranscodesWithThumbnailDurationAndNoLocationMetadata() async throws {
    let input = try await video(); defer { try? FileManager.default.removeItem(at: input) }
    let media = try await VideoCompression.prepare(input)
    XCTAssertEqual(media.kind, .video); XCTAssertLessThanOrEqual(media.data.count, 5_000_000)
    XCTAssertGreaterThan(try XCTUnwrap(media.duration), 0)
    XCTAssertGreaterThan(try XCTUnwrap(media.thumbnail).count, 0)
    let output = input.deletingPathExtension().appendingPathExtension("mp4"); defer { try? FileManager.default.removeItem(at: output) }
    try media.data.write(to: output)
    let asset = AVURLAsset(url: output)
    let metadata = try await asset.load(.metadata)
    XCTAssertFalse(metadata.contains { $0.commonKey == .commonKeyLocation || $0.identifier == .quickTimeMetadataLocationISO6709 })
    let tracks = try await asset.loadTracks(withMediaType: .video)
    let size = try await XCTUnwrap(tracks.first).load(.naturalSize)
    XCTAssertLessThanOrEqual(max(size.width, size.height), 1280)
  }
  func testOverlongAndMalformedVideoRejected() async throws {
    let input = try await video(lastFrame: 61); defer { try? FileManager.default.removeItem(at: input) }
    do { _ = try await VideoCompression.prepare(input); XCTFail("Overlong clip accepted") }
    catch { XCTAssertEqual(error.localizedDescription, VideoCompression.Failure.duration.localizedDescription) }
    try Data("not a movie".utf8).write(to: input)
    do { _ = try await VideoCompression.prepare(input); XCTFail("Malformed clip accepted") } catch {}
  }
}
