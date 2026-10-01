import ImageIO
import MaroonCore
import PhotosUI
import SwiftUI

struct ClassesView: View {
  @Environment(AppStore.self) private var store
  @State private var search = ""
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        SectionHeading(title: "Same class.\nNew connections.", eyebrow: "Fall 2026")
        Text("One course, one conversation. Join the classes you’re taking this semester.").font(
          .subheadline
        ).foregroundStyle(.secondary)
        ForEach(store.state.courses) { course in
          NavigationLink {
            ChatView(id: course.id)
          } label: {
            Card {
              HStack(spacing: 16) {
                Image(systemName: course.icon).font(.title2).frame(width: 50, height: 50)
                  .background(Palette.maroon.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 5) {
                  Text(course.code).font(.title3.bold())
                  Text(course.title).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
              }
            }
          }.buttonStyle(.plain)
        }
        NavigationLink {
          ActivityListView(filter: .study)
        } label: {
          Label("Find a study group", systemImage: "person.2").font(.headline)
        }
        Divider()
        Text("Add your classes").font(.title3.bold())
        TextField("Search course code or name", text: $search).padding(14).background(
          .white, in: RoundedRectangle(cornerRadius: 14))
        ForEach(
          Course.catalog.filter {
            search.isEmpty || "\($0.code) \($0.title)".localizedCaseInsensitiveContains(search)
          }
        ) { course in
          HStack {
            VStack(alignment: .leading, spacing: 5) {
              Text(course.code).font(.headline)
              Text(course.title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(store.state.courses.contains(course) ? "Joined" : "Join") {
              store.joinCourse(course)
            }.buttonStyle(.bordered).disabled(store.state.courses.contains(course))
              .accessibilityIdentifier("join-\(course.code)")
          }.padding(.vertical, 8)
        }
        Text(
          "Starter course catalog · enrollment is self-selected, not imported from university records."
        ).font(.caption2).foregroundStyle(.secondary)
      }.padding(22)
    }.appBackground().navigationTitle("Classes").navigationBarTitleDisplayMode(.inline)
  }
}
struct InboxView: View {
  @Environment(AppStore.self) private var store
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        SectionHeading(title: "Keep it going.", eyebrow: "Your inbox")
        ForEach(store.state.conversations) { chat in
          NavigationLink {
            ChatView(id: chat.id)
          } label: {
            Card {
              HStack(spacing: 14) {
                Image(
                  systemName: chat.request
                    ? "envelope.badge" : chat.anonymous ? "bubble.left" : "person.2"
                ).font(.title3).frame(width: 45, height: 45).background(Palette.paper, in: Circle())
                VStack(alignment: .leading, spacing: 6) {
                  Text(chat.title).font(.headline).lineLimit(1)
                  Text(chat.messages.last?.text ?? chat.subtitle).font(.caption).foregroundStyle(
                    .secondary
                  ).lineLimit(1)
                }
                Spacer()
                if chat.request { Circle().fill(Palette.maroon).frame(width: 8, height: 8) }
                Image(systemName: "chevron.right").font(.caption)
              }
            }
          }.buttonStyle(.plain)
        }
        if store.state.conversations.isEmpty {
          EmptyCard(
            icon: "tray", title: "A little quiet here",
            detail: "Join a class or a hangout to start a conversation.")
        }
      }.padding(20)
    }.appBackground().navigationTitle("Inbox").navigationBarTitleDisplayMode(.inline)
  }
}
struct ChatView: View {
  @Environment(AppStore.self) private var store
  let id: String
  @State private var text = ""
  @State private var item: PhotosPickerItem?
  @State private var media: MediaAttachment?
  @State private var gamePicker = false
  @FocusState private var messageFocused: Bool
  var chat: Conversation? { store.state.conversations.first { $0.id == id } }
  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 16) {
          Text(chat?.subtitle ?? "").font(.caption).foregroundStyle(.secondary).padding()
          if chat?.anonymous == true {
            Label("This conversation stays separate from your username.", systemImage: "eye.slash")
              .font(.caption).padding().background(
                Palette.paper, in: RoundedRectangle(cornerRadius: 14))
          }
          ForEach(chat?.messages ?? []) { message in
            HStack {
              if message.author == store.state.username { Spacer(minLength: 40) }
              VStack(alignment: .leading, spacing: 8) {
                Text(
                  chat?.anonymous == true
                    ? (message.author == store.state.username ? "You" : "Post author")
                    : "@\(message.author)"
                ).font(.caption2.bold()).foregroundStyle(.secondary)
                if let media = message.media {
                  AnimatedMedia(data: media.data).frame(maxWidth: 220).frame(height: 180).clipShape(
                    RoundedRectangle(cornerRadius: 12))
                }
                if let game = message.game {
                  NavigationLink {
                    GameView(kind: game)
                  } label: {
                    Label("Play \(game)", systemImage: "gamecontroller.fill").font(.headline)
                  }
                }
                if !message.text.isEmpty { Text(message.text) }
                Text(message.created, style: .time).font(.system(size: 9)).foregroundStyle(
                  .secondary)
              }.padding(14).background(
                message.author == store.state.username ? Palette.maroon.opacity(0.08) : Color.white,
                in: RoundedRectangle(cornerRadius: 18))
              if message.author != store.state.username { Spacer(minLength: 40) }
            }.id(message.id)
          }
          Color.clear.frame(height: 1).id("bottom")
        }.padding(18)
      }.onChange(of: chat?.messages.count) { _, _ in
        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
      }
    }.appBackground().navigationTitle(chat?.title ?? "Chat").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        Menu {
          Button("Leave conversation", role: .destructive) {
            store.state.conversations.removeAll { $0.id == id }
            store.state.courses.removeAll { $0.id == id }
            store.save()
          }
          Button("Report conversation", role: .destructive) {
            store.state.reports.append("Chat: \(id)")
            store.save()
            store.notice = "Report saved locally. Moderation delivery is not connected yet."
          }
        } label: {
          Image(systemName: "ellipsis")
        }
      }
      .safeAreaInset(edge: .bottom) {
        if chat?.request == true {
          HStack {
            Button("Decline", role: .destructive) {
              store.state.conversations.removeAll { $0.id == id }
              store.save()
            }
            Spacer()
            Button("Accept request") {
              if let i = store.state.conversations.firstIndex(where: { $0.id == id }) {
                store.state.conversations[i].request = false
                store.save()
              }
            }
          }.padding().background(.regularMaterial)
        } else if chat != nil {
          composer
        }
      }
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { messageFocused = false }
        }
      }
      .sheet(isPresented: $gamePicker) {
        NavigationStack {
          List(["8 Ball", "Chess", "Cup Pong"], id: \.self) { game in
            Button(game) {
              store.send(id, text: "Game invitation · local practice", game: game)
              gamePicker = false
            }
          }.navigationTitle("Send a game").toolbar { Button("Done") { gamePicker = false } }
        }.presentationDetents([.medium])
      }
      .onChange(of: item) { _, new in
        Task {
          if let data = try? await new?.loadTransferable(type: Data.self) {
            if data.count > 5_000_000 {
              store.notice = "Choose an image or GIF smaller than 5 MB."
            } else {
              media = MediaAttachment(
                kind: String(data: data.prefix(6), encoding: .ascii)?.hasPrefix("GIF") == true
                  ? .gif : .image, data: data)
            }
          }
        }
      }
  }
  var composer: some View {
    VStack(spacing: 10) {
      if let media {
        HStack {
          Image(systemName: media.kind == .gif ? "sparkles.tv" : "photo")
          Text("1 \(media.kind.rawValue) attached").font(.caption)
          Spacer()
          Button("Remove") {
            self.media = nil
            item = nil
          }
        }
      }
      HStack(spacing: 14) {
        PhotosPicker(selection: $item, matching: .images) {
          Image(systemName: "photo").font(.title3)
        }.accessibilityLabel("Attach one image or GIF")
        Button {
          gamePicker = true
        } label: {
          Image(systemName: "gamecontroller").font(.title3)
        }.accessibilityLabel("Send game")
        TextField("Message…", text: $text, axis: .vertical).lineLimit(1...4)
          .accessibilityIdentifier("messageText").focused($messageFocused)
        Button {
          store.send(id, text: text, media: media)
          text = ""
          media = nil
          item = nil
        } label: {
          Image(systemName: "arrow.up.circle.fill").font(.title)
        }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && media == nil)
          .accessibilityLabel("Send message")
      }
      Text("One image or GIF per message").font(.system(size: 9)).foregroundStyle(.secondary)
    }.padding().background(.regularMaterial)
  }
}
struct AnimatedMedia: UIViewRepresentable {
  let data: Data
  func makeUIView(context: Context) -> UIImageView {
    let view = UIImageView()
    view.contentMode = .scaleAspectFit
    view.clipsToBounds = true
    view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return view
  }
  func updateUIView(_ view: UIImageView, context: Context) {
    if let source = CGImageSourceCreateWithData(data as CFData, nil),
      CGImageSourceGetCount(source) > 1
    {
      var frames: [UIImage] = []
      var duration = 0.0
      for i in 0..<min(CGImageSourceGetCount(source), 120) {
        if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
          frames.append(UIImage(cgImage: image))
          let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any]
          let gif = props?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
          duration += max(0.02, gif?[kCGImagePropertyGIFDelayTime as String] as? Double ?? 0.1)
        }
      }
      view.image = UIImage.animatedImage(with: frames, duration: duration)
    } else {
      view.image = UIImage(data: data)
    }
  }
}
