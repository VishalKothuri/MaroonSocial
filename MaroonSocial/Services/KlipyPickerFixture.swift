import Foundation
import ImageIO
import MaroonCore
import UIKit
import UniformTypeIdentifiers

/// Explicit, offline UI-test content. Normal debug and release launches never
/// substitute these images for provider results or use a real provider key.
@MainActor enum KlipyPickerFixture {
  static var enabled: Bool {
    #if DEBUG
    let arguments = ProcessInfo.processInfo.arguments
    return arguments.contains("--uitesting") && arguments.contains("--uitesting-klipy")
    #else
    return false
    #endif
  }
  static let recents = KlipyRecents(defaults: nil)
  static func service() -> KlipyService {
    guard enabled else { return KlipyService(key: nil, customerID: "offline-fixture") }
    #if DEBUG
    return KlipyService(key: "offline-fixture-key", customerID: "offline-fixture") { request in
      let category = request.url?.path.contains("/gifs/") == true ? "gifs" : "static-memes"
      let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "q" }?.value ?? ""
      let rows: [[String: Any]] = entries.filter {
        $0.category == category && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query))
      }.map { entry in
        let format = entry.category == "gifs" ? "gif" : "png"
        let file: [String: Any] = ["url": url(for: entry), "size": media[entry.id]?.count ?? 1,
          "width": entry.width, "height": entry.height]
        return ["id": entry.id, "slug": entry.id, "title": entry.title,
          "type": entry.category == "gifs" ? "gif" : "image", "file": ["sm": [format: file], "md": [format: file]]]
      }
      return try JSONSerialization.data(withJSONObject: ["result": true, "data": ["data": rows, "has_next": false]])
    }
    #else
    return KlipyService(key: nil, customerID: "offline-fixture")
    #endif
  }
  static func data(for reference: KlipyReference?) -> Data? {
    guard enabled, let reference else { return nil }
    #if DEBUG
    guard reference.provider == "klipy", let entry = entries.first(where: { $0.id == reference.id }), reference.url == url(for: entry) else { return nil }
    return media[entry.id]
    #else
    return nil
    #endif
  }

  #if DEBUG
  private struct Entry {
    let id: String, title: String, category: String
    let width: Int, height: Int
  }
  private static let entries = [
    Entry(id: "fixture-portrait", title: "Campus portrait", category: "static-memes", width: 360, height: 540),
    Entry(id: "fixture-landscape", title: "Study landscape", category: "static-memes", width: 640, height: 360),
    Entry(id: "fixture-square", title: "Square reaction", category: "static-memes", width: 400, height: 400),
    Entry(id: "fixture-gif", title: "Study break GIF", category: "gifs", width: 360, height: 240)
  ]
  private static func url(for entry: Entry) -> String {
    "https://static.klipy.com/__maroon_uitest__/" + entry.id + (entry.category == "gifs" ? ".gif" : ".png")
  }
  private static let media: [String: Data] = {
    var values: [String: Data] = [:]
    for (index, entry) in entries.enumerated() {
      if entry.category == "gifs" {
        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(buffer, UTType.gif.identifier as CFString, 2, nil) else { continue }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<2 {
          if let image = image(for: entry, variant: frame).cgImage {
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.25]] as CFDictionary)
          }
        }
        if CGImageDestinationFinalize(destination) { values[entry.id] = buffer as Data }
      } else { values[entry.id] = image(for: entry, variant: index).pngData() }
    }
    return values
  }()
  private static func image(for entry: Entry, variant: Int) -> UIImage {
    let size = CGSize(width: CGFloat(entry.width), height: CGFloat(entry.height))
    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
      let colors: [UIColor] = [UIColor(red: 0.31, green: 0, blue: 0, alpha: 1), .init(red: 0.08, green: 0.27, blue: 0.27, alpha: 1), .init(red: 0.27, green: 0.20, blue: 0.40, alpha: 1)]
      colors[variant % colors.count].setFill(); context.fill(CGRect(origin: .zero, size: size))
      let side = min(size.width, size.height) * 0.52
      let center = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
      UIColor(red: 1, green: 0.9, blue: 0.65, alpha: 1).setFill()
      UIBezierPath(roundedRect: center, cornerRadius: side * 0.16).fill()
      UIColor(white: 0.12, alpha: 1).setFill()
      for x in [0.28, 0.64] {
        UIBezierPath(ovalIn: CGRect(x: center.minX + side * x, y: center.minY + side * 0.31,
          width: side * 0.08, height: side * (variant % 2 == 0 ? 0.1 : 0.04))).fill()
      }
      let smile = UIBezierPath(); smile.move(to: CGPoint(x: center.minX + side * 0.28, y: center.minY + side * 0.64))
      smile.addQuadCurve(to: CGPoint(x: center.minX + side * 0.72, y: center.minY + side * 0.64), controlPoint: CGPoint(x: center.midX, y: center.minY + side * 0.84))
      smile.lineWidth = side * 0.035; UIColor(white: 0.12, alpha: 1).setStroke(); smile.stroke()
      let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
      let caption = variant % 2 == 0 ? "ONE MORE CHAPTER" : "TIME FOR A BREAK"
      (caption as NSString).draw(in: CGRect(x: 12, y: 18, width: size.width - 24, height: 80), withAttributes: [
        .font: UIFont.systemFont(ofSize: min(30, size.width * 0.065), weight: .black),
        .foregroundColor: UIColor.white, .paragraphStyle: paragraph])
    }
  }
  #endif
}
