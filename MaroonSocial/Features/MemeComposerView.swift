import ImageIO
import MaroonCore
import PhotosUI
import SwiftUI
import UIKit

/// Original backgrounds; no third-party template artwork or remote search provider.
enum MemeTemplate: String, CaseIterable, Identifiable {
  case maroon = "Maroon", cream = "Cream", midnight = "Midnight"
  var id: String { rawValue }
  var color: UIColor {
    switch self {
    case .maroon: return UIColor(red: 80.0 / 255.0, green: 0, blue: 0, alpha: 1)
    case .cream: return UIColor(red: 0.94, green: 0.90, blue: 0.81, alpha: 1)
    case .midnight: return UIColor(red: 0.09, green: 0.17, blue: 0.20, alpha: 1)
    }
  }
}
enum MemeRenderError: LocalizedError {
  case invalidPhoto, oversizedPhoto, captionTooLong, exportFailed
  var errorDescription: String? {
    switch self {
    case .invalidPhoto: return "That photo could not be opened. Choose another image."
    case .oversizedPhoto: return "Choose a photo smaller than 30 MB."
    case .captionTooLong: return "Use 160 characters or fewer in each caption."
    case .exportFailed: return "The meme could not be exported. Try another photo."
    }
  }
}
@MainActor enum MemeRenderer {
  static let captionLimit = 160
  static let maximumBytes = 5_000_000

  /// Decode a bounded, orientation-corrected bitmap rather than retaining photo metadata.
  static func photo(from data: Data) throws -> UIImage {
    guard data.count <= 30_000_000 else { throw MemeRenderError.oversizedPhoto }
    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
      CGImageSourceGetCount(source) > 0 else { throw MemeRenderError.invalidPhoto }
    if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
      width <= 0 || height <= 0 || width > 20_000 || height > 20_000 || Int64(width) * Int64(height) > 120_000_000 {
      throw MemeRenderError.invalidPhoto
    }
    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1280,
      kCGImageSourceShouldCacheImmediately: true]
    guard let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw MemeRenderError.invalidPhoto }
    return UIImage(cgImage: bitmap)
  }

  static func image(photo: UIImage?, template: MemeTemplate, top: String, bottom: String,
                    allCaps: Bool = true, maximumDimension: CGFloat = 1200) throws -> UIImage {
    guard top.count <= captionLimit, bottom.count <= captionLimit else { throw MemeRenderError.captionTooLong }
    let longest = min(1600, max(200, maximumDimension))
    let ratio = photo.map { min(1.5, max(0.75, $0.size.width / max(1, $0.size.height))) } ?? 1
    let size = ratio >= 1 ? CGSize(width: longest, height: (longest / ratio).rounded()) : CGSize(width: (longest * ratio).rounded(), height: longest)
    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
      let bounds = CGRect(origin: .zero, size: size)
      template.color.setFill(); context.fill(bounds)
      if let photo, photo.size.width > 0, photo.size.height > 0 {
        let factor = max(size.width / photo.size.width, size.height / photo.size.height)
        let drawn = CGSize(width: photo.size.width * factor, height: photo.size.height * factor)
        photo.draw(in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2, width: drawn.width, height: drawn.height))
      }
      drawCaption(allCaps ? top.uppercased() : top, atTop: true, size: size)
      drawCaption(allCaps ? bottom.uppercased() : bottom, atTop: false, size: size)
    }
  }

  static func attachment(photo: UIImage?, template: MemeTemplate, top: String, bottom: String, allCaps: Bool = true) throws -> MediaAttachment {
    let bitmap = try image(photo: photo, template: template, top: top, bottom: bottom, allCaps: allCaps)
    guard let image = bitmap.cgImage else { throw MemeRenderError.exportFailed }
    return MediaAttachment(kind: .image, data: try MediaCompression.encodeJPEG(image))
  }

  static func attachmentAsync(photo: UIImage?, template: MemeTemplate, top: String, bottom: String, allCaps: Bool = true) async throws -> MediaAttachment {
    let bitmap = try image(photo: photo, template: template, top: top, bottom: bottom, allCaps: allCaps)
    guard let image = bitmap.cgImage else { throw MemeRenderError.exportFailed }
    return try await MediaCompression.jpeg(image).attachment
  }

  private static func drawCaption(_ text: String, atTop: Bool, size: CGSize) {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    let inset = size.width * 0.045, width = size.width - 2 * inset, maximumHeight = size.height * 0.32
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byWordWrapping
    var fontSize = size.width * 0.085
    var attributes: [NSAttributedString.Key: Any] = [:]
    var measured = CGSize.zero
    repeat {
      let font = UIFont(name: "Impact", size: fontSize) ?? .systemFont(ofSize: fontSize, weight: .black)
      attributes = [.font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor.white,
        .strokeColor: UIColor.black, .strokeWidth: -4]
      measured = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil).size
      if measured.height <= maximumHeight { break }
      fontSize -= 1
    } while fontSize > size.width * 0.025
    let height = min(maximumHeight, ceil(measured.height) + 3)
    let y = atTop ? inset : size.height - inset - height
    (text as NSString).draw(with: CGRect(x: inset, y: y, width: width, height: height), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
  }
}

