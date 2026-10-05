import MaroonCore
import SwiftUI

struct PostDetailView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let id: String
  @State private var reply = ""
  @State private var replyNonce = UUID().uuidString
  @State private var submissionKey = ""
  @State private var discardReply = false
  @State private var anonymous = true
  @State private var sending = false
  @State private var draftOwner = ""
  @State private var replyTarget: String?
  @State private var sentReplies = 0
  @State private var lastSubmittedParent: String?
  @State private var conversationID: String?
  @State private var messageTarget: Comment?
  @FocusState private var focused: Bool
  private var post: Post? { store.state.posts.first { $0.id == id } }
  private var parent: Comment? { post?.comments.first { $0.id == replyTarget } }
  private var targetUnavailable: Bool { replyTarget != nil && (parent == nil || parent?.deleted == true) }

  private var draftKey: String { "reply:" + id }
  private var savedDraft: Binding<CompositionDraft> {
    Binding(get: {
      var fields=["anonymous":String(anonymous),"submissionKey":submissionKey]
      if let replyTarget { fields["parentID"]=replyTarget }
      return CompositionDraft(text:reply,fields:fields,nonce:replyNonce,hasContent:!reply.isEmpty || replyTarget != nil)
    },set:{value in reply=value.text;replyTarget=value.fields["parentID"];anonymous=value.fields["anonymous"] != "false";replyNonce=value.nonce;submissionKey=value.fields["submissionKey"] ?? ""})
  }
  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          if let post {
            PostCard(post: post, navigates: false, onConversationCreated: { conversationID = $0 })
              .accessibilityIdentifier("threadOriginalPost")
            HStack {
              Text("Replies").font(.headline)
              Text("\(post.comments.filter { $0.deleted != true }.count)").font(.subheadline).foregroundStyle(.secondary)
              Spacer()
            }.padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 8)
            ForEach(CommentThread.flatten(post.comments)) { row in
              ThreadReplyRow(comment: row.comment, depth: row.depth, isOrphan: row.isOrphan,
                selected: replyTarget == row.id,
                onReply: { replyTarget = row.id; focused = true },
                onMessage: { focused = false; messageTarget = row.comment })
                .id(row.id)
            }
            if post.comments.isEmpty {
              EmptyCard(icon: "bubble.left", title: "No replies yet", detail: "Be the first to reply.")
            }
          } else {
            EmptyCard(icon: "bubble.left", title: "Post unavailable", detail: "It may have been removed or blocked.")
          }
          Color.clear.frame(height: 12).id("bottom")
        }
      }.maroonRefreshable { await store.refreshAndWait() }.scrollDismissesKeyboard(.interactively)
        .onChange(of: sentReplies) { _, _ in
          Task { @MainActor in
            await Task.yield()
            let target = post?.comments.filter { store.owns($0) && $0.parentID == lastSubmittedParent }
              .max { $0.created < $1.created }?.id ?? "bottom"
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.23)) { proxy.scrollTo(target, anchor: .bottom) }
          }
        }
    }.onAppear { if draftOwner.isEmpty { draftOwner = store.compositions.owner } }.persistentDraft(draftKey,value:savedDraft).appBackground().navigationTitle("Post").navigationBarTitleDisplayMode(.inline).hidesTabBarWhenPushed()
      .navigationDestination(item: $conversationID) { ChatView(id: $0) }
      .sheet(item: $messageTarget) { comment in
        NewMessageView(commentID: comment.id, anonymous: true) { conversationID = $0 }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if post != nil && post?.deleted != true {
          VStack(alignment: .leading, spacing: 8) {
            if let replyTarget {
              HStack(spacing: 10) {
                Rectangle().fill(Palette.maroon).frame(width: 3, height: 36)
                VStack(alignment: .leading, spacing: 3) {
                  Text(targetUnavailable ? "This reply is no longer available" : "Replying to \(displayName(parent))")
                    .font(.caption.weight(.semibold)).accessibilityIdentifier("replyTarget")
                  if let parent, !targetUnavailable { Text(parent.text).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button { self.replyTarget = nil } label: {
                  Image(systemName: "xmark").font(.caption.bold()).frame(width: 44, height: 44)
                }.accessibilityLabel("Reply to post instead")
              }.id(replyTarget)
            }
            if let post, post.anonymous, store.owns(post) {
              Label("Replying anonymously as the post author", systemImage: "eye.slash").font(.caption).foregroundStyle(.secondary)
            } else {
              PublicIdentityToggle(title: "Reply anonymously", anonymous: $anonymous, identifier: "replyAnonymous").font(.caption)
            }
            HStack(alignment: .bottom, spacing: 8) {
              TextField(replyTarget == nil ? "Reply to the post…" : "Reply to this comment…", text: $reply, axis: .vertical)
                .lineLimit(1...(dynamicTypeSize.isAccessibilitySize ? 3 : 4)).focused($focused).padding(12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityIdentifier("replyText").disabled(sending)
              Button(action: send) {
                Group {
                  if sending { ProgressView().tint(Palette.onAccent) }
                  else { Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold)) }
                }.frame(width: 42, height: 42).foregroundStyle(Palette.onAccent)
                  .background(Palette.maroon, in: Circle()).frame(width: 44, height: 44)
              }.buttonStyle(ControlPressStyle())
                .disabled(sending || targetUnavailable || reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reply.count > 1000)
                .accessibilityLabel("Send reply").accessibilityIdentifier("sendReply")
            }
            if reply.count > 900 { Text("\(reply.count)/1,000").font(.caption2).foregroundStyle(reply.count > 1000 ? .red : Palette.secondary) }
          }.padding(12).background(Palette.paper).overlay(alignment: .top) { Divider() }
        }
      }
      .toolbar { ToolbarItem(placement: .topBarTrailing) { HStack { if !reply.isEmpty { Button("Discard reply",systemImage:"trash"){discardReply=true}.disabled(sending).accessibilityIdentifier("discardReplyDraft") }; if focused { KeyboardDismissButton { focused = false } } } } }
      .alert("Discard this reply draft?",isPresented:$discardReply){Button("Discard draft",role:.destructive){Task{reply="";replyTarget=nil;submissionKey="";replyNonce=UUID().uuidString;await store.compositions.removeDraft(draftKey,owner:draftOwner)}};Button("Keep editing",role:.cancel){}}
  }
  private func displayName(_ comment: Comment?) -> String {
    guard let comment else { return "a reply" }
    if store.owns(comment) { return "your reply" }
    return comment.anonymous ? comment.isOP == true ? "OP" : "Anonymous" : "@\(comment.author)"
  }
  private func send() {
    guard draftOwner == store.compositions.owner, !sending && !targetUnavailable else { return }
    let target = replyTarget
    let values=["post":id,"parent":target ?? "","text":reply.trimmingCharacters(in:.whitespacesAndNewlines),"anonymous":String(anonymous)]
    let key=(try? JSONSerialization.data(withJSONObject:values,options:[.sortedKeys]))?.base64EncodedString() ?? ""
    if submissionKey != key { submissionKey=key;replyNonce=UUID().uuidString }
    AppHaptics.shared.play(.impact)
    sending = true
    Task {
      guard await store.compositions.saveDraft(savedDraft.wrappedValue,key:draftKey,owner:draftOwner) else { store.notice=store.compositions.error;sending=false;return }
      guard draftOwner == store.compositions.owner else { return }
      let succeeded = await store.createComment(postID: id, text: reply.trimmingCharacters(in: .whitespacesAndNewlines),
                                   anonymous: anonymous, parentID: target, nonce: replyNonce)
      guard draftOwner == store.compositions.owner else { return }
      if succeeded {
        reply = ""; replyTarget = nil; lastSubmittedParent = target; sentReplies += 1;submissionKey="";replyNonce=UUID().uuidString
        await store.compositions.removeDraft(draftKey,owner:draftOwner)
        AppHaptics.shared.play(.success)
      } else { AppHaptics.shared.play(.error) }
      sending = false
    }
  }
}

