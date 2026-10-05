import ImageIO
import MaroonCore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct InboxView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var filter: InboxCategory = .messages
  @State private var compose = false
  @State private var group = false
  @State private var outbox = false
  @State private var gameActivity = PushGameInbox()
  @State private var destination: String?
  private var counts: InboxCounts { store.inboxCounts }
  private var chats: [Conversation] {
    var seen = Set<String>()
    return store.state.conversations.filter { chat in
      seen.insert(chat.id).inserted && store.canAccessConversation(chat.id) && counts.entries[chat.id]?.category == filter
    }.sorted {
      let first = $0.messages.last?.created ?? .distantPast, second = $1.messages.last?.created ?? .distantPast
      return first == second ? $0.id < $1.id : first > second
    }
  }
  var body: some View {
    VStack(spacing: 0) {
      (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 7)) : AnyLayout(HStackLayout(spacing: 6))) {
        ForEach(InboxCategory.allCases) { category in
          Button { if filter != category { AppHaptics.shared.play(.selection); filter = category } } label: {
            HStack(spacing: 5) {
              Text(category.rawValue).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.9)
              if counts.count(category) > 0 { InboxBadge(count: counts.count(category), request: category == .requests, selected: filter == category) }
            }.frame(maxWidth: .infinity, minHeight: 44).padding(.horizontal, 6)
              .foregroundStyle(filter == category ? Palette.onAccent : Palette.ink)
              .background(filter == category ? Palette.maroon : Palette.surface, in: RoundedRectangle(cornerRadius: 13))
          }.buttonStyle(ControlPressStyle()).accessibilityIdentifier(category.accessibilityID)
            .accessibilityLabel(category.rawValue)
            .accessibilityValue("\(counts.count(category)) " + (category == .requests ? "pending requests" : "unread messages"))
            .accessibilityAddTraits(filter == category ? .isSelected : [])
        }
        Menu {
          Button("New message", systemImage: "square.and.pencil") { compose = true }
          Button("New group", systemImage: "person.3") { group = true }
          Button("Unsent messages (\(store.compositions.queue.count))", systemImage: "clock.arrow.circlepath") { outbox = true }
        } label: {
          Image(systemName: "square.and.pencil").font(.system(size: 19, weight: .semibold))
            .foregroundStyle(Palette.accentText).frame(width: 44, height: 44)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 13))
        }.accessibilityLabel("New conversation").accessibilityIdentifier("newConversation")
      }.padding(.horizontal, 16).padding(.vertical, 10)
      Divider()
      ScrollView {
        LazyVStack(spacing: 0) {
          NavigationLink { PushGameInboxView(inbox: gameActivity).toolbar(.visible, for: .navigationBar) } label: {
            HStack(spacing: 12) {
              Image(systemName: "gamecontroller.fill").font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.accentText)
              Text("Game activity").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
              Spacer()
              let unread = gameActivity.items.filter { !$0.read }.count
              if unread > 0 { InboxBadge(count: unread, request: false) }
              Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Palette.secondary)
            }.padding(.horizontal, 20).padding(.vertical, 14).background(Palette.surface)
          }.accessibilityIdentifier("gameActivityInbox")
          ForEach(chats) { chat in
            NavigationLink { ChatView(id: chat.id).appHapticOnOpen().toolbar(.visible, for: .navigationBar) } label: {
              HStack(spacing: 12) {
                if store.conversationMeta[chat.id]?.kind == "group" {
                  GroupPhotoAvatar(roomID: chat.id, token: store.conversationMeta[chat.id]?.avatar ?? "maroon", size: 44)
                } else {
                  Avatar(symbol: chat.anonymous ? "person.fill" : "person.2.fill", size: 44)
                }
                VStack(alignment: .leading, spacing: 5) {
                  Text(chat.anonymous ? latestMessage(chat) : chat.title)
                    .font(.subheadline.weight((counts.entries[chat.id]?.badge ?? 0) > 0 ? .semibold : .regular))
                    .foregroundStyle(Palette.ink).lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                  // Display only: the row opens the chat, whose pinned tag opens the post.
                  if store.conversationMeta[chat.id]?.kind == "dm", let origin = store.conversationMeta[chat.id]?.sourcePost { SourcePostTag(context: origin) }
                  if !chat.anonymous {
                    Text(latestMessage(chat)).font(.subheadline).foregroundStyle(.secondary)
                      .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                  }
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 6) {
                  if let date = chat.messages.last?.created { Text(shortAge(date)).font(.caption).foregroundStyle(.secondary) }
                  if let entry = counts.entries[chat.id], entry.badge > 0 {
                    InboxBadge(count: entry.badge, request: entry.incomingRequest)
                  }
                }
              }.padding(.horizontal, 16).padding(.vertical, 14).background(Palette.paper).overlay(alignment: .bottom) { Divider().padding(.leading, 72) }
            }.buttonStyle(.plain)
          }
          if chats.isEmpty {
            switch filter {
            case .requests: EmptyCard(icon: "tray", title: "No message requests", detail: "Requests from posts and replies wait here until you accept them.")
            case .groups: EmptyCard(icon: "person.3", title: "No groups yet", detail: "Create a group from the compose button or accept a group invitation.")
            default: EmptyCard(icon: "tray", title: "No conversations yet", detail: "Join a class, create a plan, or message someone by username.")
            }
          }
        }
      }.maroonRefreshable { await store.refreshAndWait(); if !store.fixtureMode { await gameActivity.refresh(social: store.social) } }
    }.appBackground().toolbar(.hidden, for: .navigationBar)
      .task {
        guard !store.fixtureMode else { return }
        while !Task.isCancelled {
          await gameActivity.refresh(social: store.social)
          try? await Task.sleep(for: .seconds(15))
        }
      }
      .sheet(isPresented: $compose) { NewMessageView { destination = $0 } }
      .sheet(isPresented: $group) { CreateGroupView { destination = $0 } }
      .sheet(isPresented: $outbox) { PendingMessagesView(roomID: nil) }
      .navigationDestination(item: $destination) { ChatView(id: $0).toolbar(.visible, for: .navigationBar) }
  }

  private func latestMessage(_ chat: Conversation) -> String {
    guard let message = chat.messages.last else { return chat.request ? "Invitation to chat" : "Start the conversation" }
    if message.deleted == true { return "Message deleted" }
    if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return message.text }
    return message.game != nil ? "Game invitation" : "Photo or GIF"
  }
}

