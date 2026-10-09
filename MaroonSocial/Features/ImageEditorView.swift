import MaroonCore
import PhotosUI
import SwiftUI
import UIKit

/// One overlay on the base image. Positions are normalized to the base so the
/// on-screen canvas and the exported bitmap agree at any display size.
struct ImageEditorItem: Identifiable {
  enum Content {
    case text(String, colorIndex: Int)
    case sticker(original: CGImage, cutout: CGImage?, usesCutout: Bool)
  }
  let id: UUID
  var content: Content
  var center: CGPoint
  var scale: CGFloat
  var rotation: Angle
  init(id: UUID = UUID(), content: Content, center: CGPoint = CGPoint(x: 0.5, y: 0.5), scale: CGFloat = 1, rotation: Angle = .zero) {
    self.id = id; self.content = content; self.center = center; self.scale = scale; self.rotation = rotation
  }
  var stickerImage: CGImage? {
    if case let .sticker(original, cutout, usesCutout) = content { return usesCutout ? (cutout ?? original) : original }
    return nil
  }
}

/// Deterministic composition shared by the live canvas and the export, so
/// what is on screen is what gets posted. Text uses the meme font and stroke.
@MainActor enum ImageComposer {
  static let maximumEdge: CGFloat = 1280
  static let textLimit = 120
  static let textColors: [UIColor] = [.white, .black, UIColor(red: 80 / 255, green: 0, blue: 0, alpha: 1), .systemYellow, .systemCyan, .systemPink]

  static func outputSize(for base: CGImage) -> CGSize {
    let width = CGFloat(max(1, base.width)), height = CGFloat(max(1, base.height))
    let factor = min(1, maximumEdge / max(width, height))
    return CGSize(width: max(1, (width * factor).rounded()), height: max(1, (height * factor).rounded()))
  }
  static func clamped(_ point: CGPoint) -> CGPoint { CGPoint(x: min(1, max(0, point.x)), y: min(1, max(0, point.y))) }
  static func fontSize(width: CGFloat, scale: CGFloat) -> CGFloat { max(8, width * 0.07 * scale) }
  static func font(size: CGFloat) -> UIFont { UIFont(name: "Impact", size: size) ?? .systemFont(ofSize: size, weight: .black) }
  static func textAttributes(width: CGFloat, scale: CGFloat, colorIndex: Int) -> [NSAttributedString.Key: Any] {
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byWordWrapping
    let color = textColors[max(0, min(textColors.count - 1, colorIndex))]
    return [.font: font(size: fontSize(width: width, scale: scale)), .paragraphStyle: paragraph, .foregroundColor: color,
      .strokeColor: color == .black ? UIColor.white : UIColor.black, .strokeWidth: -4]
  }
  static func textBounds(_ text: String, width: CGFloat, scale: CGFloat, colorIndex: Int) -> CGSize {
    let measured = (text as NSString).boundingRect(with: CGSize(width: max(40, width * 0.9), height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: textAttributes(width: width, scale: scale, colorIndex: colorIndex), context: nil).size
    return CGSize(width: ceil(measured.width) + 6, height: ceil(measured.height) + 6)
  }
  /// A sticker starts at 42% of the base width and keeps its own proportions.
  static func stickerSize(_ image: CGImage, width: CGFloat, scale: CGFloat) -> CGSize {
    let ratio = CGFloat(max(1, image.width)) / CGFloat(max(1, image.height))
    let drawnWidth = max(8, width * 0.42 * scale)
    return CGSize(width: drawnWidth, height: max(8, drawnWidth / ratio))
  }
  static func render(base: CGImage, items: [ImageEditorItem]) -> UIImage {
    let size = outputSize(for: base)
    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
      UIColor.black.setFill(); context.fill(CGRect(origin: .zero, size: size))
      UIImage(cgImage: base).draw(in: CGRect(origin: .zero, size: size))
      for item in items { draw(item, in: context.cgContext, size: size) }
    }
  }
  private static func draw(_ item: ImageEditorItem, in context: CGContext, size: CGSize) {
    let center = CGPoint(x: item.center.x * size.width, y: item.center.y * size.height)
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: CGFloat(item.rotation.radians))
    switch item.content {
    case let .text(text, colorIndex):
      let bounds = textBounds(text, width: size.width, scale: item.scale, colorIndex: colorIndex)
      (text as NSString).draw(with: CGRect(x: -bounds.width / 2, y: -bounds.height / 2, width: bounds.width, height: bounds.height),
        options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: textAttributes(width: size.width, scale: item.scale, colorIndex: colorIndex), context: nil)
    case .sticker:
      if let image = item.stickerImage {
        let drawn = stickerSize(image, width: size.width, scale: item.scale)
        UIImage(cgImage: image).draw(in: CGRect(x: -drawn.width / 2, y: -drawn.height / 2, width: drawn.width, height: drawn.height))
      }
    }
    context.restoreGState()
  }
  static func attachment(base: CGImage, items: [ImageEditorItem]) async throws -> MediaAttachment {
    guard let bitmap = render(base: base, items: items).cgImage else { throw MemeRenderError.exportFailed }
    return try await MediaCompression.jpeg(bitmap).attachment
  }
}

