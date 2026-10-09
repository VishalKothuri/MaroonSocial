import SwiftUI
import MaroonCore
import WebKit

struct KlipyPickerView: View {
  private enum LibraryTab: String, CaseIterable { case memes, gifs, community, recents
    var title: String { rawValue.capitalized }
    var category: KlipyService.Category { self == .gifs ? .gifs : .memes }
  }
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(AppStore.self) private var store
  let onAttach: (MediaAttachment) -> Void
  @State private var service: KlipyService
  @State private var recents: KlipyRecents
  @State private var tab = LibraryTab.memes
  @State private var query = ""
  @State private var selection: KlipyService.Item?
  @State private var community: SharedMemeService?
  @State private var communitySelection: SharedMeme?
  @State private var showInfo = false
  @State private var clearRecents = false
  @FocusState private var focused: Bool
  @Namespace private var tabIndicator

  init(available: Bool = true, onAttach: @escaping (MediaAttachment) -> Void) {
    self.onAttach = onAttach
    _service = State(initialValue: KlipyPickerFixture.enabled ? KlipyPickerFixture.service() : available ? KlipyService() : KlipyService(key: nil, customerID: "fixture"))
    _recents = State(initialValue: KlipyPickerFixture.enabled ? KlipyPickerFixture.recents : KlipyRecents.shared)
  }
  private var requestID: String { tab.rawValue + ":" + query }
  private var displayedItems: [KlipyService.Item] {
    guard tab == .recents else { return service.items }
    let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return recents.items.filter { text.isEmpty || $0.title.localizedCaseInsensitiveContains(text) }
  }
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        searchBar
        libraryTabs
        if tab == .community {
          GeometryReader { geometry in communityResults(width: max(1, geometry.size.width - 16)) }
        } else if service.available || tab == .recents {
          GeometryReader { geometry in
            results(width: max(1, geometry.size.width - 16))
          }
        } else {
          ContentUnavailableView("KLIPY library is being connected", systemImage: "photo.on.rectangle.angled", description: Text("Search will be available when the app’s library key is configured. You can still attach photos or make a custom meme."))
            .accessibilityIdentifier("klipyUnavailable")
        }
      }.background(Color.black.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        .task(id: requestID) {
          service.cancel()
          if tab == .community {
            let library = community ?? SharedMemeService(social: store.social, fixtureMode: store.fixtureMode)
            community = library
            do {
              if !query.isEmpty { try await Task.sleep(for: .milliseconds(350)) }
              try Task.checkCancellation()
              await library.load(query: query)
            } catch {}
            return
          }
          guard service.available, tab != .recents else { return }
          do {
            if !query.isEmpty { try await Task.sleep(for: .milliseconds(350)) }
            try Task.checkCancellation()
            await service.load(query: query, category: tab.category)
          } catch {}
        }
        .onDisappear { service.cancel(); community?.cancel() }
        .sheet(item: $selection) { item in
          KlipySelectionPreview(item: item, fixtureData: KlipyPickerFixture.data(for: item.reference)) {
            guard let reference = item.reference else { return }
            recents.record(item)
            onAttach(MediaAttachment(klipy: reference))
            AppHaptics.shared.play(.success)
            selection = nil; dismiss()
          }
        }
        .sheet(item: $communitySelection) { meme in
          if let community {
            CommunityMemePreview(meme: meme, service: community) { data in
              onAttach(MediaAttachment(kind: .image, data: data))
              AppHaptics.shared.play(.success)
              communitySelection = nil; dismiss()
            }
          }
        }
        .alert("Clear recent media?", isPresented: $clearRecents) {
          Button("Clear recents", role: .destructive) { recents.clear(); AppHaptics.shared.play(.warning) }
          Button("Cancel", role: .cancel) {}
        } message: { Text("This clears the recent picks on this device. Your posts and messages stay as they are.") }
        .sheet(isPresented: $showInfo) {
          NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
              Text("Powered by KLIPY").font(.title2.bold())
              Text("Searches and media load directly from KLIPY. Your community identity is not shared.")
              Text("Recent picks are saved on this device when you attach media to a draft. Sending or posting is always a separate action.")
              Spacer()
            }.font(.body).padding(24).appBackground().navigationTitle("Media library").navigationBarTitleDisplayMode(.inline)
              .toolbar { Button("Done") { AppHaptics.shared.play(.selection); showInfo = false } }
          }.presentationDetents([.medium, .large])
        }
    }.presentationDragIndicator(.visible).presentationBackground(.black)
  }

  private var searchBar: some View {
    HStack(spacing: 6) {
      Button { AppHaptics.shared.play(.impact); service.cancel(); dismiss() } label: {
        Image(systemName: "chevron.left").font(.system(size: 21, weight: .semibold)).frame(width: 44, height: 48).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityLabel("Cancel").accessibilityIdentifier("klipyCancel")
      HStack(spacing: 9) {
        Image(systemName: "magnifyingglass").font(.body.weight(.medium)).foregroundStyle(Palette.secondary)
        TextField(tab == .recents ? "Search recent picks" : tab == .community ? "Search shared memes" : tab == .gifs ? "Search GIFs" : "Search memes", text: $query)
          .font(.body).focused($focused).autocorrectionDisabled().textInputAutocapitalization(.never)
          .submitLabel(.search).onSubmit { focused = false }.accessibilityIdentifier("klipySearch")
        if !query.isEmpty {
          Button { AppHaptics.shared.play(.selection); query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.secondary).frame(width: 36, height: 44) }
            .buttonStyle(.plain).accessibilityLabel("Clear KLIPY search")
        }
      }.padding(.leading, 13).padding(.trailing, 5).frame(height: 46)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 15))
    }.padding(.leading, 4).padding(.trailing, 12).padding(.top, 14).padding(.bottom, 8)
  }

  private var libraryTabs: some View {
    HStack(spacing: 0) {
      ForEach(LibraryTab.allCases, id: \.self) { option in
        Button {
          focused = false
          guard tab != option else { return }
          AppHaptics.shared.play(.selection); tab = option
        } label: {
          VStack(spacing: 10) {
            Text(option.title.uppercased()).font(.system(size: 12, weight: .bold)).tracking(0.8)
              .foregroundStyle(tab == option ? Palette.ink : Palette.secondary)
            ZStack {
              Capsule().fill(.clear)
              if tab == option { Capsule().fill(Palette.maroon).matchedGeometryEffect(id: "klipy-tab", in: tabIndicator) }
            }.frame(height: 4)
          }.padding(.horizontal, 13).padding(.top, 10).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("klipyTab-" + option.rawValue)
          .accessibilityLabel(option.title).accessibilityAddTraits(tab == option ? .isSelected : [])
      }
      Button { AppHaptics.shared.play(.selection); showInfo = true } label: {
        VStack(spacing: 1) { Text("POWERED BY").font(.system(size: 6, weight: .medium)); Text("KLIPY").font(.system(size: 11, weight: .heavy)) }
          .foregroundStyle(Palette.secondary).frame(width: 62, height: 44).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityLabel("Powered by KLIPY. Library information")
    }.padding(.horizontal, 8).padding(.bottom, 8)
      .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: tab)
  }

  private func results(width: CGFloat) -> some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 8) {
          Color.clear.frame(height: 0).id("klipyTop")
          if tab == .recents && !recents.items.isEmpty {
            HStack {
              Text("YOUR RECENT PICKS").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(Palette.secondary)
              Spacer()
              Button("Clear") { AppHaptics.shared.play(.impact); clearRecents = true }.font(.caption.weight(.semibold)).frame(minWidth: 44, minHeight: 36).accessibilityIdentifier("klipyClearRecents")
            }.padding(.horizontal, 8)
          }
          ForEach(KlipyMasonry.sections(displayedItems)) { section in
            if let ad = section.ad, let html = ad.adHTML {
              VStack(alignment: .leading, spacing: 4) {
                Text("ADVERTISEMENT · KLIPY").font(.system(size: 9, weight: .medium)).tracking(0.7).foregroundStyle(Palette.secondary)
                KlipyAdvertisement(html: html).frame(height: min(300, max(50, ad.adHeight ?? 160)))
              }.padding(.vertical, 6).accessibilityLabel("KLIPY advertisement")
            } else {
              let columns = KlipyMasonry.columns(section.items, width: (width - 8) / 2)
              HStack(alignment: .top, spacing: 8) {
                ForEach(0..<2, id: \.self) { column in
                  LazyVStack(spacing: 8) {
                    ForEach(columns[column]) { item in mediaTile(item, width: (width - 8) / 2) }
                  }.frame(width: (width - 8) / 2)
                }
              }
            }
          }
          if tab != .recents && service.loading {
            if service.items.isEmpty { skeleton(width: width) }
            LoadingWordmark(size: 21).padding(.vertical, 18).accessibilityLabel("Loading media")
          }
          if tab != .recents, let error = service.error {
            VStack(spacing: 10) {
              Text(error).font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
              Button("Try again") { AppHaptics.shared.play(.impact); Task { await service.load(query: query, category: tab.category, more: !service.items.isEmpty) } }.buttonStyle(.bordered).tint(Palette.accentText)
            }.padding(24)
          } else if displayedItems.isEmpty && (tab == .recents || !service.loading) {
            VStack(spacing: 12) {
              Image(systemName: tab == .recents ? "clock" : "magnifyingglass").font(.system(size: 30, weight: .light)).foregroundStyle(Palette.secondary)
              Text(tab == .recents && query.isEmpty ? "Your go-to reactions, right here" : "No matches yet").font(.headline)
              Text(tab == .recents && query.isEmpty ? "Memes and GIFs you attach appear here." : "Try another word or phrase.").font(.subheadline).foregroundStyle(Palette.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 70).padding(.horizontal, 16).accessibilityIdentifier("klipyEmpty")
          }
          if tab != .recents && service.hasNext && service.error == nil {
            Color.clear.frame(height: 24).id("klipyPage-\(service.items.count)").onAppear {
              Task { await service.load(query: query, category: tab.category, more: true) }
            }
          }
        }.padding(.horizontal, 8).padding(.bottom, 20)
      }.accessibilityIdentifier("klipyResults").scrollDismissesKeyboard(.interactively)
        .onChange(of: requestID) { _, _ in proxy.scrollTo("klipyTop", anchor: .top) }
    }
  }

  private func mediaTile(_ item: KlipyService.Item, width: CGFloat) -> some View {
    Button {
      guard item.reference != nil else { return }
      AppHaptics.shared.play(.impact)
      focused = false; selection = item
    } label: {
      ZStack {
        Palette.surface
        if let reference = item.reference {
          KlipyThumbnail(reference: reference, fixtureData: KlipyPickerFixture.data(for: reference))
        } else {
          Image(systemName: "photo.badge.exclamationmark").font(.title2).foregroundStyle(Palette.secondary)
        }
      }.frame(width: width, height: KlipyMasonry.tileHeight(item, width: width))
        .clipShape(RoundedRectangle(cornerRadius: 12)).contentShape(RoundedRectangle(cornerRadius: 12))
    }.buttonStyle(.plain).disabled(item.reference == nil)
      .accessibilityIdentifier("klipyItem-" + (item.reference?.id ?? item.id))
      .accessibilityLabel("Preview \(item.title)")
  }

  private func communityResults(width: CGFloat) -> some View {
    let columnWidth = (width - 8) / 2
    let memes = community?.items ?? []
    let columns = Self.communityColumns(memes, width: columnWidth)
    return ScrollView {
      LazyVStack(spacing: 8) {
        HStack(alignment: .top, spacing: 8) {
          ForEach(0..<2, id: \.self) { column in
            LazyVStack(spacing: 8) { ForEach(columns[column]) { meme in communityTile(meme, width: columnWidth) } }.frame(width: columnWidth)
          }
        }
        if community?.loading == true { LoadingWordmark(size: 21).padding(.vertical, 18).accessibilityLabel("Loading shared memes") }
        if let error = community?.error {
          VStack(spacing: 10) {
            Text(error).font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
            Button("Try again") { AppHaptics.shared.play(.impact); Task { await community?.load(query: query, more: !memes.isEmpty) } }.buttonStyle(.bordered).tint(Palette.accentText)
          }.padding(24)
        } else if memes.isEmpty && community?.loading != true {
          VStack(spacing: 12) {
            Image(systemName: "person.3").font(.system(size: 30, weight: .light)).foregroundStyle(Palette.secondary)
            Text(query.isEmpty ? "No shared memes yet" : "No matches yet").font(.headline)
            Text(query.isEmpty ? "When someone shares an image from a post or chat, it shows up here for everyone." : "Try another word or phrase.")
              .font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
          }.frame(maxWidth: .infinity).padding(.vertical, 70).padding(.horizontal, 16).accessibilityIdentifier("communityEmpty")
        }
        if community?.hasNext == true && community?.error == nil {
          Color.clear.frame(height: 24).onAppear { Task { await community?.load(query: query, more: true) } }
        }
      }.padding(.horizontal, 8).padding(.bottom, 20)
    }.accessibilityIdentifier("communityResults").scrollDismissesKeyboard(.interactively)
  }
  private func communityTile(_ meme: SharedMeme, width: CGFloat) -> some View {
    Button { AppHaptics.shared.play(.impact); focused = false; communitySelection = meme } label: {
      ZStack {
        Palette.surface
        if let community { CommunityMemeThumbnail(meme: meme, service: community) }
      }.frame(width: width, height: min(width * 2.5, max(72, width / meme.aspectRatio)))
        .clipShape(RoundedRectangle(cornerRadius: 12)).contentShape(RoundedRectangle(cornerRadius: 12))
    }.buttonStyle(.plain).accessibilityIdentifier("communityItem-" + meme.id).accessibilityLabel("Preview \(meme.title)")
  }
  static func communityColumns(_ memes: [SharedMeme], width: CGFloat) -> [[SharedMeme]] {
    var columns: [[SharedMeme]] = [[], []]; var heights: [CGFloat] = [0, 0]
    for meme in memes {
      let column = heights[0] <= heights[1] ? 0 : 1
      columns[column].append(meme); heights[column] += min(width * 2.5, max(72, width / meme.aspectRatio)) + 8
    }
    return columns
  }

  private func skeleton(width: CGFloat) -> some View {
    HStack(alignment: .top, spacing: 8) {
      ForEach(0..<2, id: \.self) { column in
        VStack(spacing: 8) {
          ForEach(0..<3, id: \.self) { row in
            RoundedRectangle(cornerRadius: 12).fill(Palette.surface)
              .frame(width: (width - 8) / 2, height: CGFloat([210, 145, 190][(row + column) % 3]))
          }
        }
      }
    }.accessibilityHidden(true)
  }
}