struct NewMessageView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  var postID: String? = nil
  var commentID: String? = nil
  var organizationID: String? = nil
  var anonymous = false // Retained for existing call sites; content scope enforces privacy.
  var initialUsername = ""
  var onCreated: (String) -> Void
  @State private var username = ""
  @State private var text = ""
  @State private var sending = false
  @State private var draftOwner = ""
  @State private var error: String?
  @State private var nonce = UUID().uuidString
  @State private var submissionKey = ""
  @State private var closing = false
  private enum Field: Hashable { case username, message }
  @FocusState private var focused: Field?
  private var scope: MessageRequestScope {
    if let commentID { return .reply(commentID) }
    if let postID { return .post(postID) }
    if let organizationID { return .organization(organizationID) }
    return .username
  }
  private var draftKey:String { CompositionIdentity.requestKey(scope:scope,initialUsername:initialUsername) }
  private var savedDraft:Binding<CompositionDraft> {
    Binding(get:{CompositionDraft(text:text,fields:["username":username,"submissionKey":submissionKey],nonce:nonce,hasContent:!text.isEmpty || username != initialUsername)},set:{value in
      text=value.text;username=value.fields["username"] ?? initialUsername;submissionKey=value.fields["submissionKey"] ?? "";nonce=value.nonce
    })
  }
  private func clearDraft(){text="";username=initialUsername;submissionKey="";nonce=UUID().uuidString}
  var body: some View {
    NavigationStack { Form {
      if scope.requiresUsername { TextField("Username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled().focused($focused, equals: .username).submitLabel(.next).onSubmit { focused = .message }.accessibilityIdentifier("requestUsername") }
      Section("Message request") { TextField("Say hello…", text: $text, axis: .vertical).lineLimit(dynamicTypeSize.isAccessibilitySize ? 1...3 : 3...6).focused($focused, equals: .message).accessibilityIdentifier("requestText") }
      if scope.anonymous {
        Section {
          Label("Anonymous conversation", systemImage: "lock.fill").font(.subheadline.bold()).accessibilityIdentifier("fixedAnonymousIdentity")
          Text("Your username stays hidden. You’ll see each other as You and Them. This identity cannot be changed in this conversation.").font(.caption)
        }
      } else { Text("Your username @\(store.state.username) will be visible.").font(.caption) }
      Text("The recipient must accept before you can send photos, games, or more messages.").font(.caption).foregroundStyle(.secondary)
      if let error { Text(error).font(.subheadline).foregroundStyle(Palette.accentText).accessibilityIdentifier("requestError") }
    }.disabled(sending).scrollContentBackground(.hidden).appBackground().scrollDismissesKeyboard(.interactively)
      .interactiveDismissDisabled(sending || !text.isEmpty || username != initialUsername).navigationTitle("New message").navigationBarTitleDisplayMode(.inline)
      .onAppear { if draftOwner.isEmpty { draftOwner = store.compositions.owner }; if store.compositions.draft(draftKey)==nil { username = initialUsername } }.persistentDraft(draftKey,value:savedDraft).toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("Cancel"){if !text.isEmpty || username != initialUsername{closing=true}else{dismiss()}}.disabled(sending) }
      ToolbarItem(placement: .confirmationAction) { Button(sending ? "Sending…" : "Send") {
        let key=CompositionIdentity.signature(scope.payload(text:text,username:username,nonce:""))
        if key != submissionKey{submissionKey=key;nonce=UUID().uuidString}
        sending = true; error = nil; focused = nil
        Task {
          guard await store.compositions.saveDraft(savedDraft.wrappedValue,key:draftKey,owner:draftOwner)else{error=store.compositions.error;sending=false;return}
          guard draftOwner == store.compositions.owner else { return }
          let result = await store.perform(scope.action, scope.payload(text: text, username: username, nonce: nonce))
          guard draftOwner == store.compositions.owner else { return }
          if let room = result?.resourceID { AppHaptics.shared.play(.success);clearDraft();await store.compositions.removeDraft(draftKey,owner:draftOwner);dismiss(); onCreated(room) }
          else { AppHaptics.shared.play(.error); error = store.notice ?? "Your request could not be sent. Please retry." }
          sending = false
        }
      }.disabled(sending || store.busy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 1000 || (scope.requiresUsername && username.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)).accessibilityIdentifier("sendMessageRequest") }
      ToolbarItem(placement: .topBarTrailing) { if focused != nil { KeyboardDismissButton { focused = nil } } }
    }.alert("Keep this message request draft?",isPresented:$closing){
      Button("Save and close"){Task{if await store.compositions.saveDraft(savedDraft.wrappedValue,key:draftKey,owner:draftOwner){dismiss()}else{error=store.compositions.error}}}
      Button("Discard draft",role:.destructive){Task{clearDraft();await store.compositions.removeDraft(draftKey,owner:draftOwner);dismiss()}}
      Button("Keep editing",role:.cancel){}
    }message:{Text("This draft stays attached to the same recipient or post on this device. It is never sent automatically.")} }
  }
}
struct CreateGroupView: View {
  @Environment(AppStore.self) private var store
  var onCreated: (String) -> Void
  var body: some View { GroupSetupView(social: store.social, fixtureMode: store.fixtureMode, onCreated: onCreated) }
}

