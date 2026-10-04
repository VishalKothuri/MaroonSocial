import AppKit
import CoreText
let size: CGFloat = 43
let rounded = NSFont(descriptor: NSFont.systemFont(ofSize: size, weight: .black).fontDescriptor.withDesign(.rounded)!, size: size)!
let serif = NSFont(descriptor: NSFont.systemFont(ofSize: size).fontDescriptor.withDesign(.serif)!.withSymbolicTraits(.italic), size: size)!
let ink = NSColor(srgbRed: 0.957, green: 0.937, blue: 0.902, alpha: 1)
func line(_ text: String, _ font: NSFont, _ tracking: CGFloat) -> CTLine {
  CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font:font, .kern:tracking, .foregroundColor:ink]))
}
let left = line("maroon", rounded, -1.6), right = line("social", serif, -1.5)
let leftWidth = CTLineGetTypographicBounds(left, nil, nil, nil)
let rightWidth = CTLineGetTypographicBounds(right, nil, nil, nil)
let width: CGFloat = 320, height: CGFloat = 56, spacing: CGFloat = 9
let contentWidth = leftWidth + rightWidth + spacing
let data = NSMutableData(); let consumer = CGDataConsumer(data: data)!
var bounds = CGRect(x: 0, y: 0, width: width, height: height)
let context = CGContext(consumer: consumer, mediaBox: &bounds, nil)!
context.beginPDFPage(nil)
var ascent: CGFloat = 0, descent: CGFloat = 0
_ = CTLineGetTypographicBounds(left, &ascent, &descent, nil)
context.textPosition = CGPoint(x: (width-contentWidth)/2, y: (height-ascent-descent)/2+descent)
CTLineDraw(left, context)
context.textPosition = CGPoint(x: (width-contentWidth)/2 + leftWidth + spacing, y: (height-ascent-descent)/2+descent)
CTLineDraw(right, context)
context.endPDFPage(); context.closePDF()
try data.write(to: URL(fileURLWithPath: "MaroonSocial/Resources/Assets.xcassets/LaunchWordmark.imageset/LaunchWordmark.pdf"))
print("Generated shared 320×56 vector startup wordmark with 9-point word spacing.")