private struct ThreadReplyRow: View {
  @Environment(AppStore.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let comment: Comment
  let depth: Int
  let isOrphan: Bool
  let selected: Bool
  let onReply: () -> Void
  let onMessage: () -> Void
  private var mine: Bool { store.owns(comment) }
  private var deleted: Bool { comment.deleted == true }
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .center, spacing: 8) {
        Avatar(symbol: comment.anonymous ? "bubble.left.fill" : "person.fill", size: 24)
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text(deleted ? "[deleted]" : comment.anonymous ? "Anonymous" : "@\(comment.author)")
              .font(.caption.weight(.semibold)).lineLimit(1)
            if comment.isOP == true && !deleted {
              Text("OP").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 3)
                .foregroundStyle(Palette.onAccent).background(Palette.maroon, in: Capsule())
            }
            if mine && !deleted { Text("You").font(.caption2).foregroundStyle(.secondary) }
          }
          if comment.isOP != true { Text("Reply").font(.caption2).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
        Text(shortAge(comment.created)).font(.caption2).foregroundStyle(.secondary)
        Menu {
          if !deleted {
            Button("Report reply", systemImage: "flag", role: .destructive) {
              Task { _ = await store.mutate("report", ["target_type": "comment", "target_id": comment.id, "reason": "Reply report"]) }
            }
            if mine {
              Button("Delete reply", systemImage: "trash", role: .destructive) {
                Task { _ = await store.mutate("comment.delete", ["comment_id": comment.id]) }
              }
            }
          }
        } label: {
          Image(systemName: "ellipsis").font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44)
        }.accessibilityLabel("Reply options").disabled(deleted)
      }
      if isOrphan && comment.parentID != nil {
        Label("Earlier reply unavailable", systemImage: "arrow.turn.down.right")
          .font(.caption2).foregroundStyle(.secondary)
      } else if depth > 3 {
        Label("Continuing this reply thread", systemImage: "arrow.turn.down.right")
          .font(.caption2).foregroundStyle(.secondary)
      }
      Text(deleted ? "Reply deleted" : comment.text)
        .font(.subheadline).lineSpacing(3).foregroundStyle(deleted ? Palette.secondary : Palette.ink)
        .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
        .accessibilityIdentifier("commentText-\(comment.id)")
      if !deleted {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(spacing: 3))) {
          HStack(spacing: 2) {
            Button { AppHaptics.shared.play(.impact); onReply() } label: { Label("Reply", systemImage: "arrowshape.turn.up.left").font(.caption.weight(.semibold)).frame(minHeight: 44) }
              .accessibilityIdentifier("replyTo-\(comment.id)")
            if !mine {
              Button { AppHaptics.shared.play(.impact); onMessage() } label: { Image(systemName: "envelope").font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44) }
                .accessibilityLabel("Message reply author anonymously").accessibilityIdentifier("messageComment-\(comment.id)")
            }
          }
          if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
          HStack(spacing: 2) {
            vote(1, icon: "arrow.up", label: "Upvote reply")
            Text("\(comment.score)").font(.caption.weight(.semibold)).monospacedDigit().frame(minWidth: 20)
              .contentTransition(reduceMotion ? .identity : .numericText(value: Double(comment.score)))
              .accessibilityLabel("Reply score \(comment.score)").accessibilityIdentifier("commentScore-\(comment.id)")
            vote(-1, icon: "arrow.down", label: "Downvote reply")
          }
        }.foregroundStyle(Palette.accentText)
      }
    }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
      .background(selected ? Palette.elevated.opacity(0.5) : Palette.paper)
      .overlay(alignment: .leading) {
        if depth > 0 { Rectangle().fill(Palette.border).frame(width: 2).padding(.vertical, 5) }
      }
      .padding(.leading, CGFloat(min(depth, 3)) * 12)
      .overlay(alignment: .bottom) { Divider().padding(.leading, 16 + CGFloat(min(depth, 3)) * 12) }
  }
  private func vote(_ value: Int, icon: String, label: String) -> some View {
    Button { AppHaptics.shared.play(.selection); store.voteComment(comment.id, value) } label: {
      Image(systemName: icon).font(.system(size: 16, weight: .bold)).frame(width: 36, height: 36)
        .background(comment.vote == value ? Palette.maroon : .clear, in: RoundedRectangle(cornerRadius: 10))
        .frame(width: 44, height: 44)
    }.buttonStyle(ControlPressStyle()).disabled(comment.deleted == true)
      .accessibilityLabel(label).accessibilityIdentifier("\(value == 1 ? "upvote" : "downvote")Comment-\(comment.id)")
      .accessibilityAddTraits(comment.vote == value ? .isSelected : [])
  }
}