/// Reconcile the submitted message with edits made while its request was in
/// flight. The picker identity matters before its replacement image has loaded.
struct MessageDraftSnapshot<PhotoSelection: Equatable> {
  var text: String
  var media: MediaAttachment?
  var replyID: String?
  var photoSelection: PhotoSelection?
  var nonce: String

  func completingSend(current: Self, succeeded: Bool) -> Self {
    var remainder = current
    if succeeded {
      if current.text == text { remainder.text = "" }
      if current.media == media && current.photoSelection == photoSelection {
        remainder.media = nil; remainder.photoSelection = nil
      }
      if current.replyID == replyID { remainder.replyID = nil }
    }
    if succeeded || current.text != text || current.media != media || current.replyID != replyID || current.photoSelection != photoSelection {
      remainder.nonce = UUID().uuidString
    }
    return remainder
  }
}

struct ChatView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let id: String
  @State private var confirmLeave = false
  @State private var text = ""
  @State private var item: PhotosPickerItem?
  @State private var media: MediaAttachment?
  @State private var loadingMedia = false
  @State private var sending = false
  @State private var draftOwner = ""
  @State private var nonce = UUID().uuidString
  @State private var submissionKey = ""
  @State private var replyTo: Message?
  @State private var gamePicker = false
  @State private var meme = false
  @State private var klipy = false
  @State private var editImage = false
  @State private var offers = AttachmentOffers()
  @State private var groupInfo = false
  @State private var notificationSettings = false
  @State private var showOutbox = false
  @State private var restoredReplyID: String?
  @State private var acceptingGroup = false
  @State private var lastTyping = Date.distantPast
  @State private var showCall = false
  @State private var displayedMessages: [Message] = []
  @State private var isNearBottom = true
  @State private var hasMessagesBelow = false
  @State private var sourcePost: SourcePostDestination?
  @FocusState private var focused: Bool
  private var chat: Conversation? { store.canAccessConversation(id) ? store.state.conversations.first { $0.id == id } : nil }
  private var meta: SocialConversationMeta? { store.conversationMeta[id] }
  private var origin: SourcePostContext? { meta?.kind == "dm" ? meta?.sourcePost : nil }
  /// Game-day rooms are keyed by their calendar event ("sports:<event id>").
  private var gameEvent: CampusEvent? {
    guard meta?.kind == "sports", id.hasPrefix("sports:") else { return nil }
    let eventID = String(id.dropFirst("sports:".count))
    return store.campus.events.first { $0.id == eventID }
  }
  private var pendingGroup: Bool { meta?.kind == "group" && chat?.request == true }
  private var canSend: Bool { !pendingGroup && chat != nil && (meta?.canSend ?? (chat?.request == false)) }
  private var draftSnapshot: MessageDraftSnapshot<PhotosPickerItem> {
    MessageDraftSnapshot(text: text, media: media, replyID: replyTo?.id ?? restoredReplyID, photoSelection: item, nonce: nonce)
  }
  private var savedDraft: Binding<CompositionDraft> {
    Binding(get: {
      var fields=["submissionKey":submissionKey];if let reply=replyTo?.id ?? restoredReplyID{fields["replyID"]=reply}
      return CompositionDraft(text:text,media:media,fields:fields,nonce:nonce,hasContent:!text.isEmpty || media != nil || replyTo != nil || restoredReplyID != nil)
    }, set: { draft in
      text = draft.text; media = draft.media; nonce = draft.nonce;submissionKey=draft.fields["submissionKey"] ?? ""
      restoredReplyID = draft.fields["replyID"]
      replyTo = chat?.messages.first { $0.id == restoredReplyID }
      if replyTo != nil { restoredReplyID = nil }
    })
  }
  private var queuedCount: Int { store.compositions.queue.filter { $0.roomID == id }.count }
  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 10) {
          if let chat {
            if chat.anonymous { Label("Your username is hidden in this conversation", systemImage: "eye.slash").font(.caption2).foregroundStyle(.secondary).padding(.vertical, 8) }
            if pendingGroup { EmptyCard(icon: "person.2.badge.plus", title: "You’re invited to \(chat.title)", detail: "Choose your group alias and avatar when you accept. Messages and the member list become available after joining.") }
            else if displayedMessages.isEmpty { EmptyCard(icon: "bubble.left.and.bubble.right", title: "Say hello", detail: "Messages are shared with the members of this conversation.") }
            ForEach(pendingGroup ? [] : displayedMessages) { message in
              messageRow(message).id(message.id)
                .transition(reduceMotion ? .identity : .asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .identity))
            }
            if !pendingGroup, let typing = meta?.typing, !typing.isEmpty { Text("\(typing.joined(separator: ", ")) typing…").font(.caption).foregroundStyle(.secondary) }
          } else { EmptyCard(icon: "bubble.left", title: "Conversation closed", detail: "You no longer have access to this conversation.") }
          Color.clear.frame(height: 1).id("bottom")
        }.padding(14)
      }.scrollDismissesKeyboard(.interactively)
        .defaultScrollAnchor(.bottom)
        .onScrollGeometryChange(for: Bool.self) { geometry in
          geometry.contentSize.height - geometry.visibleRect.maxY < 100
        } action: { _, nearBottom in
          isNearBottom = nearBottom
          if nearBottom { hasMessagesBelow = false }
        }
        .onChange(of: chat?.messages ?? [], initial: true) { _, messages in
          let previousIDs = displayedMessages.map(\.id), nextIDs = messages.map(\.id)
          let appended = !previousIDs.isEmpty && nextIDs.count > previousIDs.count && Array(nextIDs.prefix(previousIDs.count)) == previousIDs
          let shouldScroll = previousIDs.isEmpty || (appended && (isNearBottom || messages.last.map(store.isMine) == true))
          // Polls that only change read receipts, reactions, or ordering do not animate or move the scroll position.
          withAnimation(reduceMotion || !appended ? nil : .easeOut(duration: 0.23)) { displayedMessages = messages }
          if appended && !shouldScroll { hasMessagesBelow = true }
          if shouldScroll {
            Task { @MainActor in
              await Task.yield()
              withAnimation(reduceMotion || !appended ? nil : .easeOut(duration: 0.23)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
          }
          if nextIDs.last != previousIDs.last { Task { await store.markRead(id) } }
        }
        .onChange(of: focused) { _, focus in
          if focus { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.23)) { proxy.scrollTo("bottom", anchor: .bottom) } }
        }
        .overlay(alignment: .bottom) {
          if hasMessagesBelow {
            Button {
              withAnimation(reduceMotion ? nil : .easeOut(duration: 0.23)) { proxy.scrollTo("bottom", anchor: .bottom) }
              hasMessagesBelow = false
            } label: {
              Label("New messages", systemImage: "arrow.down").font(.caption.bold()).padding(.horizontal, 14).frame(minHeight: 44)
                .background(Palette.maroon, in: Capsule()).foregroundStyle(Palette.onAccent)
            }.buttonStyle(ControlPressStyle()).padding(.bottom, 8)
          }
        }
    }.appBackground().navigationTitle(chat?.anonymous == true ? "Anonymous chat" : chat?.title ?? "Conversation").navigationBarTitleDisplayMode(.inline).hidesTabBarWhenPushed()
      .safeAreaInset(edge: .top) {
        VStack(spacing: 0) {
          if let gameEvent { GameChatHeader(event: gameEvent) }
          if let origin {
            SourcePostTag(context: origin, fullWidth: true) { sourcePost = SourcePostDestination(id: $0) }
              .padding(.horizontal, 16).padding(.vertical, 9).background(Palette.surface).overlay(alignment: .bottom) { Divider() }
          }
          if let call = meta?.call, call.state == "ringing" || call.state == "connected" {
            Button { AppHaptics.shared.play(.selection); showCall = true } label: {
              HStack { Image(systemName: call.mode == "video" ? "video.fill" : "phone.fill"); Text(call.incoming ? "Incoming \(call.mode) call" : "Open \(call.mode) call"); Spacer(); Image(systemName: "chevron.right") }.font(.subheadline.bold()).padding(12).background(Palette.hero)
            }
          }
        }
      }
      .toolbar {
        if ["dm", "group"].contains(meta?.kind ?? "") && canSend { Button { AppHaptics.shared.play(.selection); showCall = true } label: { Image(systemName: "phone").font(.system(size: 19, weight: .semibold)).frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Voice or video call") }
        Menu {
        if meta?.kind == "group" && !pendingGroup { Button("Group settings", systemImage: "person.3") { AppHaptics.shared.play(.selection); groupInfo = true }.accessibilityIdentifier("groupSettings") }
        if canSend { Button("Notifications", systemImage: "bell") { notificationSettings = true } }
        Button("Report conversation", systemImage: "flag", role: .destructive) { Task { _ = await store.mutate("report", ["target_type": "room", "target_id": id, "reason": "Conversation report"]) } }
        if meta?.kind == "dm" { Button("Block person", systemImage: "hand.raised", role: .destructive) { Task { if await store.mutate("block", ["room_id": id]) { dismiss() } } } }
        Button("Leave conversation", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { confirmLeave = true }
      } label: { Image(systemName: "ellipsis").font(.system(size: 20, weight: .semibold)).frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Conversation options") }
      .confirmationDialog("Leave this conversation?", isPresented: $confirmLeave, titleVisibility: .visible) {
        Button("Leave conversation", role: .destructive) { Task { let activity = store.state.activities.first { $0.id == id }
          let action = activity == nil ? "room.leave" : meta?.role == "owner" ? "activity.cancel" : "activity.leave"
          if await store.mutate(action, [activity == nil ? "room_id" : "activity_id": id]) { dismiss() } } }
      } message: { Text("You’ll stop receiving messages. Leaving a class or activity room also removes that membership.") }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if chat?.request == true || meta?.pendingOutgoing == true {
          if meta?.pendingOutgoing == true {
            Label("Request sent · waiting for acceptance", systemImage: "clock").font(.subheadline).padding().frame(maxWidth: .infinity).background(Palette.surface)
          } else {
            VStack(spacing: 10) {
              if let origin { SourcePostTag(context: origin, fullWidth: true, identifierSuffix: "Request") { sourcePost = SourcePostDestination(id: $0) } }
              HStack {
                Button(role: .destructive) { Task { if await store.mutate(meta?.kind == "group" ? "group.decline" : "dm.decline", ["room_id": id]) { dismiss() } } } label: { Text("Decline").frame(minHeight: 44) }.accessibilityIdentifier("declineRequest")
                Spacer()
                Button("Accept request") {
                  if meta?.kind == "group" { acceptingGroup = true }
                  else { Task { let accepted = await store.mutate("dm.accept", ["room_id": id]); AppHaptics.shared.play(accepted ? .success : .error) } }
                }.buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent).accessibilityIdentifier("acceptRequest")
              }
            }.padding().background(Palette.surface)
          }
        } else if canSend { composer }
      }
      .sheet(isPresented: $showCall) { NavigationStack { Group { if meta?.kind == "group" { GroupCallView(social: store.social, roomID: id) } else { RoomCallView(social: store.social, roomID: id) } }.toolbar { Button("Done") { showCall = false } } } }
      .sheet(isPresented: $gamePicker) { GameInviteSheet(roomID: id, onSent: { await store.refresh() }) }
      .sheet(isPresented: $notificationSettings) { RoomNotificationSettings(roomID: id) }
      .sheet(isPresented: $showOutbox) { PendingMessagesView(roomID: id) }
      .navigationDestination(item: $sourcePost) { PostDetailView(id: $0.id).appHapticOnOpen().toolbar(.visible, for: .navigationBar) }
      .onAppear { if draftOwner.isEmpty { draftOwner = store.compositions.owner } }
      .persistentDraft("message:" + id, value: savedDraft)
      .sheet(isPresented: $groupInfo) { GroupManageView(roomID: id) }
      .sheet(isPresented: $acceptingGroup) { GroupIdentityView(social: store.social, fixtureMode: store.fixtureMode, action: .accept(id), groupName: chat?.title ?? "") { _ in } }
      .sheet(isPresented: $meme) { MemeComposerView(draftKey:"meme:message:"+id) { attachment in item = nil; media = attachment; offers.arrived(attachment) } }
      .sheet(isPresented: $klipy) { KlipyPickerView(available: !store.fixtureMode) { attachment in item = nil; media = attachment } }
      .sheet(isPresented: $editImage) {
        if let media { ImageEditorView(source: media) { edited in item = nil; self.media = edited; offers.arrived(edited) } }
      }
      .attachmentOffers(offers, service: SharedMemeService(social: store.social, fixtureMode: store.fixtureMode))
      .task { await store.markRead(id) }
      .onChange(of: chat?.id) { _, value in
        if value == nil {
          focused = false; text = ""; media = nil; item = nil; replyTo = nil
          gamePicker = false; meme = false; klipy = false; editImage = false; groupInfo = false; acceptingGroup = false; showCall = false
          displayedMessages = []; hasMessagesBelow = false
        }
      }
      .task(id: item) {
        guard let item else { loadingMedia = false; return }
        loadingMedia = true
        let prepared = await loadPickedMedia(item, store: store)
        guard !Task.isCancelled, self.item == item else { return }
        media = prepared; loadingMedia = false
        if let prepared { offers.arrived(prepared) }
      }
      .toolbar { ToolbarItem(placement: .topBarTrailing) { if focused { KeyboardDismissButton { focused = false } } } }
  }
  private func messageRow(_ message: Message) -> some View {
    let mine = store.isMine(message)
    return HStack(alignment: .bottom) {
      if mine { Spacer(minLength: 40) }
      VStack(alignment: .leading, spacing: 6) {
        if meta?.kind == "group" {
          HStack(spacing: 6) { GroupPhotoAvatar(roomID: id, memberKey: message.memberKey ?? "unavailable", token: message.avatar ?? "maroon", size: 24); Text(mine ? "\(message.author) · You" : message.author).font(.caption2.bold()).foregroundStyle(Palette.accentText) }
        } else if !mine || chat?.anonymous == true { Text(ChatParticipantLabel.name(author: message.author, mine: mine, anonymous: chat?.anonymous == true)).font(.caption2.bold()).foregroundStyle(Palette.accentText) }
        if let reply = message.replyTo, let original = chat?.messages.first(where: { $0.id == reply }) {
          Text(original.text).font(.caption).lineLimit(2).padding(8).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        }
        if let attachmentID = message.attachmentID { RemoteMedia(attachmentID: attachmentID).frame(maxWidth: 230, maxHeight: 220) }
        else if let media = message.media { AttachmentPreview(media: media).frame(width: 210, height: 180) }
        if let session = message.gameSessionID {
          if meta?.kind == "group" { GroupGameInvitationCard(sessionID: session, title: message.game ?? "Game") }
          else { NavigationLink { OnlineGameView(sessionID: session) } label: { Label("Open \(message.game ?? "game")", systemImage: "gamecontroller.fill").font(.headline) } }
        } else if let game = message.game { NavigationLink { GameView(kind: game) } label: { Label("Play \(game)", systemImage: "gamecontroller") } }
        if !message.text.isEmpty { Text(message.text).textSelection(.enabled).foregroundStyle(message.deleted == true ? .secondary : Palette.ink) }
        if let reactions = message.reactions, !reactions.isEmpty {
          (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))) { ForEach(reactions.keys.sorted(), id: \.self) { emoji in
            Button { react(message.id, emoji) } label: { Text("\(emoji) \(reactions[emoji] ?? 0)").font(.caption).padding(.horizontal, 6).frame(minWidth: 44, minHeight: 44).background(Palette.surface.opacity(0.7), in: Capsule()) }
              .accessibilityLabel("\(emoji), \(reactions[emoji] ?? 0) reactions").accessibilityHint("Add or remove your reaction")
          } }
        }
        HStack(spacing: 5) { Text(message.created, style: .time); if mine { Image(systemName: "checkmark").accessibilityLabel("Sent") } }.font(.caption2).foregroundStyle(.secondary)
      }.padding(12).background(mine ? Palette.maroon : Palette.surface, in: RoundedRectangle(cornerRadius: 16))
        .contextMenu {
          if message.deleted != true {
            Button("Reply", systemImage: "arrowshape.turn.up.left") { replyTo = message; restoredReplyID = nil; focused = true }
            Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = message.text }
            ForEach(["❤️", "👍", "😂", "👀"], id: \.self) { emoji in Button(emoji) { react(message.id, emoji) } }
            if mine { Button("Delete message", systemImage: "trash", role: .destructive) { Task { _ = await store.mutate("room.delete", ["room_id": id, "message_id": message.id]) } } }
            Button("Report message", systemImage: "flag", role: .destructive) { Task { _ = await store.mutate("report", ["target_type": "message", "target_id": message.id, "reason": "Message report"]) } }
          }
        }
      if !mine { Spacer(minLength: 40) }
    }
  }
  private func react(_ message: String, _ emoji: String) { Task { _ = await store.mutate("room.react", ["room_id": id, "message_id": message, "emoji": emoji]) } }
  private var composer: some View {
    VStack(spacing: 8) {
      if queuedCount > 0 {
        Button { focused = false; showOutbox = true } label: { HStack { Image(systemName: "clock.arrow.circlepath"); Text("\(queuedCount) unsent \(queuedCount == 1 ? "message" : "messages")"); Spacer(); Text("Review"); Image(systemName: "chevron.right") }.font(.caption).frame(minHeight: 36) }.accessibilityIdentifier("messageOutbox")
      }
      if restoredReplyID != nil && replyTo == nil {
        HStack { Text("Your saved reply’s original message is unavailable.").font(.caption); Button("Clear reply") { restoredReplyID = nil } }
      }
      if let error = store.compositions.error { Text(error).font(.caption).foregroundStyle(Palette.secondary) }
      if let replyTo {
        HStack { Text("Replying to: \(replyTo.text)").lineLimit(1).font(.caption); Spacer(); Button { self.replyTo = nil; restoredReplyID = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Cancel reply") }
      }
      if let media {
        HStack { AttachmentPreview(media: media).frame(width: 44, height: 44); Text(media.kind == .video ? "Video attached" : media.kind == .gif ? "GIF attached" : "Photo attached").font(.caption); Spacer(); if media.kind == .image { Button { AppHaptics.shared.play(.impact); focused = false; editImage = true } label: { Text("Edit").frame(minHeight: 44) }.accessibilityLabel("Edit image").accessibilityIdentifier("messageEditImage") }; Button { self.media = nil; item = nil } label: { Text("Remove").frame(minHeight: 44) }.accessibilityLabel("Remove attachment") }
      }
      if loadingMedia { ProgressView("Preparing attachment…").font(.caption) }
      if let status = offers.status { Text(status).font(.caption).foregroundStyle(Palette.secondary).accessibilityIdentifier("messageShareStatus") }
      (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .bottom, spacing: 6))) {
        HStack(spacing: 6) {
        Menu {
          Button("Invite to a game", systemImage: "gamecontroller") { focused = false; gamePicker = true }
          Button("Search memes & GIFs", systemImage: "magnifyingglass") { focused = false; klipy = true }
          Button("Make a meme", systemImage: "text.below.photo") { focused = false; meme = true }
        } label: { Image(systemName: "plus.circle").font(.system(size: 23, weight: .semibold)).foregroundStyle(Palette.accentText).frame(width: 44, height: 44) }.accessibilityLabel("Send game").accessibilityHint("Add a game, search KLIPY, or make a meme")
        PhotosPicker(selection: $item, matching: .any(of: [.images, .videos])) { Image(systemName: "photo").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.accentText).frame(width: 44, height: 44) }.accessibilityLabel("Attach a photo, GIF, or video")
        }
        HStack(alignment: .bottom, spacing: 6) {
        TextField("Message…", text: $text, axis: .vertical).lineLimit(1...(dynamicTypeSize.isAccessibilitySize ? 3 : 5)).focused($focused).submitLabel(.send)
          .padding(11).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18)).accessibilityIdentifier("messageText")
          .onSubmit { send() }
          .onChange(of: text) { _, value in if !store.fixtureMode && store.connected && !value.isEmpty && Date.now.timeIntervalSince(lastTyping) > 4 { lastTyping = .now; Task { _ = try? await store.social.perform("room.typing", payload: ["room_id": id]) } } }
        Button(action: send) { Image(systemName: "arrow.up").font(.system(size: 20, weight: .bold)).frame(width: 40, height: 40).background(Palette.maroon, in: Circle()).foregroundStyle(Palette.onAccent).frame(width: 44, height: 44) }.buttonStyle(ControlPressStyle())
          .disabled(sending || loadingMedia || restoredReplyID != nil || text.count > 4000 || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && media == nil)).accessibilityLabel("Send message").accessibilityIdentifier("sendMessage")
        }
      }
    }.padding(12).background(Palette.paper).overlay(alignment: .top) { Divider() }
  }
  private func send() {
    guard draftOwner == store.compositions.owner, canSend, !sending, !loadingMedia, restoredReplyID == nil, text.count <= 4000,
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || media != nil else { return }
    let key=CompositionIdentity.signature(["room":id,"text":text,"media":media?.id ?? "","reply":replyTo?.id ?? restoredReplyID ?? ""])
    if key != submissionKey{submissionKey=key;nonce=UUID().uuidString}
    let submitted = draftSnapshot
    sending = true
    Task {
      guard await store.compositions.saveDraft(savedDraft.wrappedValue,key:"message:"+id,owner:draftOwner)else{store.notice=store.compositions.error;sending=false;return}
      guard draftOwner == store.compositions.owner else { return }
      let sent = await store.sendMessage(roomID: id, text: submitted.text, media: submitted.media, replyTo: submitted.replyID, nonce: submitted.nonce)
      guard draftOwner == store.compositions.owner else { return }
      AppHaptics.shared.play(sent ? (store.compositions.queue.contains { $0.id == submitted.nonce } ? .impact : .success) : .error)
      let remaining = submitted.completingSend(current: draftSnapshot, succeeded: sent)
      text = remaining.text; media = remaining.media; item = remaining.photoSelection; nonce = remaining.nonce
      if remaining.replyID == nil { replyTo = nil; restoredReplyID = nil }
      sending = false
    }
  }
}

