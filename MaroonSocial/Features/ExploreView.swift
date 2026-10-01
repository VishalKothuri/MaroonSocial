import MaroonCore
import SwiftUI

struct ExploreView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        SectionHeading(title: "Get out there.", eyebrow: "More than a group chat")
        NavigationLink {
          TagView()
        } label: {
          ZStack(alignment: .bottomLeading) {
            Palette.ink
            Circle().stroke(Palette.lime.opacity(0.12), lineWidth: 35).frame(
              width: 240, height: 240
            ).offset(x: 180, y: -30)
            Image(systemName: "location.north.circle").font(.system(size: 110, weight: .ultraLight))
              .foregroundStyle(Palette.lime).frame(maxWidth: .infinity, alignment: .trailing)
              .padding(20)
            VStack(alignment: .leading, spacing: 10) {
              Text("CAMPUS TAG").font(.system(size: 10, weight: .bold)).tracking(3).foregroundStyle(
                Palette.lime)
              Text("Catch you\non campus.").font(.system(size: 35, weight: .bold, design: .serif))
                .foregroundStyle(.white)
              Label("Open the lobby", systemImage: "arrow.up.right").font(.caption.bold())
                .foregroundStyle(.white)
            }.padding(24)
          }.frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 26))
        }.buttonStyle(.plain)
        Text("Find your people").font(.title3.bold())
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
          ForEach(ActivityKind.allCases) { kind in
            NavigationLink {
              ActivityListView(filter: kind)
            } label: {
              Card {
                VStack(alignment: .leading, spacing: 20) {
                  Image(systemName: kind.icon).font(.title2).foregroundStyle(Palette.maroon)
                  HStack {
                    Text(kind.rawValue).font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption)
                  }
                }
              }
            }.buttonStyle(.plain)
          }
        }
        HStack {
          Text("Game room").font(.title3.bold())
          Spacer()
          Text("PASS & PLAY").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(
            .secondary)
        }
        ForEach(["8 Ball", "Chess", "Cup Pong"], id: \.self) { game in
          NavigationLink {
            GameView(kind: game)
          } label: {
            Card {
              HStack {
                Image(
                  systemName: game == "Chess"
                    ? "crown.fill" : game == "8 Ball" ? "8.circle.fill" : "cup.and.saucer.fill"
                ).font(.system(size: 35)).foregroundStyle(Palette.maroon)
                VStack(alignment: .leading, spacing: 4) {
                  Text(game).font(.headline)
                  Text(
                    game == "Chess"
                      ? "A little strategy. A lot of rivalry." : "Your next study break."
                  ).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
              }
            }
          }.buttonStyle(.plain)
        }
        NavigationLink {
          RandomMatchView()
        } label: {
          Card {
            HStack {
              Image(systemName: "shuffle").font(.title2)
              VStack(alignment: .leading, spacing: 5) {
                Text("Meet a random Aggie").font(.headline)
                Text("Text · voice · video").font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              Image(systemName: "arrow.up.right")
            }
          }
        }.buttonStyle(.plain)
      }.padding(20)
    }.appBackground().navigationTitle("Explore").navigationBarTitleDisplayMode(.inline)
  }
}
struct ActivityListView: View {
  @Environment(AppStore.self) private var store
  let filter: ActivityKind
  @State private var create = false
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        SectionHeading(
          title: filter == .organization ? "Find your circle." : "Good plans.\nBetter company.",
          eyebrow: filter.rawValue)
        if filter == .organization {
          Card {
            VStack(alignment: .leading, spacing: 12) {
              Label("Verified organizations only", systemImage: "checkmark.seal").font(.headline)
              Text(
                "Organizations publish under their public name. Their student administrators stay private."
              ).font(.subheadline).foregroundStyle(.secondary)
              Text("Organization verification opens with enrollment.").font(.caption)
            }
          }
        }
        ForEach(store.state.activities.filter { $0.kind == filter && !$0.cancelled }) { a in
          NavigationLink {
            ActivityDetailView(id: a.id)
          } label: {
            ActivityCard(activity: a)
          }.buttonStyle(.plain)
        }
        if store.state.activities.filter({ $0.kind == filter }).isEmpty {
          EmptyCard(
            icon: filter.icon, title: "Room for something new",
            detail: filter == .organization
              ? "No verified organizations have published yet." : "Start a plan and make it happen."
          )
        }
      }.padding(20)
    }.appBackground().navigationTitle(filter.rawValue).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if filter != .organization { Button("Create", systemImage: "plus") { create = true } }
      }.sheet(isPresented: $create) { CreateActivityView(kind: filter) }
  }
}
struct ActivityCard: View {
  let activity: Activity
  var body: some View {
    Card {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Pill(text: activity.kind.rawValue, icon: activity.kind.icon)
          Spacer()
          Text("\(activity.participants.count)/\(activity.capacity)").font(.caption)
            .foregroundStyle(.secondary)
        }
        Text(activity.title).font(.system(size: 23, weight: .bold, design: .serif))
        Label(activity.place, systemImage: "mappin").font(.caption)
        HStack {
          Text(activity.starts, format: .dateTime.weekday(.wide).hour().minute())
          Spacer()
          Text("@\(activity.host)")
        }.font(.caption).foregroundStyle(.secondary)
      }
    }
  }
}
struct ActivityDetailView: View {
  @Environment(AppStore.self) private var store
  let id: String
  var activity: Activity? { store.state.activities.first { $0.id == id } }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        if let a = activity {
          ActivityCard(activity: a)
          Text(a.details).lineSpacing(5)
          Label("Meet in a public place. You choose what to share.", systemImage: "hand.raised")
            .font(.caption).foregroundStyle(.secondary)
          Text("Who’s going").font(.headline)
          ForEach(a.participants, id: \.self) { Text("@\($0)") }
          if a.cancelled {
            Label("This activity was cancelled", systemImage: "calendar.badge.minus")
              .foregroundStyle(.secondary)
          } else if a.participants.contains(store.state.username) {
            NavigationLink {
              ChatView(id: a.id)
            } label: {
              Label("Open group chat", systemImage: "bubble.left.and.bubble.right")
            }.buttonStyle(PrimaryButton())
            Button(
              a.host == store.state.username ? "Cancel activity" : "Leave activity",
              role: .destructive
            ) {
              if let i = store.state.activities.firstIndex(where: { $0.id == id }) {
                if a.host == store.state.username {
                  store.state.activities[i].cancelled = true
                } else {
                  store.state.activities[i].participants.removeAll { $0 == store.state.username }
                }
                store.state.conversations.removeAll { $0.id == id }
                store.save()
              }
            }
          } else {
            Button(a.participants.count >= a.capacity ? "This plan is full" : "I’m in") {
              store.joinActivity(id)
            }.buttonStyle(PrimaryButton()).disabled(
              a.participants.count >= a.capacity || a.cancelled)
          }
        }
      }.padding(22)
    }.appBackground().navigationTitle("The plan").navigationBarTitleDisplayMode(.inline)
  }
}
struct CreateActivityView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let kind: ActivityKind
  @State private var title = ""
  @State private var place = ""
  @State private var details = ""
  @State private var starts = Date.now.addingTimeInterval(3600)
  @State private var capacity = 6
  @State private var course = ""
  var body: some View {
    NavigationStack {
      Form {
        Section("The plan") {
          TextField("Give it a name", text: $title)
          TextField("Public meeting place", text: $place)
          DatePicker(
            "When", selection: $starts, in: Date.now...,
            displayedComponents: [.date, .hourAndMinute])
          Stepper("\(capacity) spots", value: $capacity, in: 2...30)
        }
        if kind == .study {
          Section("Course") {
            Picker("Class", selection: $course) {
              Text("Any class").tag("")
              ForEach(store.state.courses) { Text($0.code).tag($0.code) }
            }
          }
        }
        Section("Details") { TextEditor(text: $details).frame(height: 100) }
        Section { Text("Hosted as @\(store.state.username)").font(.caption) }
      }.navigationTitle("New \(kind.rawValue.lowercased())").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Create") {
              let a = Activity(
                title: title, kind: kind, host: store.state.username, place: place, starts: starts,
                capacity: capacity, details: details, course: course.isEmpty ? nil : course)
              store.state.activities.insert(a, at: 0)
              store.state.conversations.append(
                Conversation(id: a.id, title: a.title, subtitle: kind.rawValue))
              store.save()
              dismiss()
            }.disabled(
              title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || title.count > 100 || details.count > 2000
            ).accessibilityIdentifier("publishActivity")
          }
        }
    }
  }
}
struct RandomMatchView: View {
  @State private var mode = "Text"
  var body: some View {
    VStack(spacing: 28) {
      Spacer()
      Image(systemName: "shuffle.circle.fill").font(.system(size: 90, weight: .light))
        .foregroundStyle(Palette.maroon)
      SectionHeading(title: "One campus.\nSomeone new.", eyebrow: "Random matching")
      Text(
        "Meet another verified Aggie. Leave anytime, and report or block from every conversation."
      ).foregroundStyle(.secondary)
      Picker("Conversation", selection: $mode) {
        ForEach(["Text", "Voice", "Video"], id: \.self) { Text($0) }
      }.pickerStyle(.segmented)
      Card {
        Label(
          "Matching opens after student enrollment and moderation are connected.",
          systemImage: "lock"
        ).font(.subheadline)
      }
      Text(
        "Video and voice need WebRTC signaling and a TURN relay. The distribution path for random chat is still under review."
      ).font(.caption).foregroundStyle(.secondary)
      Spacer()
    }.padding(25).appBackground().navigationTitle("Meet an Aggie").navigationBarTitleDisplayMode(
      .inline)
  }
}