/// Edits a still image attachment (a photo, a composed meme or a KLIPY still):
/// text, stickers from the library or an image search, and subject cut-outs.
struct ImageEditorView: View {
  @Environment(\.dismiss) private var dismiss
  let source: MediaAttachment
  let onComplete: (MediaAttachment) -> Void
  @State private var searchService: ImageSearchService
  @State private var base: CGImage?
  @State private var items: [ImageEditorItem] = []
  @State private var selected: UUID?
  @State private var textPrompt = false
  @State private var draftText = ""
  @State private var editingText: UUID?
  @State private var search = false
  @State private var stickerItem: PhotosPickerItem?
  @State private var busy: String?
  @State private var error: String?
  @State private var confirmDiscard = false
  @State private var dragOrigin: [UUID: CGPoint] = [:]
  @State private var scaleOrigin: [UUID: CGFloat] = [:]
  @State private var rotationOrigin: [UUID: Angle] = [:]

  init(source: MediaAttachment, onComplete: @escaping (MediaAttachment) -> Void) {
    self.source = source; self.onComplete = onComplete
    _searchService = State(initialValue: ImageSearchFixture.enabled ? ImageSearchFixture.service() : ImageSearchService())
  }

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        ZStack {
          Color.black.ignoresSafeArea()
          if let base { canvas(base: base, in: geometry.size) }
          else if let error {
            VStack(spacing: 12) { Image(systemName: "photo.badge.exclamationmark").font(.largeTitle); Text(error).font(.subheadline).multilineTextAlignment(.center) }
              .foregroundStyle(Palette.secondary).padding(24)
          } else { LoadingWordmark(size: 24).accessibilityLabel("Loading image") }
        }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) { toolbar }
      .navigationTitle("Edit image").navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.black, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { AppHaptics.shared.play(.impact); if items.isEmpty { dismiss() } else { confirmDiscard = true } }
            .disabled(busy == "Preparing your image…").accessibilityIdentifier("imageEditorCancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(busy == "Preparing your image…" ? "Preparing…" : "Use image") { use() }
            .disabled(base == nil || busy != nil).accessibilityIdentifier("imageEditorUse")
        }
      }
      .alert(editingText == nil ? "Add text" : "Edit text", isPresented: $textPrompt) {
        TextField("Your text", text: $draftText).accessibilityIdentifier("imageEditorTextField")
        Button(editingText == nil ? "Add" : "Save") { commitText() }
        Button("Cancel", role: .cancel) { editingText = nil; draftText = "" }
      } message: { Text("Up to \(ImageComposer.textLimit) characters. Drag to move, pinch to resize, twist to rotate.") }
      .confirmationDialog("Discard your edits?", isPresented: $confirmDiscard, titleVisibility: .visible) {
        Button("Discard edits", role: .destructive) { AppHaptics.shared.play(.warning); dismiss() }
        Button("Keep editing", role: .cancel) {}
      }
      .sheet(isPresented: $search) { ImageSearchSheet(service: searchService) { picked in addSearchResult(picked) } }
      .interactiveDismissDisabled(!items.isEmpty || busy != nil)
      .task { await loadBase() }
      .task(id: stickerItem) { await loadSticker() }
    }.presentationBackground(.black).presentationDragIndicator(.visible)
  }

  // MARK: Canvas

  static func fittedFrame(for base: CGImage, in size: CGSize) -> CGRect {
    let width = CGFloat(max(1, base.width)), height = CGFloat(max(1, base.height))
    let factor = max(0.01, min(size.width / width, size.height / height))
    let drawn = CGSize(width: width * factor, height: height * factor)
    return CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2, width: drawn.width, height: drawn.height)
  }
  private func canvas(base: CGImage, in size: CGSize) -> some View {
    let frame = Self.fittedFrame(for: base, in: size)
    return ZStack(alignment: .topLeading) {
      Image(uiImage: UIImage(cgImage: base)).resizable()
        .frame(width: frame.width, height: frame.height).position(x: frame.midX, y: frame.midY)
        .onTapGesture { selected = nil }
        .accessibilityLabel("Your image").accessibilityIdentifier("imageEditorCanvas")
      ForEach(items) { item in overlay(item, frame: frame) }
    }.frame(width: size.width, height: size.height).clipped()
  }
  private func overlay(_ item: ImageEditorItem, frame: CGRect) -> some View {
    let center = CGPoint(x: frame.minX + item.center.x * frame.width, y: frame.minY + item.center.y * frame.height)
    return ImageEditorItemView(item: item, width: frame.width, selected: selected == item.id)
      .rotationEffect(item.rotation)
      .position(center)
      .gesture(dragGesture(for: item.id, frame: frame).simultaneously(with: magnifyGesture(for: item.id)).simultaneously(with: rotateGesture(for: item.id)))
      .onTapGesture { select(item.id) }
  }
  private func dragGesture(for id: UUID, frame: CGRect) -> some Gesture {
    DragGesture(minimumDistance: 2)
      .onChanged { value in
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let origin = dragOrigin[id] ?? items[index].center; dragOrigin[id] = origin; selected = id
        items[index].center = ImageComposer.clamped(CGPoint(x: origin.x + value.translation.width / max(1, frame.width), y: origin.y + value.translation.height / max(1, frame.height)))
      }
      .onEnded { _ in dragOrigin[id] = nil }
  }
  private func magnifyGesture(for id: UUID) -> some Gesture {
    MagnifyGesture()
      .onChanged { value in
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let origin = scaleOrigin[id] ?? items[index].scale; scaleOrigin[id] = origin; selected = id
        items[index].scale = min(4, max(0.3, origin * value.magnification))
      }
      .onEnded { _ in scaleOrigin[id] = nil }
  }
  private func rotateGesture(for id: UUID) -> some Gesture {
    RotateGesture()
      .onChanged { value in
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let origin = rotationOrigin[id] ?? items[index].rotation; rotationOrigin[id] = origin; selected = id
        items[index].rotation = origin + value.rotation
      }
      .onEnded { _ in rotationOrigin[id] = nil }
  }

  // MARK: Tools

  private var toolbar: some View {
    VStack(spacing: 6) {
      if let error { Text(error).font(.caption).foregroundStyle(Palette.accentText).multilineTextAlignment(.center).padding(.horizontal, 16).accessibilityIdentifier("imageEditorError") }
      if let busy { ProgressView(busy).font(.caption).tint(Palette.ink).accessibilityIdentifier("imageEditorBusy") }
      if let selected, let item = items.first(where: { $0.id == selected }) { selectionBar(item) }
      HStack(spacing: 14) {
        tool("Search images", symbol: "magnifyingglass", id: "imageEditorSearch") { search = true }
        tool("Add text", symbol: "textformat", id: "imageEditorAddText") { draftText = ""; editingText = nil; textPrompt = true }
        PhotosPicker(selection: $stickerItem, matching: .images) { toolLabel(symbol: "photo.on.rectangle") }
          .accessibilityLabel("Add a photo sticker").accessibilityIdentifier("imageEditorAddSticker")
        Spacer()
        Text("\(items.count) \(items.count == 1 ? "layer" : "layers")").font(.caption).foregroundStyle(Palette.secondary)
      }.padding(.horizontal, 16).disabled(base == nil || busy != nil)
    }.padding(.vertical, 8).background(Color.black)
  }
  private func tool(_ label: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
    Button { AppHaptics.shared.play(.impact); action() } label: { toolLabel(symbol: symbol) }
      .buttonStyle(.plain).accessibilityLabel(label).accessibilityIdentifier(id)
  }
  private func toolLabel(symbol: String) -> some View {
    Image(systemName: symbol).font(.system(size: 22, weight: .semibold)).foregroundStyle(Palette.ink).frame(width: 48, height: 48)
      .background(Palette.surface, in: Circle()).contentShape(Circle())
  }
  @ViewBuilder private func selectionBar(_ item: ImageEditorItem) -> some View {
    HStack(spacing: 10) {
      switch item.content {
      case let .text(text, colorIndex):
        ForEach(ImageComposer.textColors.indices, id: \.self) { index in
          Button { AppHaptics.shared.play(.selection); setColor(index, for: item.id) } label: {
            Circle().fill(Color(ImageComposer.textColors[index])).frame(width: 24, height: 24)
              .overlay(Circle().strokeBorder(index == colorIndex ? Color.white : Color.white.opacity(0.35), lineWidth: 2))
              .frame(width: 36, height: 44)
          }.buttonStyle(.plain).accessibilityLabel("Text color \(index + 1)").accessibilityIdentifier("imageEditorColor-\(index)")
            .accessibilityAddTraits(index == colorIndex ? .isSelected : [])
        }
        Button("Edit") { draftText = text; editingText = item.id; textPrompt = true }.accessibilityIdentifier("imageEditorEditText")
      case let .sticker(_, cutout, usesCutout):
        Button(usesCutout ? "Keep background" : "Cut out") { toggleCutout(item.id, cutout: cutout, usesCutout: usesCutout) }
          .accessibilityIdentifier("imageEditorCutout")
      }
      Spacer(minLength: 4)
      Button("Remove", role: .destructive) { remove(item.id) }.accessibilityIdentifier("imageEditorRemoveItem")
    }.font(.subheadline.weight(.semibold)).frame(minHeight: 44).padding(.horizontal, 16)
  }

  // MARK: Actions

  private func select(_ id: UUID) {
    AppHaptics.shared.play(.selection); selected = id
    if let index = items.firstIndex(where: { $0.id == id }), index != items.count - 1 { items.append(items.remove(at: index)) }
  }
  private func setColor(_ index: Int, for id: UUID) {
    guard let position = items.firstIndex(where: { $0.id == id }), case let .text(text, _) = items[position].content else { return }
    items[position].content = .text(text, colorIndex: index)
  }
  private func remove(_ id: UUID) {
    AppHaptics.shared.play(.selection); items.removeAll { $0.id == id }; if selected == id { selected = nil }
  }
  private func commitText() {
    let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    let editing = editingText
    editingText = nil; draftText = ""
    guard !text.isEmpty else { return }
    guard text.count <= ImageComposer.textLimit else { error = "Use \(ImageComposer.textLimit) characters or fewer."; return }
    error = nil
    if let editing, let index = items.firstIndex(where: { $0.id == editing }), case let .text(_, colorIndex) = items[index].content {
      items[index].content = .text(text, colorIndex: colorIndex); selected = editing
    } else {
      let offset = CGFloat(min(4, items.count)) * 0.07
      let item = ImageEditorItem(content: .text(text, colorIndex: 0), center: CGPoint(x: 0.5, y: min(0.9, 0.5 + offset)))
      items.append(item); selected = item.id
    }
    AppHaptics.shared.play(.impact)
  }
  private func addSticker(_ bitmap: CGImage) {
    let offset = CGFloat(min(4, items.count)) * 0.05
    let item = ImageEditorItem(content: .sticker(original: bitmap, cutout: nil, usesCutout: false), center: CGPoint(x: min(0.8, 0.5 + offset), y: min(0.8, 0.5 + offset)))
    items.append(item); selected = item.id
  }
  private func addSearchResult(_ picked: ImageSearchSheet.Pick) {
    search = false
    Task {
      busy = "Adding image…"; error = nil
      defer { busy = nil }
      do {
        let bitmap = try await ImageSearchService.bitmap(for: picked.item)
        guard !Task.isCancelled else { return }
        addSticker(bitmap)
        if picked.cutOut, let id = selected { await cutOut(id) }
        AppHaptics.shared.play(.success)
      } catch { if !Task.isCancelled { AppHaptics.shared.play(.error); self.error = error.localizedDescription } }
    }
  }
  private func toggleCutout(_ id: UUID, cutout: CGImage?, usesCutout: Bool) {
    guard let index = items.firstIndex(where: { $0.id == id }), case let .sticker(original, _, _) = items[index].content else { return }
    AppHaptics.shared.play(.selection)
    if usesCutout { items[index].content = .sticker(original: original, cutout: cutout, usesCutout: false); return }
    if let cutout { items[index].content = .sticker(original: original, cutout: cutout, usesCutout: true); return }
    Task { busy = "Cutting out the subject…"; error = nil; defer { busy = nil }; await cutOut(id) }
  }
  private func cutOut(_ id: UUID) async {
    guard let index = items.firstIndex(where: { $0.id == id }), case let .sticker(original, _, _) = items[index].content else { return }
    do {
      let cut = try await StickerCutout.cutOut(original)
      guard !Task.isCancelled, let current = items.firstIndex(where: { $0.id == id }), case let .sticker(base, _, _) = items[current].content else { return }
      items[current].content = .sticker(original: base, cutout: cut, usesCutout: true)
    } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
  }
  private func loadSticker() async {
    guard let picked = stickerItem else { return }
    busy = "Adding photo…"; error = nil
    defer { busy = nil; stickerItem = nil }
    do {
      guard let data = try await picked.loadTransferable(type: Data.self), !Task.isCancelled else { return }
      let bitmap = try await MediaCompression.thumbnail(data)
      guard !Task.isCancelled else { return }
      addSticker(bitmap); AppHaptics.shared.play(.success)
    } catch { if !Task.isCancelled { AppHaptics.shared.play(.error); self.error = error.localizedDescription } }
  }
  private func loadBase() async {
    guard base == nil else { return }
    busy = "Loading image…"
    defer { busy = nil }
    do {
      let data: Data
      if let reference = source.klipy {
        if let fixture = KlipyPickerFixture.data(for: reference) { data = fixture } else { data = try await KlipyNetwork.media(reference) }
      } else { data = source.data }
      let bitmap = try await MediaCompression.thumbnail(data)
      guard !Task.isCancelled else { return }
      base = bitmap
    } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
  }
  private func use() {
    guard let base, busy == nil else { return }
    AppHaptics.shared.play(.impact); busy = "Preparing your image…"; error = nil
    let snapshot = items
    Task {
      defer { busy = nil }
      do {
        let attachment = try await ImageComposer.attachment(base: base, items: snapshot)
        guard !Task.isCancelled else { return }
        AppHaptics.shared.play(.success); onComplete(attachment); dismiss()
      } catch { if !Task.isCancelled { AppHaptics.shared.play(.error); self.error = error.localizedDescription } }
    }
  }
}