struct GroupManageView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let roomID: String
  var body: some View {
    NavigationStack {
      CommunityDetailView(id: roomID, social: store.social, fixtureMode: store.fixtureMode, showsOpenChat: false)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }
}

@MainActor func loadPickedMedia(_ item: PhotosPickerItem?, store: AppStore) async -> MediaAttachment? {
  guard let item else { return nil }
  do {
    if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
      guard let picked = try await item.loadTransferable(type: PickedVideo.self) else { throw VideoCompression.Failure.unsupported }
      defer { try? FileManager.default.removeItem(at: picked.url) }
      return try await VideoCompression.prepare(picked.url)
    }
    guard let data = try await item.loadTransferable(type: Data.self), !Task.isCancelled else { return nil }
    let encoded = try await MediaCompression.prepare(data)
    try Task.checkCancellation()
    return encoded.attachment
  } catch { if !Task.isCancelled { store.notice = error.localizedDescription }; return nil }
}

struct RemoteMedia: View {
  enum Layout { case fill, feed }
  @Environment(AppStore.self) private var store
  let attachmentID: String
  var layout: Layout = .fill
  /// Width cap for the feed layout; quote cards pass a smaller one.
  var maxWidth: CGFloat = MediaGeometry.feedMaxWidth
  @State private var data: Data?
  @State private var failed = false
  @State private var isKlipy = false
  @State private var isVideo = false
  @State private var retry = 0
  @State private var paused = false
  var body: some View {
    Group {
      if let data, isVideo {
        if layout == .feed { VideoAttachmentView(data: data).postMedia(ratio: MediaGeometry.ratio(of: data), maxWidth: maxWidth) } else { VideoAttachmentView(data: data) }
      }
      else if let data {
        let picture = AnimatedMedia(data: data, paused: paused).overlay(alignment: .bottomLeading) { if isKlipy { Text("KLIPY").font(.caption2.bold()).padding(5).background(Palette.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 5)).padding(6) } }
          .overlay(alignment: .bottomTrailing) {
            if String(data: data.prefix(6), encoding: .ascii)?.hasPrefix("GIF") == true {
              Button { paused.toggle() } label: { Image(systemName: paused ? "play.circle.fill" : "pause.circle.fill").font(.title2).padding(8).background(.ultraThinMaterial, in: Circle()) }.accessibilityLabel(paused ? "Play GIF" : "Pause GIF")
            }
          }
        if layout == .feed { picture.postMedia(ratio: MediaGeometry.ratio(of: data), maxWidth: maxWidth) }
        else { picture.frame(minHeight: 160).clipShape(RoundedRectangle(cornerRadius: 12)) }
      }
      else if failed { Button("Reload attachment") { retry += 1 }.font(.caption).padding(20) }
      else if layout == .feed { ProgressView().frame(width: min(180, maxWidth), height: 120 * min(180, maxWidth) / 180).background(Palette.elevated.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous)).frame(maxWidth: .infinity, alignment: .leading) }
      else { ProgressView().frame(height: 120) }
    }.task(id: "\(attachmentID)-\(retry)") { do { let result = try await store.social.attachmentContent(attachmentID); try Task.checkCancellation(); data = result.data; isKlipy = result.isKlipy; isVideo = result.mime == "video/mp4"; failed = false } catch { failed = true } }
  }
}

