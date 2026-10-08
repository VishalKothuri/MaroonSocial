import SwiftUI
import PhotosUI
import MaroonCore

/// The feed's post composer. Collapsed it is one maroon bubble; expanded it is a maroon card (text,
/// inline poll/link/hashtags/media/quote, then one tool row ending in Send) over a grey panel (topic
/// chips, Anonymous / Accept DMs and the counter, where it posts and Discard). The expanded composer
/// scrolls as one region when it is taller than the space above the keyboard; nothing inside it
/// scrolls vertically on its own. While the card runs past the bottom of that space, its tool row
/// stays pinned there, so Send is always in reach.
struct InlinePostComposer: View {
  @Environment(AppStore.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let community: Community
  @Binding var expanded: Bool
  /// The sheet variant (QuotePostComposerSheet) keeps a separate draft from the feed's inline composer.
  var draftKey = "post"
  var quoting: String? = nil
  /// The topic the feed is showing: a new post starts in it (a restored draft keeps its own).
  var browsedTopic: String? = nil
  /// Called with the published post's topic, before `onPublished`.
  var onPublishedTopic: ((String?) -> Void)? = nil
  let onPublished: () -> Void
  @State private var text = ""
  @State private var anonymous = true
  @State private var acceptsDM = true
  @State private var sending = false
  @State private var draftOwner = ""
  @State private var item: PhotosPickerItem?
  @State private var photoPicker = false
  @State private var media: MediaAttachment?
  @State private var loadingMedia = false
  @State private var meme = false
  @State private var klipy = false
  @State private var editImage = false
  @State private var offers = AttachmentOffers()
  @State private var discard = false
  @State private var error: String?
  @State private var draftCommunity: Community?
  private enum Field: Hashable { case body, option(Int), link, tags }
  @FocusState private var focused: Field?
  /// Poll (the text is its question), link and hashtags.
  @State private var features = PostComposerFeatures()
  /// The expanded composer's natural height; its scroll region never grows past it.
  @State private var contentHeight: CGFloat = 320
  /// What pins the tool row footer to the bottom of the visible band: the card's frame in the
  /// scroll content, the footer's height and the visible part of the scroll view (its offset is
  /// only tracked while the card's bottom can still be below the band).
  @State private var cardFrame: CGRect = .zero
  @State private var footerHeight: CGFloat = 52
  @State private var visible = VisibleBand()
  /// Where each field sits in the scroll content, and the composer's own scroll position, so a
  /// focused field can be brought above the pinned tool row (not just above the keyboard).
  @State private var fieldFrames: [Field: CGRect] = [:]
  @State private var scrollPosition = ScrollPosition(idType: String.self)
  private static let contentSpace = "postComposerContent"
  @State private var quotedPostID: String?
  /// One topic per post. Required only while topics are available (older servers accept none).
  @State private var topic: String?
  /// The community guidelines sheet shown before a member's first post.
  @State private var guidelines = GuidelinesGate()
  private var validation: Result<ValidatedPostFeatures, Error> {
    Result { try features.validate(text: text, hasQuote: quotedPostID != nil) }
  }
  /// Only a rule the draft actually breaks; required pieces still empty just keep Send disabled.
  private var validationMessage: String? {
    guard hasDraft, let error = features.brokenRule(text: text, hasQuote: quotedPostID != nil) else { return nil }
    // The card's own words: the text is the question, and the poll has choices.
    switch error {
    case .invalidQuestion: return "With a poll, your post is the question: 1–180 characters."
    case .invalidOptions: return "Add 2–4 different choices with 1–80 characters each."
    default: return error.localizedDescription
    }
  }
  private var hasDraft: Bool { hasOwnContent || quotedPostID != nil }
  /// What the member wrote or attached. The sheet's quote is supplied by the screen,
  /// so a sheet closed with nothing else in it leaves no draft behind.
  private var hasOwnContent: Bool { !text.isEmpty || media != nil || item != nil || loadingMedia || features.pollEnabled || features.linkEnabled || features.tagsEnabled }
  private var persistsContent: Bool { quoting == nil ? hasDraft : hasOwnContent }
  private var quote: PostQuote? {
    quotedPostID.map { id in store.state.posts.first { $0.id == id }.map(PostQuote.init(quoting:)) ?? PostQuote(id: id, unavailable: true) }
  }
  private var target: Community { draftCommunity ?? community }
  /// The chosen topic while the catalog still lists it; never sent to a server without topics.
  private var chosenTopic: String? {
    guard store.topicsAvailable, let topic, store.topics.contains(where: { $0.slug == topic }) else { return nil }
    return topic
  }
  private var topicSatisfied: Bool { TopicCatalog.canPublish(topic: chosenTopic, topicsAvailable: store.topicsAvailable, catalog: store.topics) }
  private var canSend: Bool { !sending && !loadingMedia && topicSatisfied && (try? validation.get()) != nil }
  /// Send waits for a topic.
  private var needsTopic: Bool { store.topicsAvailable && hasDraft && !topicSatisfied }
  /// The topic chips (the top of the grey panel) are on screen, so their own hint is enough.
  private var topicChipsInView: Bool { cardFrame.maxY + 8 + 56 <= visible.offset + visible.height }
  private var tagsTitle: String { store.topicsAvailable ? "Hashtags" : "Tags" }
  private var savedDraft: Binding<CompositionDraft> {
    Binding(get: { CompositionDraft(text: text, media: media, fields: ["anonymous": String(anonymous), "acceptsDM": String(acceptsDM), "community": target.rawValue, "pollEnabled": String(features.pollEnabled), "linkEnabled": String(features.linkEnabled), "link": features.link, "tagsEnabled": String(features.tagsEnabled), "tags": features.tagsText, "quotedPostID": quotedPostID ?? "", "topic": topic ?? ""], poll: features.poll, nonce: "post", hasContent: persistsContent) }, set: { draft in
      media = draft.media; anonymous = draft.fields["anonymous"] != "false"; acceptsDM = draft.fields["acceptsDM"] != "false"
      draftCommunity = draft.fields["community"].flatMap(Community.init(rawValue:))
      // A draft from the earlier layout may carry a separate poll question; it moves into the text once.
      let restored = PostComposerFeatures.migratingLegacyPoll(text: draft.text, pollEnabled: draft.fields["pollEnabled"] == "true", poll: draft.poll)
      text = restored.text
      var next = restored.features
      next.linkEnabled = draft.fields["linkEnabled"] == "true"; next.link = draft.fields["link"] ?? ""
      next.tagsEnabled = draft.fields["tagsEnabled"] == "true"; next.tagsText = draft.fields["tags"] ?? ""
      features = next
      quotedPostID = draft.fields["quotedPostID"].flatMap { $0.isEmpty ? nil : $0 }
      topic = draft.fields["topic"].flatMap { $0.isEmpty ? nil : $0 }
    })
  }
  var body: some View {
    Group {
      if expanded { expandedComposer } else { collapsedBubble.padding(.horizontal, 12).padding(.vertical, 8) }
    }.disabled(sending).background(Palette.paper)
      .overlay(alignment: .top) { Divider() }
      .onAppear { if draftOwner.isEmpty { draftOwner = store.compositions.owner } }
      .persistentDraft(draftKey, value: savedDraft)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: expanded)
      // Runs after the saved draft is restored, so the post tapped now wins over an older quote.
      .task {
        guard let quoting else { return }
        quotedPostID = quoting
        // The sheet is always expanded, so it pre-selects here (a restored draft keeps its topic).
        if topic == nil { topic = browsedTopic }
        // The sheet starts ready to type, like the inline repost path.
        try? await Task.sleep(for: .milliseconds(350)); focused = .body
      }
      .onChange(of: store.quoteRequest) { _, value in
        guard quoting == nil, let value else { return }
        quotedPostID = value; expand(); store.quoteRequest = nil
      }
      .onChange(of: expanded) { _, value in
        if value {
          AppHaptics.shared.play(.impact)
          if draftCommunity == nil { draftCommunity = community }
          preselectTopic()
        } else { focused = nil }
      }
      .onChange(of: store.topicComposeRequest) { _, value in
        guard quoting == nil, value != nil, expanded else { return }
        preselectTopic()
      }
      .onChange(of: item) { _, value in if value != nil { expand(focus: false); focused = nil } }
      .onDisappear { focused = nil }
      .task(id: item) {
        guard let item else { loadingMedia = false; return }
        loadingMedia = true; let prepared = await loadPickedMedia(item, store: store)
        guard !Task.isCancelled, self.item == item else { return }
        media = prepared; loadingMedia = false
        if let prepared { offers.arrived(prepared) }
      }
      .photosPicker(isPresented: $photoPicker, selection: $item, matching: .any(of: [.images, .videos]))
      .sheet(isPresented: $meme) { MemeComposerView(draftKey:"meme:post") { attachment in item = nil; media = attachment; offers.arrived(attachment) } }
      .sheet(isPresented: $klipy) { KlipyPickerView(available: !store.fixtureMode) { attachment in item = nil; media = attachment } }
      .sheet(isPresented: $editImage) {
        if let media { ImageEditorView(source: media) { edited in item = nil; self.media = edited; offers.arrived(edited) } }
      }
      .attachmentOffers(offers, service: SharedMemeService(social: store.social, fixtureMode: store.fixtureMode))
      .guidelinesSheet(guidelines)
      .alert("Discard this post draft?", isPresented: $discard) {
        Button("Discard draft", role: .destructive) { AppHaptics.shared.play(.warning); Task { guard draftOwner == store.compositions.owner else { return }; await store.discardPendingPostDraft(owner:draftOwner); resetDraft(); close() } }
        Button("Keep editing", role: .cancel) { focused = .body }
      }
  }

