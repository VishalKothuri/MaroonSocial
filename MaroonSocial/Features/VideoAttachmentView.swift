import AVKit
import SwiftUI

/// Private media is fetched through the authenticated gateway before entering a
/// temporary protected file. Nothing is published as a long-lived media URL.
struct VideoAttachmentView: View {
  @Environment(\.scenePhase) private var scenePhase
  let data: Data
  var thumbnail: Data? = nil
  @State private var player: AVPlayer?
  @State private var file: URL?
  @State private var poster: UIImage?
  @State private var playing = false
  @State private var failed = false
  var body: some View {
    ZStack {
      Palette.surface
      if playing, let player { VideoPlayer(player: player) }
      else if let poster { Image(uiImage: poster).resizable().scaledToFit() }
      if !playing && !failed {
        Button { playing = true; player?.play() } label: {
          Image(systemName: "play.circle.fill").font(.system(size: 42)).foregroundStyle(.white)
            .background(.black.opacity(0.45), in: Circle()).padding(12)
        }.disabled(player == nil).accessibilityLabel("Play video")
      }
      if failed { Label("Video unavailable", systemImage: "video.slash").font(.caption) }
    }.frame(minHeight: 140).clipShape(RoundedRectangle(cornerRadius: 12))
      .task(id: data) {
        removeFile(); playing = false; failed = false
        do {
          guard !data.isEmpty, data.count <= VideoCompression.maximumOutputBytes else { throw VideoCompression.Failure.tooLarge }
          let url = FileManager.default.temporaryDirectory.appendingPathComponent("maroon-video-play-" + UUID().uuidString).appendingPathExtension("mp4")
          try data.write(to: url, options: [.atomic, .completeFileProtection]); file = url
          player = AVPlayer(url: url)
          if let thumbnail { poster = UIImage(data: thumbnail) }
          else { poster = UIImage(data: try await VideoCompression.thumbnail(url)) }
          try Task.checkCancellation()
        } catch { if !Task.isCancelled { failed = true }; removeFile() }
      }
      .onChange(of: scenePhase) { _, phase in if phase != .active { player?.pause(); playing = false } }
      .onDisappear { removeFile() }
  }
  private func removeFile() {
    player?.pause(); player?.replaceCurrentItem(with: nil); player = nil; poster = nil
    if let file { try? FileManager.default.removeItem(at: file) }; file = nil
  }
}
