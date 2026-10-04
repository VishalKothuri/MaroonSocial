import AppKit
import CoreText

let side = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                        bytesPerRow: side * 4, space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(colorSpace: colorSpace, components: [80.0 / 255.0, 0, 0, 1])!)
context.fill(CGRect(x: 0, y: 0, width: side, height: side))
let font = NSFont.systemFont(ofSize: 750, weight: .black)
let rounded = NSFont(descriptor: font.fontDescriptor.withDesign(.rounded)!, size: 750)!
var character: UniChar = 109
var glyph: CGGlyph = 0
precondition(CTFontGetGlyphsForCharacters(rounded, &character, &glyph, 1))
let path = CTFontCreatePathForGlyph(rounded, glyph, nil)!
// Center the visible glyph, not its font advance/baseline box.
let bounds = path.boundingBoxOfPath
context.translateBy(x: CGFloat(side) / 2 - bounds.midX, y: CGFloat(side) / 2 - bounds.midY)
context.addPath(path)
context.setFillColor(CGColor(colorSpace: colorSpace, components: [0.957, 0.937, 0.902, 1])!)
context.fillPath()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "MaroonSocial/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
print("Generated 1024×1024 icon with glyph centered at (512, 512) on A&M maroon.")