  // MARK: Collapsed

  private var collapsedBubble: some View {
    HStack(spacing: 4) {
      attachmentMenu
      expandButton
    }
    .padding(.horizontal, 9)
    .foregroundStyle(Palette.onAccent)
    .background(Palette.maroon, in: RoundedRectangle(cornerRadius: 28))
    .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Palette.ink.opacity(0.22), lineWidth: 0.75))
  }
  private var attachmentMenu: some View {
    Menu {
      Button("Add poll", systemImage: "chart.bar.xaxis") { add(.poll) }.accessibilityIdentifier("postAddPollMenu")
      Button("Add link", systemImage: "link") { add(.link) }
      Button("Add " + tagsTitle.lowercased(), systemImage: "number") { add(.tags) }
      Divider()
      Button("Photo, GIF, or video", systemImage: "photo") { openPhotoPicker() }.accessibilityIdentifier("postPhotoPicker")
      Button("Search memes & GIFs", systemImage: "magnifyingglass") { openKlipy() }.accessibilityIdentifier("postKlipyPicker")
      Button("Make a meme", systemImage: "text.below.photo") { openMeme() }
    } label: {
      Image(systemName: "photo.on.rectangle.angled").font(.system(size: 21, weight: .semibold)).frame(width: 44, height: 48)
    }.accessibilityLabel("Post attachments").accessibilityHint("Add a poll, link, tags, photo, GIF, video, or meme")
  }
  private var expandButton: some View {
    Button { expand() } label: {
      Text(hasDraft ? "Continue your post…" : "What’s happening?")
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel("Create post")
  }

  // MARK: Expanded

  /// Card and panel in one scroll region, as tall as they are until the space runs out.
  private var expandedComposer: some View {
    ScrollView {
      VStack(spacing: 8) {
        card
        panel
      }.padding(.horizontal, 12).padding(.vertical, 8)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .coordinateSpace(.named(Self.contentSpace))
    }
    .frame(maxHeight: contentHeight)
    .scrollPosition($scrollPosition)
    .scrollBounceBehavior(.basedOnSize)
    .scrollDismissesKeyboard(.interactively)
    // Once the card's bottom has scrolled past, the value stops changing, so scrolling the panel
    // does not re-render the composer.
    .onScrollGeometryChange(for: VisibleBand.self) { geometry in
      VisibleBand(offset: min(geometry.contentOffset.y + geometry.contentInsets.top, cardFrame.maxY),
        height: geometry.visibleRect.height - geometry.contentInsets.top - geometry.contentInsets.bottom)
    } action: { _, band in visible = band }
    .accessibilityIdentifier("postComposer")
    // After a focus change, and again whenever the band changes height: the keyboard can settle
    // after the focus moves (it may even drop and come back between fields). Restarting the task
    // waits for the last change.
    .task(id: RevealRequest(field: focused, height: visible.height)) {
      try? await Task.sleep(for: .milliseconds(350))
      if !Task.isCancelled { revealFocusedField() }
    }
  }
  private struct RevealRequest: Equatable { let field: Field?; let height: CGFloat }
  /// The visible part of the scroll content: where it starts and how tall it is.
  private struct VisibleBand: Equatable { var offset: CGFloat = 0; var height: CGFloat = .greatestFiniteMagnitude }
  /// How far the tool row footer rises from its place at the card's bottom to sit on the bottom of
  /// the visible band. It never covers the card's first line.
  private var footerLift: CGFloat {
    let lift = cardFrame.maxY - (visible.offset + visible.height)
    guard lift > 0 else { return 0 }
    return min(lift, max(0, cardFrame.height - footerHeight - 56))
  }
  /// Keeps the focused field in view: above the tool row, which can be pinned over the bottom of
  /// the band, and with its top edge showing.
  private func revealFocusedField() {
    guard let field = focused, let frame = fieldFrames[field] else { return }
    let top = visible.offset, lowest = visible.offset + visible.height - footerHeight - 8
    // Down far enough to clear the tool row, but never so far that the field's top goes out of view.
    var delta = max(0, frame.maxY - lowest)
    if frame.minY - delta < top + 8 { delta = frame.minY - top - 8 }
    guard abs(delta) > 1 else { return }
    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { scrollPosition.scrollTo(y: max(0, top + delta)) }
  }
  /// Records where a field sits in the scroll content.
  private func tracksFrame(of field: Field) -> FrameTracker { FrameTracker(space: Self.contentSpace) { fieldFrames[field] = $0 } }

  // MARK: Card

  private var card: some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top, spacing: 0) {
          postEditor
          closeButton
        }
        if let quote { quoteRow(quote) }
        if let media { attachmentRow(media) }
        if loadingMedia { ProgressView("Preparing attachment…").font(.caption).tint(Palette.onAccent) }
        if features.linkEnabled { linkField }
        if features.tagsEnabled { tagsField }
        if features.pollEnabled { pollChoices }
      }.padding(.horizontal, 10).padding(.top, 4)
      cardFooter
    }
    .foregroundStyle(Palette.onAccent)
    .tint(Palette.onAccent)
    .background(Palette.maroon, in: RoundedRectangle(cornerRadius: 24))
    .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.ink.opacity(0.22), lineWidth: 0.75))
    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.contentSpace)) } action: { cardFrame = $0 }
  }
  /// The hairline, why Send waits (a missing topic) and the tool row. While the card runs past the
  /// bottom of the visible band it is pinned there, opaque, with the card scrolling under it.
  private var cardFooter: some View {
    let lift = footerLift
    return VStack(alignment: .leading, spacing: 6) {
      Rectangle().fill(Palette.onAccent.opacity(0.22)).frame(height: 0.5)
      // Next to Send while the chips are out of view (under the keyboard or further down).
      if needsTopic && !topicChipsInView {
        Label("Pick a topic below to send.", systemImage: "arrow.down")
          .font(.caption.weight(.semibold)).foregroundStyle(Palette.onAccent.opacity(0.9))
          .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4)
          // Capped like Send, so the pinned footer leaves room for the card at accessibility sizes.
          .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
          .accessibilityIdentifier("postTopicReason")
      }
      toolRow
    }
    .padding(.horizontal, 10).padding(.bottom, 2)
    .background {
      UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24).fill(Palette.maroon)
        .shadow(color: .black.opacity(lift > 0 ? 0.35 : 0), radius: 5, y: -2)
    }
    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footerHeight = $0 }
    .offset(y: -lift)
  }
  /// The text grows with what is typed (the composer scrolls, the editor does not).
  private var postEditor: some View {
    // The hidden copy sizes the editor: same font and insets as the text view, plus room for a trailing return.
    // While empty it is sized by the placeholder, which can wrap at accessibility sizes.
    Text(text.isEmpty ? placeholder : text + " ").font(.body).padding(.vertical, 8).padding(.horizontal, 5)
      .frame(maxWidth: .infinity, minHeight: features.pollEnabled ? 44 : 78, alignment: .topLeading)
      .hidden().accessibilityHidden(true)
      .overlay {
        TextEditor(text: $text).font(.body)
          .scrollContentBackground(.hidden).scrollDisabled(true)
          .focused($focused, equals: .body)
          .accessibilityIdentifier("postText").accessibilityLabel(features.pollEnabled ? "Poll question" : "Post text")
      }
      .overlay(alignment: .topLeading) {
        if text.isEmpty {
          Text(placeholder).font(.body)
            .foregroundStyle(Palette.onAccent.opacity(0.75))
            .padding(.top, 8).padding(.leading, 5).allowsHitTesting(false).accessibilityHidden(true)
        }
      }
      .padding(.vertical, 4).modifier(tracksFrame(of: .body))
  }
  private var placeholder: String { features.pollEnabled ? "Ask a question…" : "What’s happening?" }
  /// Folds the composer away and keeps the draft; Discard in the panel removes it.
  private var closeButton: some View {
    Button { AppHaptics.shared.play(.impact); close() } label: {
      Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).frame(width: 44, height: 44)
    }.buttonStyle(.plain).accessibilityLabel("Close composer").accessibilityIdentifier("closePostComposer")
  }
  /// A field on the maroon card: darker translucent fill, light text, readable placeholder.
  private func cardField(_ title: String, text: Binding<String>, field: Field, id: String) -> some View {
    TextField(title, text: text, prompt: Text(title).foregroundStyle(Palette.onAccent.opacity(0.72)))
      .focused($focused, equals: field).accessibilityIdentifier(id)
      .foregroundStyle(Palette.onAccent)
      .padding(.horizontal, 10).frame(minHeight: 44)
      // The whole fill focuses the field, not only its line of text (the text itself still takes
      // its own taps, so placing the cursor works as usual).
      .background {
        RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.3))
          .contentShape(RoundedRectangle(cornerRadius: 10))
          .onTapGesture { focused = field }
      }
      .modifier(tracksFrame(of: field))
  }
  private var linkField: some View {
    cardField("Link (example.com)", text: $features.link, field: .link, id: "postLink")
      .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
      .accessibilityLabel("Post link")
  }
  private var tagsField: some View {
    VStack(alignment: .leading, spacing: 4) {
      cardField(store.topicsAvailable ? "#hashtags" : "Tags", text: $features.tagsText, field: .tags, id: "postTags")
        .textInputAutocapitalization(.never).autocorrectionDisabled()
        .accessibilityLabel(store.topicsAvailable ? "Post hashtags" : "Post tags")
      Text(store.topicsAvailable ? "Up to 5 hashtags, separated by spaces or commas." : "Up to 5 tags, separated by spaces or commas.")
        .font(.caption).foregroundStyle(Palette.onAccent.opacity(0.8))
    }
  }
  private var pollChoices: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(features.poll.options.indices, id: \.self) { index in
        HStack(spacing: 4) {
          cardField("Choice \(index + 1)", text: $features.poll.options[index], field: .option(index), id: "pollOption\(index)")
            .submitLabel(index + 1 < features.poll.options.count || features.canAddChoice ? .next : .done)
            .onSubmit { focused = features.choiceAfterReturn(from: index).map(Field.option) }
          if index >= PostComposerFeatures.minChoices {
            Button {
              AppHaptics.shared.play(.selection); features.removeChoice(at: index); focused = nil
            } label: { Image(systemName: "minus.circle").frame(width: 44, height: 44) }
              .buttonStyle(.plain).accessibilityLabel("Remove choice \(index + 1)").accessibilityIdentifier("removePollOption\(index)")
          }
        }
      }
      let controls = dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) : AnyLayout(HStackLayout(spacing: 12))
      controls {
        if features.canAddChoice {
          Button {
            AppHaptics.shared.play(.selection)
            if let index = features.addChoice() { focused = .option(index) }
          } label: { Label("Add choice", systemImage: "plus").frame(minHeight: 44) }
            .buttonStyle(.plain).accessibilityIdentifier("pollAddOption")
        }
        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
        durationMenu
        Button { AppHaptics.shared.play(.selection); remove(.poll) } label: { Text("Remove poll").frame(minHeight: 44) }
          .buttonStyle(.plain).accessibilityIdentifier("removePoll")
      }.font(.subheadline.weight(.semibold))
    }
  }
  private var durationMenu: some View {
    Menu {
      Picker("Poll duration", selection: $features.poll.durationHours) {
        Text("1 day").tag(24); Text("3 days").tag(72); Text("7 days").tag(168)
      }
    } label: {
      Label(durationTitle, systemImage: "clock").frame(minHeight: 44)
    }.accessibilityIdentifier("pollDuration").accessibilityLabel("Poll duration").accessibilityValue(durationTitle)
  }
  private var durationTitle: String {
    switch features.poll.durationHours { case 72: "3 days"; case 168: "7 days"; default: "1 day" }
  }
  private func quoteRow(_ quote: PostQuote) -> some View {
    HStack(alignment: .top, spacing: 4) {
      PostQuoteCard(quote: quote, navigates: false)
      Button { AppHaptics.shared.play(.selection); quotedPostID = nil } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
        .buttonStyle(.plain).accessibilityLabel("Remove quote").accessibilityIdentifier("removeQuote")
    }
  }
  private func attachmentRow(_ attachment: MediaAttachment) -> some View {
    let label = attachment.klipy != nil ? "KLIPY attachment" : attachment.kind == .video ? "Video attached" : attachment.kind == .gif ? "GIF attached" : "Image attached"
    return HStack(spacing: 10) {
      // A backdrop and an edge, so a maroon or dark image still shows on the maroon card.
      AttachmentPreview(media: attachment).frame(width: 56, height: 48)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.onAccent.opacity(0.35), lineWidth: 1))
      Text(label).font(.caption)
      Spacer(minLength: 0)
      if attachment.kind == .image {
        Button { AppHaptics.shared.play(.impact); focused = nil; editImage = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }
          .buttonStyle(.plain).accessibilityLabel("Edit image").accessibilityIdentifier("postEditImage")
      }
      Button { AppHaptics.shared.play(.selection); media = nil; item = nil } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
        .buttonStyle(.plain).accessibilityLabel("Remove attachment")
    }
  }

  // MARK: Tool row

  private var toolRow: some View {
    HStack(spacing: 0) {
      Menu {
        Button("Photo or video", systemImage: "photo") { openPhotoPicker() }.accessibilityIdentifier("postPhotoPicker")
        Button("Make a meme", systemImage: "text.below.photo") { openMeme() }
      } label: { toolIcon(Image(systemName: "photo"), selected: false) }
        .accessibilityLabel("Add photo or video")
      Button { openKlipy() } label: {
        toolIcon(Text("GIF").font(.system(size: 11, weight: .heavy)).padding(.horizontal, 3).padding(.vertical, 1)
          .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(lineWidth: 1.6)), selected: false)
      }.buttonStyle(.plain).accessibilityLabel("Search GIFs and memes").accessibilityIdentifier("postKlipyPicker")
      toolToggle(.poll, symbol: "chart.bar.xaxis", name: "poll", id: "postAddPoll")
      toolToggle(.link, symbol: "link", name: "link", id: "postAddLink")
      toolToggle(.tags, symbol: "number", name: tagsTitle.lowercased(), id: "postAddTags")
      Spacer(minLength: 4)
      if focused != nil { KeyboardDismissButton { focused = nil } }
      sendButton
    }
  }
  private func toolIcon(_ icon: some View, selected: Bool) -> some View {
    icon.font(.system(size: 18, weight: .semibold))
      .frame(width: 36, height: 36)
      .background(Palette.onAccent.opacity(selected ? 0.22 : 0), in: Circle())
      .frame(width: 44, height: 44).contentShape(Rectangle())
  }
  private func toolToggle(_ tool: PostComposerFeatures.Tool, symbol: String, name: String, id: String) -> some View {
    let on = features.isOn(tool)
    return Button { AppHaptics.shared.play(.selection); toggle(tool) } label: { toolIcon(Image(systemName: symbol), selected: on) }
      .buttonStyle(.plain).accessibilityLabel((on ? "Remove " : "Add ") + name).accessibilityIdentifier(id)
      .accessibilityAddTraits(on ? .isSelected : [])
  }
  private var sendButton: some View {
    Button(action: send) {
      sendLabel.frame(minWidth: 52, minHeight: 44)
        .padding(.horizontal, 6)
        .background(Palette.onAccent.opacity(canSend ? 0.16 : 0.06), in: Capsule())
        .contentShape(Rectangle())
    }.buttonStyle(.plain).disabled(!canSend).opacity(canSend ? 1 : 0.55)
      .dynamicTypeSize(...DynamicTypeSize.accessibility2)
      .accessibilityIdentifier("publishPost").accessibilityLabel("Send")
      .accessibilityInputLabels(["Send", "Publish post"])
      .accessibilityHint(needsTopic ? "Pick a topic to send" : "")
  }
  @ViewBuilder private var sendLabel: some View {
    if sending { ProgressView().tint(Palette.onAccent) }
    else { Text("Send").font(.subheadline.bold()) }
  }

  // MARK: Panel

  private var panel: some View {
    VStack(alignment: .leading, spacing: 6) {
      if store.topicsAvailable {
        TopicChipRow(topics: store.topics, selection: Binding(get: { chosenTopic }, set: { topic = $0 }))
      }
      settingsLine
      postingLine
      if let status = offers.status { Text(status).font(.caption).foregroundStyle(Palette.secondary).accessibilityIdentifier("postShareStatus") }
      if let message = error ?? validationMessage {
        Text(message).font(.caption).foregroundStyle(Palette.accentText).accessibilityIdentifier("inlinePostError")
      }
    }.padding(.horizontal, 12).padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
      .accessibilityElement(children: .contain).accessibilityIdentifier("postOptions")
  }
  /// Anonymous and Accept DMs, then the counter: one line when it fits, else the counter goes under
  /// the toggles; everything stacks at accessibility sizes.
  private var settingsLine: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 4) { anonymousToggle; dmToggle; counter }
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 8) { anonymousToggle; dmToggle; Spacer(minLength: 0); counter }
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) { anonymousToggle; dmToggle }
            counter
          }
        }
      }
    }.font(.caption.weight(.medium)).toggleStyle(SwitchToggleStyle(tint: Palette.maroon))
  }
  private var anonymousToggle: some View {
    PublicIdentityToggle(title: "Anonymous", anonymous: $anonymous, identifier: "postAnonymous").fixedSize()
  }
  private var dmToggle: some View {
    Toggle("Accept DMs", isOn: $acceptsDM).accessibilityIdentifier("postAcceptDMs").fixedSize()
  }
  private var counter: some View {
    let limit = features.characterLimit, over = text.count > limit
    return Text("\(text.count)/\(limit.formatted())").font(.caption2.monospacedDigit().weight(over ? .bold : .regular)).fixedSize()
      .foregroundStyle(over ? Palette.accentText : Palette.secondary)
      .accessibilityLabel("\(text.count) of \(limit.formatted()) characters").accessibilityIdentifier("postCharacterCount")
  }
  private var postingLine: some View {
    HStack(alignment: .center) {
      Text("Posting to \(target.rawValue)").font(.caption2).foregroundStyle(Palette.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 4)
      if persistsContent {
        Button("Discard") { AppHaptics.shared.play(.impact); focused = nil; discard = true }
          .font(.caption.bold()).foregroundStyle(Palette.accentText).frame(minHeight: 44)
          .accessibilityHint("Deletes this post draft").accessibilityIdentifier("postDiscard")
      }
    }.frame(minHeight: 32)
  }

  // MARK: Actions

  private func expand(focus: Bool = true) {
    if draftCommunity == nil { draftCommunity = community }
    expanded = true
    if focus { focused = .body }
  }
  private func openPhotoPicker() { if expanded { AppHaptics.shared.play(.impact) }; expand(focus: false); focused = nil; photoPicker = true }
  private func openKlipy() { if expanded { AppHaptics.shared.play(.impact) }; expand(focus: false); focused = nil; klipy = true }
  private func openMeme() { if expanded { AppHaptics.shared.play(.impact) }; expand(focus: false); focused = nil; meme = true }
  /// The collapsed menu's "Add …": opens the composer with that piece on (never turns it off).
  private func add(_ tool: PostComposerFeatures.Tool) {
    if expanded && !features.isOn(tool) { AppHaptics.shared.play(.selection) }
    expand(focus: false); features.enable(tool); focus(tool)
  }
  /// The tool row: on, or off (clearing it).
  private func toggle(_ tool: PostComposerFeatures.Tool) {
    if features.toggle(tool) { focus(tool) } else { forgetFocus(of: tool) }
  }
  private func remove(_ tool: PostComposerFeatures.Tool) { features.disable(tool); forgetFocus(of: tool) }
  private func focus(_ tool: PostComposerFeatures.Tool) {
    switch tool {
    // The question is the post text; an empty one is typed first, then the first empty choice.
    case .poll: focused = text.isEmpty ? .body : features.poll.options.firstIndex(where: { $0.isEmpty }).map(Field.option) ?? .body
    case .link: focused = .link
    case .tags: focused = .tags
    }
  }
  private func forgetFocus(of tool: PostComposerFeatures.Tool) {
    switch (tool, focused) {
    case (.poll, .option?), (.link, .link?), (.tags, .tags?): focused = nil
    default: break
    }
  }
  /// Opening the composer: "Post in <topic>" sets its topic; otherwise a draft without a topic
  /// starts in the browsed one.
  private func preselectTopic() {
    if let request = store.topicComposeRequest { topic = request; store.topicComposeRequest = nil }
    else if topic == nil { topic = browsedTopic }
  }
  private func resetDraft() {
    text = ""; media = nil; item = nil; loadingMedia = false; error = nil; quotedPostID = nil; topic = nil
    features = PostComposerFeatures()
  }
  private func close() {
    focused = nil; expanded = false; draftCommunity = nil
    // Without a draft, the next opening starts in whatever topic is browsed then.
    if !hasDraft { topic = nil }
  }
  private func send() {
    guard draftOwner == store.compositions.owner, canSend else { return }
    // First post: the guidelines sheet comes first, and "I agree" sends this draft.
    if guidelines.intercept(store, retry: send) { focused = nil; return }
    AppHaptics.shared.play(.impact); sending = true; focused = nil; error = nil
    Task {
      guard await store.compositions.saveDraft(savedDraft.wrappedValue,key:draftKey,owner:draftOwner), draftOwner == store.compositions.owner else { sending=false;return }
      var succeeded = false
      // With a poll the text is its question and the body goes out empty.
      let sent = features.payload(text: text)
      let refused = await guidelines.run(store, retry: send) {
        succeeded = await store.createPost(text: sent.text, anonymous: anonymous, community: target, acceptsDM: acceptsDM, media: media, poll: sent.poll, linkURL: features.linkEnabled ? features.link : nil, tags: features.tagsEnabled ? features.tagValues : [], quoting: quotedPostID, topic: chosenTopic)
      }
      guard draftOwner == store.compositions.owner else { return }
      if refused && !succeeded { sending = false; return }
      if succeeded {
        AppHaptics.shared.play(.success)
        let posted = chosenTopic
        resetDraft(); sending = false; close(); onPublishedTopic?(posted); onPublished()
      } else { AppHaptics.shared.play(.error); sending = false; error = store.notice ?? "Your post could not be sent. Your draft is saved here; tap Send to retry." }
    }
  }
}

/// Reports a view's frame in a named coordinate space when it changes.
private struct FrameTracker: ViewModifier {
  let space: String
  let action: (CGRect) -> Void
  func body(content: Content) -> some View {
    content.onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: { action($0) }
  }
}
