import SwiftUI
import PhotosUI
import MaroonCore

struct InlinePostComposer: View {
  @Environment(AppStore.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let community: Community
  @Binding var expanded: Bool
  /// The sheet variant (QuotePostComposerSheet) keeps a separate draft from the feed's inline composer.
  var draftKey = "post"
  var quoting: String? = nil
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
  private enum Field: Hashable { case body, question, option(Int), link, tags }
  @FocusState private var focused: Field?
  @State private var pollEnabled = false
  @State private var poll = PostPollDraft()
  @State private var linkEnabled = false
  @State private var link = ""
  @State private var tagsEnabled = false
  @State private var tagsText = ""
  @State private var optionsHeight: CGFloat = 220
  @State private var quotedPostID: String?
  private var tagValues: [String] { tagsText.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init) }
  private var validation: Result<ValidatedPostFeatures, Error> {
    Result { try PostFeatureRules.validate(text: text, poll: pollEnabled ? poll : nil, linkURL: linkEnabled ? link : nil, tags: tagsEnabled ? tagValues : [], hasQuote: quotedPostID != nil) }
  }
  private var validationMessage: String? {
    if case let .failure(error) = validation, hasDraft { return error.localizedDescription }
    return nil
  }
  private var hasDraft: Bool { hasOwnContent || quotedPostID != nil }
  /// What the member wrote or attached. The sheet's quote is supplied by the screen,
  /// so a sheet closed with nothing else in it leaves no draft behind.
  private var hasOwnContent: Bool { !text.isEmpty || media != nil || item != nil || loadingMedia || pollEnabled || linkEnabled || tagsEnabled }
  private var persistsContent: Bool { quoting == nil ? hasDraft : hasOwnContent }
  private var quote: PostQuote? {
    quotedPostID.map { id in store.state.posts.first { $0.id == id }.map(PostQuote.init(quoting:)) ?? PostQuote(id: id, unavailable: true) }
  }
  private var target: Community { draftCommunity ?? community }
  private var canSend: Bool { !sending && !loadingMedia && (try? validation.get()) != nil }
  private var savedDraft: Binding<CompositionDraft> {
    Binding(get: { CompositionDraft(text: text, media: media, fields: ["anonymous": String(anonymous), "acceptsDM": String(acceptsDM), "community": target.rawValue, "pollEnabled": String(pollEnabled), "linkEnabled": String(linkEnabled), "link": link, "tagsEnabled": String(tagsEnabled), "tags": tagsText, "quotedPostID": quotedPostID ?? ""], poll: poll, nonce: "post", hasContent: persistsContent) }, set: { draft in
      text = draft.text; media = draft.media; anonymous = draft.fields["anonymous"] != "false"; acceptsDM = draft.fields["acceptsDM"] != "false"
      draftCommunity = draft.fields["community"].flatMap(Community.init(rawValue:))
      pollEnabled = draft.fields["pollEnabled"] == "true"; poll = draft.poll ?? PostPollDraft()
      linkEnabled = draft.fields["linkEnabled"] == "true"; link = draft.fields["link"] ?? ""
      tagsEnabled = draft.fields["tagsEnabled"] == "true"; tagsText = draft.fields["tags"] ?? ""
      quotedPostID = draft.fields["quotedPostID"].flatMap { $0.isEmpty ? nil : $0 }
    })
  }
  var body: some View {
    VStack(spacing: 8) {
      composerBubble
      if expanded { optionsPanel }
    }.disabled(sending).padding(.horizontal, 12).padding(.vertical, 8).background(Palette.paper)
      .overlay(alignment: .top) { Divider() }
      .onAppear { if draftOwner.isEmpty { draftOwner = store.compositions.owner } }
      .persistentDraft(draftKey, value: savedDraft)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: expanded)
      // Runs after the saved draft is restored, so the post tapped now wins over an older quote.
      .task {
        guard let quoting else { return }
        quotedPostID = quoting
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
        } else { focused = nil }
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
      .alert("Discard this post draft?", isPresented: $discard) {
        Button("Discard draft", role: .destructive) { AppHaptics.shared.play(.warning); Task { guard draftOwner == store.compositions.owner else { return }; await store.discardPendingPostDraft(owner:draftOwner); resetDraft(); close() } }
        Button("Keep editing", role: .cancel) { focused = .body }
      }
  }
  private var composerBubble: some View {
    HStack(alignment: expanded ? VerticalAlignment.top : .center, spacing: 4) {
      attachmentMenu
      if expanded { postEditor } else { expandButton }
      if expanded { VStack(spacing: 0) { closeButton; sendButton } }
    }
    .padding(.horizontal, 9)
    .foregroundStyle(Palette.onAccent)
    .background(Palette.maroon, in: RoundedRectangle(cornerRadius: expanded ? 24 : 28))
    .overlay(RoundedRectangle(cornerRadius: expanded ? 24 : 28).strokeBorder(Palette.ink.opacity(0.22), lineWidth: 0.75))
  }
  private var attachmentMenu: some View {
    Menu {
      Button("Add poll", systemImage: "chart.bar.xaxis") { addPoll() }.accessibilityIdentifier("postAddPollMenu")
      Button("Add link", systemImage: "link") { addLink() }
      Button("Add tags", systemImage: "number") { addTags() }
      Divider()
      Button("Photo, GIF, or video", systemImage: "photo") {
        if expanded { AppHaptics.shared.play(.impact) }
        expand(focus: false); focused = nil; photoPicker = true
      }.accessibilityIdentifier("postPhotoPicker")
      Button("Search memes & GIFs", systemImage: "magnifyingglass") {
        if expanded { AppHaptics.shared.play(.impact) }
        expand(focus: false); focused = nil; klipy = true
      }.accessibilityIdentifier("postKlipyPicker")
      Button("Make a meme", systemImage: "text.below.photo") {
        if expanded { AppHaptics.shared.play(.impact) }
        expand(focus: false); focused = nil; meme = true
      }
    } label: {
      Image(systemName: "photo.on.rectangle.angled").font(.system(size: 21, weight: .semibold)).frame(width: 44, height: 48)
    }.accessibilityLabel("Post attachments").accessibilityHint("Add a poll, link, tags, photo, GIF, video, or meme")
  }
  private var postEditor: some View {
    TextEditor(text: $text).font(.body).frame(minHeight: 78, maxHeight: 110)
      .scrollContentBackground(.hidden).focused($focused, equals: .body)
      .accessibilityIdentifier("postText").accessibilityLabel("Post text")
      .overlay(alignment: .topLeading) {
        if text.isEmpty {
          Text("What’s happening?").foregroundStyle(Palette.onAccent.opacity(0.75))
            .padding(.top, 8).padding(.leading, 4).allowsHitTesting(false)
        }
      }.padding(.vertical, 5)
  }
  private var expandButton: some View {
    Button { expand() } label: {
      Text(hasDraft ? "Continue your post…" : "What’s happening?")
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel("Create post")
  }
  /// Folds the composer away and keeps the draft; Cancel in the footer discards it.
  private var closeButton: some View {
    Button { AppHaptics.shared.play(.impact); close() } label: {
      Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).frame(width: 44, height: 40)
    }.buttonStyle(.plain).accessibilityLabel("Close composer").accessibilityIdentifier("closePostComposer")
  }
  private var sendButton: some View {
    Button(action: send) {
      sendLabel.frame(minWidth: 48, minHeight: 48)
    }.disabled(!canSend).opacity(canSend ? 1 : 0.55)
      .accessibilityIdentifier("publishPost").accessibilityLabel("Publish post")
  }
  @ViewBuilder private var sendLabel: some View {
    if sending { ProgressView().tint(Palette.onAccent) }
    else { Text("Send").font(.subheadline.bold()) }
  }
  private var optionsPanel: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        featureToolbar
        if let quote { quoteRow(quote) }
        if pollEnabled { pollEditor }
        if linkEnabled { linkEditor }
        if tagsEnabled { tagsEditor }
        if let media { attachmentRow(media) }
        if loadingMedia { ProgressView("Preparing attachment…").font(.caption) }
        if let status = offers.status { Text(status).font(.caption).foregroundStyle(Palette.secondary).accessibilityIdentifier("postShareStatus") }
        privacyOptions
        draftFooter
        if let message = error ?? validationMessage {
          Text(message).font(.caption).foregroundStyle(Palette.accentText).accessibilityIdentifier("inlinePostError")
        }
      }.padding(.horizontal, 12).padding(.vertical, 7)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { optionsHeight = $0 }
    }.frame(height: min(220, optionsHeight)).scrollBounceBehavior(.basedOnSize)
      .scrollDismissesKeyboard(.interactively).accessibilityIdentifier("postOptions")
      .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
  }
  private var featureToolbar: some View {
    HStack(spacing: 12) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          featureButton("Poll", symbol: "chart.bar.xaxis", selected: pollEnabled, id: "postAddPoll", action: addPoll)
          featureButton("Link", symbol: "link", selected: linkEnabled, id: "postAddLink", action: addLink)
          featureButton("Tags", symbol: "number", selected: tagsEnabled, id: "postAddTags", action: addTags)
        }.fixedSize(horizontal: true, vertical: false)
      }.scrollBounceBehavior(.basedOnSize)
      if focused != nil { KeyboardDismissButton { focused = nil } }
    }
  }
  private func featureButton(_ title: String, symbol: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
    Button(action: action) { Label(title, systemImage: symbol).font(.caption.weight(.semibold)).frame(minHeight: 44) }
      .buttonStyle(.plain).foregroundStyle(Palette.accentText).accessibilityIdentifier(id)
      .accessibilityAddTraits(selected ? .isSelected : [])
  }
  private func editorHeading(_ title: String, remove: @escaping () -> Void) -> some View {
    HStack {
      Text(title).font(.subheadline.bold())
      Spacer()
      Button { AppHaptics.shared.play(.selection); remove() } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
        .buttonStyle(.plain).accessibilityLabel("Remove " + title.lowercased())
    }
  }
  private var pollEditor: some View {
    VStack(alignment: .leading, spacing: 6) {
      editorHeading("Poll") { pollEnabled = false; focused = nil }
      TextField("Ask a question", text: $poll.question, axis: .vertical).lineLimit(1...3)
        .focused($focused, equals: .question).accessibilityIdentifier("pollQuestion")
        .accessibilityLabel("Poll question").padding(10).background(Palette.elevated, in: RoundedRectangle(cornerRadius: 9))
      ForEach(poll.options.indices, id: \.self) { index in
        HStack(spacing: 4) {
          TextField("Answer \(index + 1)", text: $poll.options[index])
            .focused($focused, equals: .option(index)).accessibilityIdentifier("pollOption\(index)")
            .padding(10).background(Palette.elevated, in: RoundedRectangle(cornerRadius: 9))
          if poll.options.count > 2 {
            Button { AppHaptics.shared.play(.selection); poll.options.remove(at: index); focused = nil } label: { Image(systemName: "minus.circle").frame(width: 44, height: 44) }
              .buttonStyle(.plain).accessibilityLabel("Remove answer \(index + 1)")
          }
        }
      }
      HStack {
        if poll.options.count < 4 { Button("Add answer", systemImage: "plus") { AppHaptics.shared.play(.selection); poll.options.append(""); focused = .option(poll.options.count - 1) }.font(.caption).frame(minHeight: 44) }
        Spacer(minLength: 0)
        Picker("Poll duration", selection: $poll.durationHours) {
          Text("1 day").tag(24); Text("3 days").tag(72); Text("7 days").tag(168)
        }.pickerStyle(.menu).accessibilityIdentifier("pollDuration")
      }
    }.font(.subheadline)
  }
  private var linkEditor: some View {
    VStack(alignment: .leading, spacing: 4) {
      editorHeading("Link") { linkEnabled = false; focused = nil }
      TextField("example.com", text: $link).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
        .focused($focused, equals: .link).accessibilityIdentifier("postLink").accessibilityLabel("Post link")
        .padding(10).background(Palette.elevated, in: RoundedRectangle(cornerRadius: 9))
    }
  }
  private var tagsEditor: some View {
    VStack(alignment: .leading, spacing: 4) {
      editorHeading("Tags") { tagsEnabled = false; focused = nil }
      TextField("campus, study_group", text: $tagsText).textInputAutocapitalization(.never).autocorrectionDisabled()
        .focused($focused, equals: .tags).accessibilityIdentifier("postTags").accessibilityLabel("Post tags")
        .padding(10).background(Palette.elevated, in: RoundedRectangle(cornerRadius: 9))
      Text("Up to 5 tags, separated by spaces or commas.").font(.caption).foregroundStyle(Palette.secondary)
    }
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
      AttachmentPreview(media: attachment).frame(width: 56, height: 48).clipShape(RoundedRectangle(cornerRadius: 8))
      Text(label).font(.caption)
      Spacer()
      if attachment.kind == .image {
        Button("Edit image") { AppHaptics.shared.play(.impact); focused = nil; editImage = true }
          .font(.caption).frame(minHeight: 44).accessibilityIdentifier("postEditImage")
      }
      Button("Remove attachment", role: .destructive) { AppHaptics.shared.play(.selection); media = nil; item = nil }
        .font(.caption).frame(minHeight: 44)
    }
  }
  private var privacyOptions: some View {
    let layout = dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 18))
    return layout {
      PublicIdentityToggle(title: "Anonymous", anonymous: $anonymous, identifier: "postAnonymous")
      Toggle("Accept DMs", isOn: $acceptsDM).accessibilityIdentifier("postAcceptDMs")
    }.font(.caption.weight(.medium)).toggleStyle(SwitchToggleStyle(tint: Palette.maroon))
  }
  private var draftFooter: some View {
    let identity = anonymous ? "Anonymous" : "@" + store.state.username
    let countColor = text.count > 1000 ? Palette.accentText : Palette.secondary
    return HStack(alignment: .center) {
      Text("\(target.rawValue) · \(identity)").font(.caption2).foregroundStyle(Palette.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 4)
      Text("\(text.count)/1,000").font(.caption2.monospacedDigit()).foregroundStyle(countColor)
      Button("Cancel") { AppHaptics.shared.play(.impact); focused = nil; if persistsContent { discard = true } else { close() } }
        .font(.caption.bold()).frame(minHeight: 44)
    }
  }
  private func expand(focus: Bool = true) {
    if draftCommunity == nil { draftCommunity = community }
    expanded = true
    if focus { focused = .body }
  }
  private func addPoll() { if expanded && !pollEnabled { AppHaptics.shared.play(.selection) }; expand(focus: false); pollEnabled = true; focused = .question }
  private func addLink() { if expanded && !linkEnabled { AppHaptics.shared.play(.selection) }; expand(focus: false); linkEnabled = true; focused = .link }
  private func addTags() { if expanded && !tagsEnabled { AppHaptics.shared.play(.selection) }; expand(focus: false); tagsEnabled = true; focused = .tags }
  private func resetDraft() {
    text = ""; media = nil; item = nil; loadingMedia = false; error = nil; quotedPostID = nil
    pollEnabled = false; poll = PostPollDraft(); linkEnabled = false; link = ""; tagsEnabled = false; tagsText = ""
  }
  private func close() { focused = nil; expanded = false; draftCommunity = nil }
  private func send() {
    guard draftOwner == store.compositions.owner, canSend else { return }; AppHaptics.shared.play(.impact); sending = true; focused = nil; error = nil
    Task {
      guard await store.compositions.saveDraft(savedDraft.wrappedValue,key:draftKey,owner:draftOwner), draftOwner == store.compositions.owner else { sending=false;return }
      let succeeded = await store.createPost(text: text.trimmingCharacters(in: .whitespacesAndNewlines), anonymous: anonymous, community: target, acceptsDM: acceptsDM, media: media, poll: pollEnabled ? poll : nil, linkURL: linkEnabled ? link : nil, tags: tagsEnabled ? tagValues : [], quoting: quotedPostID)
      guard draftOwner == store.compositions.owner else { return }
      if succeeded {
        AppHaptics.shared.play(.success)
        resetDraft(); sending = false; close(); onPublished()
      } else { AppHaptics.shared.play(.error); sending = false; error = store.notice ?? "Your post could not be sent. Your draft is saved here; tap Send to retry." }
    }
  }
}