/// Ads remain full-width boundaries in provider order; media before each ad
/// flows into the shortest column without stretching or cropping its captions.
enum KlipyMasonry {
  struct Section: Identifiable {
    let id: String
    var items: [KlipyService.Item] = []
    var ad: KlipyService.Item?
  }
  static func sections(_ items: [KlipyService.Item]) -> [Section] {
    var result: [Section] = []; var media: [KlipyService.Item] = []
    func flush() { if let first = media.first { result.append(Section(id: "media-" + first.id, items: media)); media = [] } }
    for item in items {
      if item.adHTML != nil { flush(); result.append(Section(id: "ad-" + item.id, ad: item)) }
      else { media.append(item) }
    }
    flush(); return result
  }
  static func tileHeight(_ item: KlipyService.Item, width: CGFloat) -> CGFloat {
    // Preserve normal media proportions, but keep extreme provider dimensions
    // from turning a single row into an enormous blank scrolling surface.
    min(width * 2.5, max(72, width / item.aspectRatio))
  }
  static func columns(_ items: [KlipyService.Item], width: CGFloat) -> [[KlipyService.Item]] {
    var columns: [[KlipyService.Item]] = [[], []]; var heights: [CGFloat] = [0, 0]
    for item in items {
      let column = heights[0] <= heights[1] ? 0 : 1
      columns[column].append(item); heights[column] += tileHeight(item, width: width) + 8
    }
    return columns
  }
}

