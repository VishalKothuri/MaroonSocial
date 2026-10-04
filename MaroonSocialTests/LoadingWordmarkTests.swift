import XCTest
import SwiftUI
import UIKit
@testable import MaroonSocial

/// These inspect the real bundled artwork rendered by LoadingWordmark. The
/// independent asset mask includes both words, so an empty/clipped mark cannot
/// satisfy a color assertion. No product state or animation progress is read.
@MainActor final class LoadingWordmarkTests: XCTestCase {
  private let logoSize = CGSize(width: 320, height: 56)
  private let renderScale: CGFloat = 2

  func testFirstLoadingFrameContainsBothCompleteWhiteWords() throws {
    // ImageRenderer evaluates the actual initial SwiftUI frame synchronously,
    // before task scheduling can advance it past the brief white lead-in.
    let renderer = ImageRenderer(content: LoadingWordmark(animating: true, size: 43)
      .frame(width: logoSize.width, height: logoSize.height)
      .background(Palette.paper))
    renderer.scale = renderScale
    let firstFrame = try XCTUnwrap(renderer.uiImage)
    try assertGlyphs(firstFrame, color: .white, name: "Initial loading frame — both words white")
  }

  func testEveryLetterBecomesMaroonAndHoldsUntilLoadingStops() async throws {
    try XCTSkipIf(UIAccessibility.isReduceMotionEnabled,
      "The animated fill is intentionally disabled by the device’s Reduce Motion setting")
    let model = WordmarkRenderState()
    let host = try makeHost(model: model)
    defer { host.window.isHidden = true; host.window.rootViewController = nil }
    // Let the first hosting transaction mount its task, then allow a small
    // rendering margin after the app's complete-fill deadline.
    await Task.yield()
    try await Task.sleep(for: .seconds(LoadingWordmarkTiming.minimumFill + 0.2))
    try assertGlyphs(capture(host.controller), color: .maroon, name: "Complete fill — every letter of both words is maroon")
    try await Task.sleep(for: .seconds(0.35))
    try assertGlyphs(capture(host.controller), color: .maroon, name: "Slow request — full maroon fill remains visible")

    model.animating = false
    await Task.yield()
    try await Task.sleep(for: .seconds(LoadingWordmarkTiming.settle + 0.12))
    try assertGlyphs(capture(host.controller), color: .white, name: "Stopped loading — both words white again")
  }

  private func makeHost(model: WordmarkRenderState) throws -> (window: UIWindow, controller: UIViewController) {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let controller = UIHostingController(rootView: WordmarkRenderHost(model: model))
    let window = UIWindow(windowScene: scene)
    window.frame = scene.coordinateSpace.bounds
    window.rootViewController = controller
    controller.view.backgroundColor = UIColor(Palette.paper)
    window.isHidden = false
    window.layoutIfNeeded(); controller.view.layoutIfNeeded()
    return (window, controller)
  }

  private func capture(_ controller: UIViewController) throws -> UIImage {
    controller.view.layoutIfNeeded()
    let bounds = controller.view.bounds
    XCTAssertGreaterThanOrEqual(bounds.width, logoSize.width)
    let format = UIGraphicsImageRendererFormat(); format.scale = renderScale; format.opaque = true
    var rendered = false
    let image = UIGraphicsImageRenderer(size: logoSize, format: format).image { context in
      context.cgContext.translateBy(x: -(bounds.midX - logoSize.width / 2), y: -(bounds.midY - logoSize.height / 2))
      rendered = controller.view.drawHierarchy(in: bounds, afterScreenUpdates: true)
    }
    XCTAssertTrue(rendered, "UIKit must produce the actual visible hosting hierarchy")
    return image
  }

  private enum GlyphColor { case white, maroon }
  private func assertGlyphs(_ image: UIImage, color: GlyphColor, name: String, file: StaticString = #filePath, line: UInt = #line) throws {
    let asset = try XCTUnwrap(UIImage(named: "LaunchWordmark", in: .main, compatibleWith: nil), "Bundled logo missing", file: file, line: line)
    let format = UIGraphicsImageRendererFormat(); format.scale = renderScale; format.opaque = false
    let reference = UIGraphicsImageRenderer(size: logoSize, format: format).image { _ in
      asset.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: CGRect(origin: .zero, size: logoSize))
    }
    let expected = try pixels(reference)
    let actual = try pixels(image)
    XCTAssertEqual(actual.width, expected.width, file: file, line: line)
    XCTAssertEqual(actual.height, expected.height, file: file, line: line)
    guard actual.width == expected.width, actual.height == expected.height else { return }
    let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)

    // Together these regions cover every glyph in the asset. The split keeps
    // independent coverage of the heavier left word and thinner right word.
    let split = Int(Double(expected.width) * 0.60)
    for (word, range) in [("maroon / left glyphs", 1..<split), ("social / right glyphs", split..<(expected.width - 1))] {
      var samples = 0; var matching = 0
      for y in 1..<(expected.height - 1) {
        for x in range {
          // Ignore only antialiased edges; require opaque glyph interiors in
          // the reference and their four immediate neighbors.
          let neighbors = [(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
          guard neighbors.allSatisfy({ expected.channel($0.0, $0.1, 3) >= 245 }) else { continue }
          samples += 1
          let r = actual.channel(x, y, 0), g = actual.channel(x, y, 1), b = actual.channel(x, y, 2)
          switch color {
          case .white:
            // The app's white is warm (#f4efe6); these tolerances permit normal
            // color conversion without accepting the dark background or fill.
            if r >= 205 && g >= 200 && b >= 190 && abs(Int(r) - Int(b)) < 45 { matching += 1 }
          case .maroon:
            // Brand #500000, allowing a little antialiasing/light-edge bleed.
            if (55...115).contains(r) && g <= 35 && b <= 35 { matching += 1 }
          }
        }
      }
      XCTAssertGreaterThan(samples, 80, "The reference must contain substantial \(word)", file: file, line: line)
      let fraction = Double(matching) / Double(max(1, samples))
      XCTAssertGreaterThanOrEqual(fraction, 0.95, "\(name): only \(matching)/\(samples) interior pixels matched in \(word)", file: file, line: line)
    }
  }

  private struct PixelBuffer {
    let bytes: [UInt8]
    let width: Int
    let height: Int
    func channel(_ x: Int, _ y: Int, _ channel: Int) -> UInt8 { bytes[(y * width + x) * 4 + channel] }
  }
  private func pixels(_ image: UIImage) throws -> PixelBuffer {
    let cgImage = try XCTUnwrap(image.cgImage)
    let width = cgImage.width, height = cgImage.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    try bytes.withUnsafeMutableBytes { buffer in
      let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return PixelBuffer(bytes: bytes, width: width, height: height)
  }
}

@MainActor private final class WordmarkRenderState: ObservableObject {
  @Published var animating = true
}
private struct WordmarkRenderHost: View {
  @ObservedObject var model: WordmarkRenderState
  var body: some View {
    ZStack {
      Palette.paper
      LoadingWordmark(animating: model.animating, size: 43)
    }.ignoresSafeArea()
  }
}
