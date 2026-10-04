import SwiftUI

/// Picks a found picture for the editor. Results come from the configured
/// image search (SafeSearch on); only the chosen picture's bytes are fetched.
struct ImageSearchSheet: View {
  struct Pick { let item: ImageSearchService.Item; let cutOut: Bool }
  @Environment(\.dismiss) private var dismiss
  let service: ImageSearchService
  let onPick: (Pick) -> Void
  @State private var query = ""
  @State private var cutOut = false
  @FocusState private var focused: Bool

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        searchBar
        Toggle(isOn: $cutOut) { Label("Remove the background automatically", systemImage: "scissors").font(.subheadline) }
          .toggleStyle(SwitchToggleStyle(tint: Palette.maroon)).padding(.horizontal, 16).padding(.bottom, 8)
          .accessibilityIdentifier("imageSearchCutout")
        if service.available {
          GeometryReader { geometry in results(width: max(1, geometry.size.width - 16)) }
        } else {
          ContentUnavailableView("Image search is being connected", systemImage: "magnifyingglass",
            description: Text("Search will be available when the app’s search key is configured. You can still add photos from your library."))
            .accessibilityIdentifier("imageSearchUnavailable")
        }
      }.background(Color.black.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        .task(id: query) {
          service.cancel()
          guard service.available else { return }
          do {
            if !query.isEmpty { try await Task.sleep(for: .milliseconds(350)) }
            try Task.checkCancellation()
            await service.load(query: query)
          } catch {}
        }
        .onDisappear { service.cancel() }
    }.presentationDragIndicator(.visible).presentationBackground(.black)
  }

  private var searchBar: some View {
    HStack(spacing: 6) {
      Button { AppHaptics.shared.play(.impact); service.cancel(); dismiss() } label: {
        Image(systemName: "chevron.down").font(.system(size: 21, weight: .semibold)).frame(width: 44, height: 48).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityLabel("Close image search").accessibilityIdentifier("imageSearchClose")
      HStack(spacing: 9) {
        Image(systemName: "magnifyingglass").font(.body.weight(.medium)).foregroundStyle(Palette.secondary)
        TextField("Search images", text: $query).font(.body).focused($focused).autocorrectionDisabled().textInputAutocapitalization(.never)
          .submitLabel(.search).onSubmit { focused = false }.accessibilityIdentifier("imageSearchField")
        if !query.isEmpty {
          Button { AppHaptics.shared.play(.selection); query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.secondary).frame(width: 36, height: 44) }
            .buttonStyle(.plain).accessibilityLabel("Clear image search")
        }
      }.padding(.leading, 13).padding(.trailing, 5).frame(height: 46).background(Palette.surface, in: RoundedRectangle(cornerRadius: 15))
    }.padding(.leading, 4).padding(.trailing, 12).padding(.top, 14).padding(.bottom, 8)
      .onAppear { focused = true }
  }

  private func results(width: CGFloat) -> some View {
    let columnWidth = (width - 8) / 2
    let columns = Self.columns(service.items, width: columnWidth)
    return ScrollView {
      LazyVStack(spacing: 8) {
        HStack(alignment: .top, spacing: 8) {
          ForEach(0..<2, id: \.self) { column in
            LazyVStack(spacing: 8) { ForEach(columns[column]) { item in tile(item, width: columnWidth) } }.frame(width: columnWidth)
          }
        }
        if service.loading { LoadingWordmark(size: 21).padding(.vertical, 18).accessibilityLabel("Loading images") }
        if let error = service.error {
          VStack(spacing: 10) {
            Text(error).font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
            Button("Try again") { AppHaptics.shared.play(.impact); Task { await service.load(query: query, more: !service.items.isEmpty) } }.buttonStyle(.bordered).tint(Palette.accentText)
          }.padding(24)
        } else if service.items.isEmpty && !service.loading {
          VStack(spacing: 12) {
            Image(systemName: "magnifyingglass").font(.system(size: 30, weight: .light)).foregroundStyle(Palette.secondary)
            Text(query.isEmpty ? "Find a picture to add" : "No images found").font(.headline)
            Text(query.isEmpty ? "Search, then tap a result to drop it on your image." : "Try another word or phrase.").font(.subheadline).foregroundStyle(Palette.secondary)
          }.frame(maxWidth: .infinity).padding(.vertical, 60).padding(.horizontal, 16).accessibilityIdentifier("imageSearchEmpty")
        }
        if service.hasNext && service.error == nil {
          Color.clear.frame(height: 24).onAppear { Task { await service.load(query: query, more: true) } }
        }
        Text("Image results by Google").font(.caption2).foregroundStyle(Palette.secondary).padding(.top, 8)
      }.padding(.horizontal, 8).padding(.bottom, 20)
    }.accessibilityIdentifier("imageSearchResults").scrollDismissesKeyboard(.interactively)
  }
  private func tile(_ item: ImageSearchService.Item, width: CGFloat) -> some View {
    Button {
      AppHaptics.shared.play(.impact); focused = false
      onPick(Pick(item: item, cutOut: cutOut)); dismiss()
    } label: {
      ZStack { Palette.surface; SearchThumbnail(item: item) }
        .frame(width: width, height: Self.tileHeight(item, width: width))
        .clipShape(RoundedRectangle(cornerRadius: 12)).contentShape(RoundedRectangle(cornerRadius: 12))
    }.buttonStyle(.plain).accessibilityLabel(item.title).accessibilityIdentifier("imageSearchItem-\(item.id)")
  }
  static func tileHeight(_ item: ImageSearchService.Item, width: CGFloat) -> CGFloat { min(width * 2, max(72, width / item.aspectRatio)) }
  static func columns(_ items: [ImageSearchService.Item], width: CGFloat) -> [[ImageSearchService.Item]] {
    var columns: [[ImageSearchService.Item]] = [[], []]; var heights: [CGFloat] = [0, 0]
    for item in items {
      let column = heights[0] <= heights[1] ? 0 : 1
      columns[column].append(item); heights[column] += tileHeight(item, width: width) + 8
    }
    return columns
  }
}

private struct SearchThumbnail: View {
  let item: ImageSearchService.Item
  @State private var image: UIImage?
  @State private var failed = false
  var body: some View {
    ZStack {
      if let image { Image(uiImage: image).resizable().scaledToFill() }
      else if failed { Image(systemName: "photo").font(.title3).foregroundStyle(Palette.secondary) }
    }.clipped()
      .task(id: item.id) {
        do { let bitmap = try await ImageSearchService.thumbnail(for: item); if !Task.isCancelled { image = UIImage(cgImage: bitmap) } }
        catch { if !Task.isCancelled { failed = true } }
      }
  }
}