private struct KlipySelectionPreview: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let item: KlipyService.Item
  let fixtureData: Data?
  let onAttach: () -> Void
  @State private var data: Data?
  @State private var error: String?
  @State private var retry = 0
  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        ZStack {
          if let data {
            AnimatedMedia(data: data, paused: reduceMotion)
              .frame(width: geometry.size.width, height: geometry.size.height)
              .accessibilityIdentifier("klipyPreview")
          }
          else if let error {
            VStack(spacing: 12) { Image(systemName: "photo.badge.exclamationmark").font(.largeTitle); Text(error).font(.subheadline).multilineTextAlignment(.center); Button("Retry") { AppHaptics.shared.play(.impact); retry += 1 }.buttonStyle(.bordered) }.padding(24)
          } else { LoadingWordmark(size: 24).accessibilityLabel("Loading preview") }
        }.frame(width: geometry.size.width, height: geometry.size.height)
      }.padding(.horizontal, 8).background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
          VStack(spacing: 10) {
            Button(action: onAttach) {
              Label(item.reference?.kind == "gif" ? "Attach GIF" : "Attach meme", systemImage: "plus")
            }.buttonStyle(PrimaryButton()).disabled(data == nil).accessibilityIdentifier("klipyAttach")
            Text("Added to your draft. You choose when to send.").font(.caption).foregroundStyle(Palette.secondary)
          }.padding(16).background(Color.black)
        }
        .navigationTitle(item.title).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.black, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button { AppHaptics.shared.play(.selection); dismiss() } label: { Image(systemName: "chevron.left") }
              .accessibilityLabel("Back to results").accessibilityIdentifier("klipyBack")
          }
        }
    }.presentationDetents([.large]).presentationDragIndicator(.visible).presentationBackground(.black)
      .task(id: retry) {
        guard let reference = item.reference else { return }
        data = nil; error = nil
        do {
          let result: Data
          if let fixtureData { result = fixtureData } else { result = try await KlipyNetwork.media(reference) }
          try Task.checkCancellation(); data = result
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
      }
  }
}