private struct ImageEditorItemView: View {
  let item: ImageEditorItem
  let width: CGFloat
  let selected: Bool
  var body: some View {
    Group {
      switch item.content {
      case let .text(text, colorIndex):
        let bounds = ImageComposer.textBounds(text, width: width, scale: item.scale, colorIndex: colorIndex)
        StrokedText(text: text, attributes: ImageComposer.textAttributes(width: width, scale: item.scale, colorIndex: colorIndex))
          .frame(width: bounds.width, height: bounds.height)
      case .sticker:
        if let image = item.stickerImage {
          let size = ImageComposer.stickerSize(image, width: width, scale: item.scale)
          Image(uiImage: UIImage(cgImage: image)).resizable().frame(width: size.width, height: size.height)
        }
      }
    }
    .padding(4)
    .overlay { if selected { RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])) } }
    .contentShape(Rectangle())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityIdentifier("imageEditorItem-\(item.id.uuidString)")
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
  private var label: String {
    switch item.content {
    case let .text(text, _): return "Text: \(text)"
    case let .sticker(_, _, usesCutout): return usesCutout ? "Cut-out sticker" : "Sticker"
    }
  }
}

/// UILabel draws the exact attributes the export uses, including the stroke.
private struct StrokedText: UIViewRepresentable {
  let text: String
  let attributes: [NSAttributedString.Key: Any]
  func makeUIView(context: Context) -> UILabel {
    let label = UILabel(); label.numberOfLines = 0; label.textAlignment = .center; label.backgroundColor = .clear
    label.isUserInteractionEnabled = false
    return label
  }
  func updateUIView(_ label: UILabel, context: Context) { label.attributedText = NSAttributedString(string: text, attributes: attributes) }
}