struct MemeComposerView: View {
  @Environment(AppStore.self) private var store
  var draftKey = "meme"
  @Environment(\.dismiss) private var dismiss
  var completion: (MediaAttachment) -> Void
  @State private var top = ""
  @State private var bottom = ""
  @State private var template: MemeTemplate = .maroon
  @State private var allCaps = true
  @State private var photo: UIImage?
  @State private var photoData: Data?
  @State private var photoItem: PhotosPickerItem?
  @State private var photoVersion = 0
  @State private var preview: UIImage?
  @State private var loadingPhoto = false
  @State private var exporting = false
  @State private var draftOwner = ""
  @State private var error: String?
  @State private var confirmDiscard = false
  @State private var confirmClear = false
  @State private var confirmRemovePhoto = false
  @FocusState private var captionFocus: CaptionField?
  private enum CaptionField { case top, bottom }
  private struct PreviewKey: Hashable { let top: String; let bottom: String; let template: MemeTemplate; let allCaps: Bool; let photoVersion: Int }
  private var key: PreviewKey { PreviewKey(top: top, bottom: bottom, template: template, allCaps: allCaps, photoVersion: photoVersion) }
  private var hasEdits: Bool { !top.isEmpty || !bottom.isEmpty || photo != nil || template != .maroon || !allCaps }
  private var hasCaption: Bool { !top.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !bottom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

  private var savedDraft:Binding<CompositionDraft> {
    Binding(get:{CompositionDraft(text:top,media:photoData.map{CompositionIdentity.image($0,identity:"meme-photo")},fields:["bottom":bottom,"template":template.rawValue,"allCaps":String(allCaps)],nonce:"meme",hasContent:hasEdits)},set:{value in
      top=value.text;bottom=value.fields["bottom"] ?? "";template=MemeTemplate(rawValue:value.fields["template"] ?? "") ?? .maroon;allCaps=value.fields["allCaps"] != "false";photoData=value.media?.data;photo=photoData.flatMap{UIImage(data:$0)};photoVersion+=1
    })
  }
  private func clearDraft(){top="";bottom="";photo=nil;photoData=nil;photoItem=nil;photoVersion+=1;template = .maroon;allCaps=true;error=nil}
  var body: some View {
    NavigationStack {
      Form {
        previewSection
        captionsSection
        backgroundSection
        if let error { Section { Text(error).font(.callout).foregroundStyle(.red).accessibilityLabel(error) } }
        if hasEdits { Section { Button("Clear draft", role: .destructive) { AppHaptics.shared.play(.impact); confirmClear = true }.disabled(exporting) } }
      }.scrollContentBackground(.hidden).background(Palette.paper)
        .scrollDismissesKeyboard(.interactively).navigationTitle("Create meme").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { AppHaptics.shared.play(.impact); if hasEdits { confirmDiscard = true } else { dismiss() } }.disabled(exporting) }
          ToolbarItem(placement: .confirmationAction) {
            Button(exporting ? "Preparing…" : "Use meme") {
              AppHaptics.shared.play(.impact)
              captionFocus = nil; exporting = true; error = nil
              Task {
                guard draftOwner == store.compositions.owner else { return }
                do {
                  let result = try await MemeRenderer.attachmentAsync(photo: photo, template: template, top: top, bottom: bottom, allCaps: allCaps)
                  try Task.checkCancellation(); guard draftOwner == store.compositions.owner else { return }; AppHaptics.shared.play(.success); completion(result); clearDraft();await store.compositions.removeDraft(draftKey,owner:draftOwner);dismiss()
                } catch { if !Task.isCancelled && draftOwner == store.compositions.owner { AppHaptics.shared.play(.error); self.error = error.localizedDescription } }
                exporting = false
              }
            }.disabled(!hasCaption || loadingPhoto || exporting).accessibilityIdentifier("useMeme")
          }
          ToolbarItem(placement: .topBarTrailing) { if captionFocus != nil { KeyboardDismissButton { captionFocus = nil } } }
        }
        .onAppear { if draftOwner.isEmpty { draftOwner = store.compositions.owner } }
        .persistentDraft(draftKey,value:savedDraft)
        .interactiveDismissDisabled(hasEdits || loadingPhoto || exporting)
        .confirmationDialog("Keep this meme draft?", isPresented: $confirmDiscard, titleVisibility: .visible) {
          Button("Save and close"){Task{if await store.compositions.saveDraft(savedDraft.wrappedValue,key:draftKey,owner:draftOwner){dismiss()}}}
          Button("Discard draft", role: .destructive) { AppHaptics.shared.play(.warning);Task{clearDraft();await store.compositions.removeDraft(draftKey,owner:draftOwner);dismiss()} }
        } message: { Text("Saved photos and captions stay on this device.") }
        .confirmationDialog("Clear the photo and captions?", isPresented: $confirmClear, titleVisibility: .visible) { Button("Clear draft", role: .destructive) { AppHaptics.shared.play(.warning);clearDraft();Task{await store.compositions.removeDraft(draftKey,owner:draftOwner)} } }
        .confirmationDialog("Remove the photo?", isPresented: $confirmRemovePhoto, titleVisibility: .visible) { Button("Use color background", role: .destructive) { AppHaptics.shared.play(.selection); photo = nil; photoData=nil;photoItem = nil; photoVersion += 1 } } message: { Text("Your captions will stay in place.") }
        .task(id: key) {
          try? await Task.sleep(for: .milliseconds(70))
          guard !Task.isCancelled else { return }
          do { preview = try MemeRenderer.image(photo: photo, template: template, top: top, bottom: bottom, allCaps: allCaps, maximumDimension: 600) }
          catch { self.error = error.localizedDescription }
        }
        .task(id: photoItem) {
          guard let photoItem else { return }
          loadingPhoto = true; error = nil
          defer { loadingPhoto = false }
          do {
            guard let data = try await photoItem.loadTransferable(type: Data.self), !Task.isCancelled else { return }
            let bitmap = try await MediaCompression.thumbnail(data)
            let decoded = UIImage(cgImage: bitmap)
            guard !Task.isCancelled else { return }
            let sanitized=try await MediaCompression.jpeg(bitmap)
            guard !Task.isCancelled, draftOwner == store.compositions.owner else{return}
            photoData=sanitized.data;photo = decoded; photoVersion += 1
          } catch { if !Task.isCancelled && draftOwner == store.compositions.owner { AppHaptics.shared.play(.error); self.error = error.localizedDescription; self.photoItem = nil } }
        }
    }
  }
  private var previewSection: some View {
    Section {
      if let preview {
        Image(uiImage: preview).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 280)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .accessibilityLabel("Meme preview. Top: \(top.isEmpty ? "empty" : top). Bottom: \(bottom.isEmpty ? "empty" : bottom).")
          .accessibilityIdentifier("memePreview")
      } else { ProgressView("Preparing preview…").frame(maxWidth: .infinity, minHeight: 180) }
    }
  }
  private var captionsSection: some View {
    Section {
      TextField("Top caption", text: $top, axis: .vertical).lineLimit(1...3).focused($captionFocus, equals: .top)
        .textInputAutocapitalization(.sentences).accessibilityIdentifier("memeTopCaption")
        .onChange(of: top) { _, value in limitCaption(value, field: .top) }
      TextField("Bottom caption", text: $bottom, axis: .vertical).lineLimit(1...3).focused($captionFocus, equals: .bottom)
        .textInputAutocapitalization(.sentences).accessibilityIdentifier("memeBottomCaption")
        .onChange(of: bottom) { _, value in limitCaption(value, field: .bottom) }
      Toggle("All caps", isOn: $allCaps)
    } header: { Text("Captions") } footer: { Text("Up to 160 characters per caption. Add at least one caption.") }
  }
  private func limitCaption(_ value: String, field: CaptionField) {
    guard value.count > MemeRenderer.captionLimit else { return }
    let limited = String(value.prefix(MemeRenderer.captionLimit))
    if field == .top { top = limited } else { bottom = limited }
  }
  private var backgroundSection: some View {
    Section {
      PhotosPicker(selection: $photoItem, matching: .images) {
        Label(loadingPhoto ? "Loading photo…" : photo == nil ? "Choose photo" : "Replace photo", systemImage: "photo")
      }.disabled(loadingPhoto || exporting)
      if photo == nil {
        Picker("Original template", selection: $template) {
          ForEach(MemeTemplate.allCases) { item in Text(item.rawValue).tag(item) }
        }.pickerStyle(.segmented)
      } else { Button("Use a color background instead", role: .destructive) { confirmRemovePhoto = true } }
    } header: { Text("Background") } footer: {
      Text(photo != nil ? "Your photo is cropped to fit the preview." : "Color templates are original. Choose your own photo for an image meme.")
    }
  }

}