struct AttachmentPreview: View {
  let media: MediaAttachment
  var body: some View {
    if let reference = media.klipy { KlipyMedia(reference: reference) }
    else if media.kind == .video { VideoAttachmentView(data: media.data, thumbnail: media.thumbnail) }
    else { AnimatedMedia(data: media.data) }
  }
}
struct KlipyMedia: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let reference: KlipyReference
  var paused = false
  @State private var data: Data?
  @State private var failed = false
  var body: some View {
    Group {
      if let data { AnimatedMedia(data: data, paused: paused || reduceMotion) }
      else if failed { Label("KLIPY media unavailable", systemImage: "photo.badge.exclamationmark").font(.caption) }
      else { ProgressView() }
    }.task(id: reference.url) {
      data = nil; failed = false
      do {
        let result: Data
        if let fixture = KlipyPickerFixture.data(for: reference) { result = fixture }
        else { result = try await KlipyNetwork.media(reference) }
        try Task.checkCancellation(); data = result
      }
      catch { if !Task.isCancelled { failed = true } }
    }.accessibilityLabel(reference.title)
  }
}

// Ads returned by the provider retain their original position/content. They have
// no native bridge, account data, camera, microphone, or persistent cookie store.
struct KlipyAdvertisement: UIViewRepresentable {
  let html: String
  func makeUIView(context: Context) -> WKWebView {
    let view = Self.makeWebView(coordinator: context.coordinator)
    context.coordinator.load(html, in: view)
    return view
  }
  func updateUIView(_ view: WKWebView, context: Context) { context.coordinator.load(html, in: view) }
  func makeCoordinator() -> Coordinator { Coordinator() }
  static func makeWebView(coordinator: Coordinator) -> WKWebView {
    let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent(); config.applicationNameForUserAgent = "MaroonSocial/0.1"
    let view = WKWebView(frame: .zero, configuration: config); view.isOpaque = false; view.backgroundColor = .clear
    view.scrollView.isScrollEnabled = false; view.navigationDelegate = coordinator; view.uiDelegate = coordinator
    return view
  }
  final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    private static let documentURL = URL(string: "https://api.klipy.com/")!
    private var initialDocumentPending = false
    private var loadedHTML: String?
    var onLoad: (() -> Void)?
    var onBlockedNavigation: (() -> Void)?
    func load(_ html: String, in webView: WKWebView) {
      guard html != loadedHTML else { return }
      loadedHTML = html; initialDocumentPending = true
      webView.loadHTMLString(html, baseURL: Self.documentURL)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { onLoad?() }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(.deny) }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
      if action.navigationType == .linkActivated, let url = action.request.url, url.scheme == "https" { UIApplication.shared.open(url) }
      return nil
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
      guard let url = action.request.url else { decisionHandler(.cancel); return }
      if action.navigationType == .linkActivated {
        if url.scheme == "https" { UIApplication.shared.open(url) }; decisionHandler(.cancel); return
      }
      if action.targetFrame?.isMainFrame == true {
        // loadHTMLString uses its HTTPS base URL for the initial navigation.
        // Permit this one local document load, never a subsequent ad redirect.
        if initialDocumentPending && action.navigationType == .other && (url == Self.documentURL || url.absoluteString == "about:blank") {
          initialDocumentPending = false; decisionHandler(.allow)
        } else { onBlockedNavigation?(); decisionHandler(.cancel) }
      } else { decisionHandler(url.scheme == "https" || url.absoluteString == "about:blank" ? .allow : .cancel) }
    }
  }
}