/// Feed pictures keep their own shape: sized to the image, capped, left-aligned
/// under the text with rounded corners, instead of a centered full-width box.
enum MediaGeometry {
  static let feedMaxWidth: CGFloat = 300
  static let feedMaxHeight: CGFloat = 260
  static let cornerRadius: CGFloat = 14
  /// Width ÷ height read from the container metadata only; nothing is decoded.
  static func ratio(of data: Data) -> CGFloat? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? CGFloat, let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
          width > 0, height > 0 else { return nil }
    return width / height
  }
}
extension View {
  /// An exact box in the picture's own proportions (so the rounded clip hugs the
  /// picture), capped at 300×260 points and pinned to the leading edge.
  func postMedia(ratio: CGFloat?, maxWidth: CGFloat = MediaGeometry.feedMaxWidth) -> some View {
    let proportion = max(0.5, min(ratio ?? 4 / 3, 2.4))
    // The height cap scales with the width cap so a smaller box keeps the feed's shape.
    let maxHeight = MediaGeometry.feedMaxHeight * maxWidth / MediaGeometry.feedMaxWidth
    let width = min(maxWidth, maxHeight * proportion)
    return frame(width: width, height: width / proportion)
      .clipShape(RoundedRectangle(cornerRadius: MediaGeometry.cornerRadius, style: .continuous))
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
extension MediaAttachment {
  /// Local drafts and preview fixtures: the poster for video, the first frame otherwise.
  var aspectRatio: CGFloat? { MediaGeometry.ratio(of: kind == .video ? (thumbnail ?? data) : data) }
}

struct AnimatedMedia: UIViewRepresentable {
  let data: Data
  var paused = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  final class MediaImageView: UIImageView {
    private let unavailable = UILabel()
    override init(frame: CGRect) {
      super.init(frame: frame)
      unavailable.text = "Attachment unavailable"; unavailable.textColor = .secondaryLabel
      unavailable.font = .preferredFont(forTextStyle: .caption1); unavailable.adjustsFontForContentSizeCategory = true
      unavailable.numberOfLines = 0; unavailable.textAlignment = .center
      unavailable.accessibilityIdentifier = "mediaUnavailable"; unavailable.isHidden = true
      unavailable.translatesAutoresizingMaskIntoConstraints = false; addSubview(unavailable)
      NSLayoutConstraint.activate([unavailable.centerXAnchor.constraint(equalTo: centerXAnchor), unavailable.centerYAnchor.constraint(equalTo: centerYAnchor), unavailable.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8), unavailable.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func resetStatus() { unavailable.isHidden = true; accessibilityLabel = nil }
    func showUnavailable() { image = nil; unavailable.isHidden = false }
  }
  @MainActor final class Coordinator {
    var displayedData: Data?
    var firstFrame: UIImage?
    private var prepared: MediaCompression.DisplayFrames?
    private var decodeTask: Task<Void, Never>?
    private var revision = 0
    private var wantsAnimation = false
    private var playing = false
    static let animationKey = "maroonGIFFrames"
    func display(_ data: Data, in view: UIImageView, animate: Bool) {
      wantsAnimation = animate
      guard displayedData != data else { apply(to: view); return }
      displayedData = data; revision += 1; let expected = revision
      decodeTask?.cancel(); prepared = nil; firstFrame = nil; playing = false
      view.layer.removeAnimation(forKey: Self.animationKey); view.image = nil
      (view as? MediaImageView)?.resetStatus()
      decodeTask = Task { [weak self, weak view] in
        let worker = Task.detached(priority: .userInitiated) { try MediaCompression.displayFrames(data) }
        do {
          let decoded = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
          guard !Task.isCancelled, let self, let view, self.revision == expected else { return }
          self.prepared = decoded; self.firstFrame = decoded.frames.first.map { UIImage(cgImage: $0) }
          view.image = self.firstFrame; self.apply(to: view)
        } catch {
          guard !Task.isCancelled, let self, let view, self.revision == expected else { return }
          do {
            let bitmap = try await MediaCompression.thumbnail(data)
            guard !Task.isCancelled, self.revision == expected else { return }
            let still = UIImage(cgImage: bitmap)
            self.prepared = MediaCompression.DisplayFrames(frames: [bitmap], delays: [0.1], loopCount: nil)
            self.firstFrame = still; view.image = still
            view.accessibilityLabel = "Still image preview. Animation unavailable."
          } catch {
            guard !Task.isCancelled, self.revision == expected else { return }
            (view as? MediaImageView)?.showUnavailable()
          }
        }
      }
    }
    private func apply(to view: UIImageView) {
      guard let prepared else { return }
      let shouldPlay = wantsAnimation && prepared.frames.count > 1
      guard shouldPlay != playing else { return }
      playing = shouldPlay
      view.layer.removeAnimation(forKey: Self.animationKey)
      view.image = firstFrame
      guard shouldPlay else { return }
      let animation = CAKeyframeAnimation(keyPath: "contents")
      animation.values = prepared.frames + [prepared.frames.last!]
      var elapsed = 0.0
      animation.keyTimes = prepared.delays.map { delay in defer { elapsed += delay }; return NSNumber(value: elapsed / prepared.duration) } + [1]
      animation.duration = prepared.duration; animation.calculationMode = .discrete
      // GIF's positive loop extension counts repeats after the initial play.
      // No loop extension means play once; zero means repeat indefinitely.
      animation.repeatCount = prepared.loopCount == 0 ? Float.greatestFiniteMagnitude : Float((prepared.loopCount ?? 0) + 1)
      animation.isRemovedOnCompletion = false; animation.fillMode = .forwards
      view.layer.contentsGravity = .resizeAspect
      view.layer.add(animation, forKey: Self.animationKey)
    }
    func stop(_ view: UIImageView) {
      revision += 1; decodeTask?.cancel(); decodeTask = nil
      view.layer.removeAnimation(forKey: Self.animationKey)
    }
  }
  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeUIView(context: Context) -> UIImageView {
    let view = MediaImageView(frame: .zero); view.contentMode = .scaleAspectFit; view.clipsToBounds = true
    view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    return view
  }
  func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
    let bitmap = uiView.image?.size ?? CGSize(width: 1, height: 1)
    let width = max(1, proposal.width ?? min(bitmap.width, 320))
    let height = proposal.height ?? min(360, width * bitmap.height / max(1, bitmap.width))
    return CGSize(width: width, height: max(1, height))
  }
  func updateUIView(_ view: UIImageView, context: Context) {
    context.coordinator.display(data, in: view, animate: !paused && !reduceMotion)
  }
  static func dismantleUIView(_ view: UIImageView, coordinator: Coordinator) { coordinator.stop(view) }

}

private struct InboxBadge: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let count: Int
  var request = false
  var selected = false
  var body: some View {
    Text(count > 99 ? "99+" : "\(count)").font(.caption2.bold()).monospacedDigit()
      .padding(.horizontal, 6).frame(minWidth: 21, minHeight: 21)
      .background(Palette.maroon, in: Capsule()).foregroundStyle(Palette.onAccent)
      .overlay(Capsule().strokeBorder(selected ? Palette.onAccent.opacity(0.4) : .clear, lineWidth: 1))
      .contentTransition(reduceMotion ? .identity : .numericText())
      .accessibilityLabel("\(count) " + (request ? "pending request" : "unread messages"))
  }
}
