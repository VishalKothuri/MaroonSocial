import Foundation
import AVFoundation
import CoreVideo
import AppKit

// Host-only synthetic pixels; no camera, photo library, account or location is read.
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let inputURL = directory.appendingPathComponent("synthetic-source.mov")
let outputURL = directory.appendingPathComponent("synthetic-upload.mp4")
try? FileManager.default.removeItem(at: inputURL); try? FileManager.default.removeItem(at: outputURL)
let writer = try AVAssetWriter(outputURL: inputURL, fileType: .mov)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 240])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240])
writer.add(input)
let privateMetadata = AVMutableMetadataItem(); privateMetadata.identifier = .quickTimeMetadataLocationISO6709; privateMetadata.value = "+30.0000-096.0000/" as NSString; writer.metadata = [privateMetadata]
guard writer.startWriting() else { fatalError("Writer failed") }
writer.startSession(atSourceTime: .zero)
for index in 0..<15 {
 var buffer: CVPixelBuffer?
 guard CVPixelBufferCreate(nil, 320, 240, kCVPixelFormatType_32ARGB, nil, &buffer) == kCVReturnSuccess, let frame = buffer else { fatalError("Frame failed") }
 CVPixelBufferLockBaseAddress(frame, [])
 memset(CVPixelBufferGetBaseAddress(frame), Int32(30 + index * 12), CVPixelBufferGetBytesPerRow(frame) * CVPixelBufferGetHeight(frame))
 CVPixelBufferUnlockBaseAddress(frame, [])
 while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
 guard adaptor.append(frame, withPresentationTime: CMTime(value:Int64(index),timescale:15)) else { fatalError("Append failed") }
}
input.markAsFinished(); await writer.finishWriting()
let asset = AVURLAsset(url:inputURL)
let duration = try await asset.load(.duration)
let composition = AVMutableComposition()
for type in [AVMediaType.video,.audio] {
 for track in try await asset.loadTracks(withMediaType:type).prefix(1) {
  let copied = composition.addMutableTrack(withMediaType:type,preferredTrackID:kCMPersistentTrackID_Invalid)!
  try copied.insertTimeRange(CMTimeRange(start:.zero,duration:duration),of:track,at:.zero)
  if type == .video { copied.preferredTransform = try await track.load(.preferredTransform) }
 }
}
let export = AVAssetExportSession(asset:composition,presetName:AVAssetExportPreset1280x720)!
export.metadata=[]; export.shouldOptimizeForNetworkUse=true
try await export.export(to:outputURL,as:.mp4)
let output = AVURLAsset(url:outputURL)
guard try await output.load(.metadata).allSatisfy({ $0.identifier != .quickTimeMetadataLocationISO6709 }) else { fatalError("Location retained") }
let generator = AVAssetImageGenerator(asset:output); generator.appliesPreferredTrackTransform=true
let (image,_) = try await generator.image(at:.zero)
let bitmap = NSBitmapImageRep(cgImage:image)
try bitmap.representation(using:.jpeg,properties:[.compressionFactor:0.8])!.write(to:directory.appendingPathComponent("synthetic-photo.jpg"))
print("Synthetic video and JPEG exported; source location metadata removed.")