/// Grid previews of shared memes stay still; bytes come through the social
/// service and are cached per picker session.
struct CommunityMemeThumbnail: View {
  let meme: SharedMeme
  let service: SharedMemeService
  @State private var image: UIImage?
  @State private var failed = false
  var body: some View {
    ZStack {
      if let image { Image(uiImage: image).resizable().scaledToFill() }
      else if failed { Image(systemName: "photo").font(.title3).foregroundStyle(Palette.secondary) }
    }.clipped().accessibilityLabel(failed ? "Preview unavailable" : meme.title)
      .task(id: meme.id) {
        do {
          let bitmap = try await MediaCompression.thumbnail(try await service.media(for: meme))
          if !Task.isCancelled { image = UIImage(cgImage: bitmap) }
        } catch { if !Task.isCancelled { failed = true } }
      }
  }
}

struct CommunityMemePreview: View {
  @Environment(\.dismiss) private var dismiss
  let meme: SharedMeme
  let service: SharedMemeService
  let onAttach: (Data) -> Void
  @State private var data: Data?
  @State private var error: String?
  @State private var retry = 0
  @State private var confirmReport = false
  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        ZStack {
          if let data {
            AnimatedMedia(data: data).frame(width: geometry.size.width, height: geometry.size.height).accessibilityIdentifier("communityPreview")
          } else if let error {
            VStack(spacing: 12) {
              Image(systemName: "photo.badge.exclamationmark").font(.largeTitle)
              Text(error).font(.subheadline).multilineTextAlignment(.center)
              Button("Retry") { AppHaptics.shared.play(.impact); retry += 1 }.buttonStyle(.bordered)
            }.padding(24)
          } else { LoadingWordmark(size: 24).accessibilityLabel("Loading preview") }
        }.frame(width: geometry.size.width, height: geometry.size.height)
      }.padding(.horizontal, 8).background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
          VStack(spacing: 10) {
            Button { if let data { onAttach(data) } } label: { Label("Attach meme", systemImage: "plus") }
              .buttonStyle(PrimaryButton()).disabled(data == nil).accessibilityIdentifier("communityAttach")
            Text("Shared by another Aggie. Added to your draft; you choose when to send.").font(.caption).foregroundStyle(Palette.secondary)
          }.padding(16).background(Color.black)
        }
        .navigationTitle(meme.title.isEmpty ? "Shared meme" : meme.title).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.black, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button { AppHaptics.shared.play(.selection); dismiss() } label: { Image(systemName: "chevron.left") }
              .accessibilityLabel("Back to results").accessibilityIdentifier("communityBack")
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button { AppHaptics.shared.play(.selection); confirmReport = true } label: { Image(systemName: "flag") }
              .accessibilityLabel("Report this meme").accessibilityIdentifier("communityReport")
          }
        }
        .confirmationDialog("Report this meme?", isPresented: $confirmReport, titleVisibility: .visible) {
          Button("Report", role: .destructive) {
            AppHaptics.shared.play(.warning)
            Task { do { try await service.report(meme); dismiss() } catch { self.error = error.localizedDescription } }
          }
        } message: { Text("Reports are reviewed. A meme reported by several people disappears for everyone.") }
    }.presentationDetents([.large]).presentationDragIndicator(.visible).presentationBackground(.black)
      .task(id: retry) {
        data = nil; error = nil
        do { let result = try await service.media(for: meme); try Task.checkCancellation(); data = result }
        catch { if !Task.isCancelled { self.error = error.localizedDescription } }
      }
  }
}

