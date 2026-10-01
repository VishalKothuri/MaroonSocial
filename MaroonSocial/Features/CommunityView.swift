import MaroonCore
import SwiftUI

struct CommunityView: View {
  @Environment(AppStore.self) private var store
  @State private var community = Community.campus
  @State private var sort = "New"
  @State private var compose = false
  @State private var settings = false
  @State private var adultGate = false
  @State private var unlocked = false
  var posts: [Post] {
    let p = store.state.posts.filter {
      $0.community == community && !store.state.hiddenPosts.contains($0.id)
    }
    return sort == "Top" ? p.sorted { $0.score > $1.score } : p.sorted { $0.created > $1.created }
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Wordmark(small: true)
          Spacer()
          Button {
            settings = true
          } label: {
            Image(systemName: "person.crop.circle").font(.title2)
          }.accessibilityLabel("Profile and settings")
        }
        ZStack(alignment: .bottomLeading) {
          CampusPhoto().frame(height: 170).clipped()
          LinearGradient(
            colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
          VStack(alignment: .leading, spacing: 5) {
            Text("THE CAMPUS CONVERSATION").font(.system(size: 9, weight: .bold)).tracking(2)
            Text(community == .campus ? "Howdy, Aggies." : "After hours.").font(
              .system(size: 33, weight: .bold, design: .serif))
            Text(
              community == .campus
                ? "Big campus. Small world." : "18+ conversations. Keep it non-explicit."
            ).font(.caption)
          }.foregroundStyle(.white).padding(20)
        }.clipShape(RoundedRectangle(cornerRadius: 22))
        HStack {
          Menu {
            Button("Texas A&M") { community = .campus }
            Button("NSFW · 18+ discussions") {
              if unlocked { community = .nsfw } else { adultGate = true }
            }
          } label: {
            Label(community.rawValue, systemImage: "chevron.down").font(.headline)
          }
          Spacer()
          ForEach(["New", "Top"], id: \.self) { s in
            Button {
              sort = s
            } label: {
              Pill(text: s, selected: sort == s)
            }
          }
        }
        if community == .nsfw {
          Text(
            "No nudity or explicit sexual media. Be considerate and protect other people’s privacy."
          ).font(.caption).foregroundStyle(.secondary)
        }
        ForEach(posts) { post in PostCard(post: post) }
        Text("Sample conversations · not real student activity").font(.caption2).foregroundStyle(
          .secondary
        ).frame(maxWidth: .infinity)
      }.padding(20).padding(.bottom, 70)
    }.appBackground().toolbar(.hidden, for: .navigationBar)
      .overlay(alignment: .bottomTrailing) {
        Button {
          compose = true
        } label: {
          Image(systemName: "plus").font(.title2.bold()).padding(20).background(
            Palette.maroon, in: Circle()
          ).foregroundStyle(.white).shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }.accessibilityLabel("Create post").padding(22)
      }
      .sheet(isPresented: $compose) { ComposePostView(community: community) }.sheet(
        isPresented: $settings
      ) { SettingsView() }
      .alert("18+ discussions", isPresented: $adultGate) {
        Button("Enter community") {
          unlocked = true
          community = .nsfw
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("This space allows mature discussions, but no nudity or explicit sexual media.")
      }
  }
}
struct PostCard: View {
  @Environment(AppStore.self) private var store
  let post: Post
  var navigates = true
  private var postText: some View {
    Text(post.text).font(.system(size: 17, weight: .medium)).lineSpacing(5)
      .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
  }
  var body: some View {
    Card {
      VStack(alignment: .leading, spacing: 15) {
        HStack {
          Circle().fill(post.anonymous ? Palette.maroon.opacity(0.1) : Palette.lime).frame(
            width: 28, height: 28
          ).overlay(
            Image(systemName: post.anonymous ? "bubble.left" : "person.fill").font(.caption)
              .foregroundStyle(Palette.maroon))
          Text(post.displayName).font(.caption.bold())
          Text(post.created, style: .relative).font(.caption2).foregroundStyle(.secondary)
          Spacer()
          Menu {
            Button(post.saved ? "Unsave" : "Save", systemImage: "bookmark") {
              store.toggleSave(post.id)
            }
            Button("Hide and report", systemImage: "flag", role: .destructive) {
              store.report(post.id, reason: "Community report")
            }
            Button(
              "Hide this author", systemImage: "person.crop.circle.badge.minus", role: .destructive
            ) {
              for p in store.state.posts where p.author == post.author {
                store.state.hiddenPosts.insert(p.id)
              }
              store.save()
            }
          } label: {
            Image(systemName: "ellipsis").padding(7)
          }
        }
        if navigates {
          NavigationLink {
            PostDetailView(id: post.id)
          } label: {
            postText
          }.buttonStyle(.plain)
        } else {
          postText
        }
        HStack(spacing: 15) {
          HStack(spacing: 10) {
            Button {
              store.vote(post.id, 1)
            } label: {
              Image(systemName: "arrow.up").fontWeight(.bold).foregroundStyle(
                post.vote == 1 ? Palette.maroon : .secondary)
            }.accessibilityLabel("Upvote")
            Text("\(post.score)").font(.caption.bold()).monospacedDigit()
            Button {
              store.vote(post.id, -1)
            } label: {
              Image(systemName: "arrow.down").foregroundStyle(
                post.vote == -1 ? Palette.maroon : .secondary)
            }.accessibilityLabel("Downvote")
          }.padding(.horizontal, 12).padding(.vertical, 8).background(Palette.paper, in: Capsule())
          if navigates {
            NavigationLink {
              PostDetailView(id: post.id)
            } label: {
              Label("\(post.comments.count)", systemImage: "bubble.right").font(.caption)
            }
          } else {
            Label("\(post.comments.count)", systemImage: "bubble.right").font(.caption)
          }
          Spacer()
          if post.saved {
            Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(Palette.maroon)
          }
          if post.acceptsDM {
            Text("DMs open").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
          }
        }
      }
    }
  }
}
struct ComposePostView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let community: Community
  @State private var text = ""
  @State private var anonymous = true
  @State private var dms = false
  var body: some View {
    NavigationStack {
      Form {
        Section("What’s on your mind?") {
          TextEditor(text: $text).frame(minHeight: 160).accessibilityIdentifier("postText")
          Text("\(text.count)/1,000").font(.caption).foregroundStyle(.secondary)
        }
        Section {
          Toggle("Post anonymously", isOn: $anonymous)
          Toggle("Allow message requests", isOn: $dms)
        } footer: {
          Text(
            anonymous
              ? "This post has its own anonymous conversation. Your username will not appear on it."
              : "Your username @\(store.state.username) will appear on this post.")
        }
        Section { Text("Posting to \(community.rawValue)").font(.subheadline) }
      }.navigationTitle("Say something.").navigationBarTitleDisplayMode(.inline).toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Post") {
            store.state.posts.insert(
              Post(
                author: store.state.username, anonymous: anonymous, community: community,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines), acceptsDM: dms), at: 0)
            store.save()
            dismiss()
          }.disabled(
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 1000)
        }
      }
    }
  }
}
struct PostDetailView: View {
  @Environment(AppStore.self) private var store
  let id: String
  @State private var reply = ""
  @State private var anonymous = true
  var post: Post? { store.state.posts.first { $0.id == id } }
  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        if let post {
          PostCard(post: post, navigates: false)
          if post.acceptsDM {
            Button("Request a private chat") {
              let chatID = "post-\(post.id)"
              if !store.state.conversations.contains(where: { $0.id == chatID }) {
                store.state.conversations.append(
                  Conversation(
                    id: chatID,
                    title: post.anonymous ? "Anonymous • post conversation" : post.displayName,
                    subtitle: "Local conversation preview", anonymous: post.anonymous))
                store.save()
              }
              store.notice =
                "Conversation added to Inbox. In this local preview, no request is sent to another person."
            }.font(.subheadline)
          }
          ForEach(post.comments) { comment in
            Card {
              VStack(alignment: .leading, spacing: 10) {
                Text(comment.anonymous ? "Anonymous reply" : "@\(comment.author)").font(
                  .caption.bold()
                ).foregroundStyle(.secondary)
                Text(comment.text)
              }
            }
          }
          if post.comments.isEmpty {
            EmptyCard(
              icon: "bubble.left", title: "Start the conversation",
              detail: "A good reply goes a long way.")
          }
        }
      }.padding(20)
    }.appBackground().navigationTitle("Conversation").navigationBarTitleDisplayMode(.inline)
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: 9) {
          Toggle("Reply anonymously", isOn: $anonymous).font(.caption)
          HStack {
            TextField("Add a reply…", text: $reply, axis: .vertical).lineLimit(1...4)
            Button {
              guard let i = store.state.posts.firstIndex(where: { $0.id == id }) else { return }
              store.state.posts[i].comments.append(
                Comment(author: store.state.username, text: reply, anonymous: anonymous))
              reply = ""
              store.save()
            } label: {
              Image(systemName: "arrow.up.circle.fill").font(.title)
            }.disabled(
              reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reply.count > 1000)
          }
        }.padding().background(.regularMaterial)
      }
  }
}
struct SettingsView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        Section {
          Label("@\(store.state.username)", systemImage: "person.crop.circle")
          Text("Local preview · not student verified").font(.caption).foregroundStyle(.secondary)
        }
        Section("Your privacy") {
          Text(
            "Anonymous community posts hide your username from other users. This development build stores sample activity on your device. Enrollment and stronger identity separation are not enabled yet."
          )
          Text("One username is used in classes, study groups, recreation, hangouts and games.")
        }
        Section("Connections") {
          Text("Supabase · Maroon Social")
          Text("No paid plan or billing change has been made.").font(.caption)
        }
        Section("Photography") {
          Text(
            "Academic Building: Laura McKenzie / Texas A&M University. Uploaded by Kailynn.Nelson on Wikimedia Commons. CC BY-SA 4.0. Resized and cropped for display."
          ).font(.caption)
          Link(
            "Photo source",
            destination: URL(
              string: "https://commons.wikimedia.org/wiki/File:Texas_A%26M_Academic_Building.jpg")!)
          Link(
            "CC BY-SA 4.0",
            destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
        }
        Section {
          Text("Independent student project. Not an official Texas A&M University app.").font(
            .caption)
        }
      }.navigationTitle("Your corner").toolbar { Button("Done") { dismiss() } }
    }
  }
}
