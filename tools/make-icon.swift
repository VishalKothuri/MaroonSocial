import AppKit
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(srgbRed: 0.36, green: 0.055, blue: 0.11, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let font = NSFont.systemFont(ofSize: 750, weight: .black)
let rounded = NSFont(descriptor: font.fontDescriptor.withDesign(.rounded)!, size: 750)!
let text = "m" as NSString
text.draw(at: NSPoint(x: 150, y: 105), withAttributes: [.font: rounded, .foregroundColor: NSColor(srgbRed: 0.96, green: 0.95, blue: 0.92, alpha: 1)])
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "MaroonSocial/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
