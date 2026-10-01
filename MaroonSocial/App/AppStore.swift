import MaroonCore
import SwiftUI

struct LocalState: Codable {
  var username = ""
  var onboarded = false
  var adult = false
  var posts: [Post] = []
  var courses: [Course] = []
  var conversations: [Conversation] = []
  var activities: [Activity] = []
  var hiddenPosts: Set<String> = []
  var savedEvents: Set<String> = []
  var reports: [String] = []
}

@Observable @MainActor final class AppStore {
  var state = LocalState()
  var notice: String?
  var tab = 0
  let campus = CampusService()
  private var file: URL { URL.documentsDirectory.appending(path: "preview-state.json") }
  init() {
    if ProcessInfo.processInfo.arguments.contains("--uitesting") {
      try? FileManager.default.removeItem(at: file)
    }
    if let data = try? Data(contentsOf: file),
      let saved = try? JSONDecoder().decode(LocalState.self, from: data)
    {
      state = saved
    }
    if state.posts.isEmpty && !state.onboarded { seed() }
  }
  func save() {
    do {
      try JSONEncoder().encode(state).write(
        to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
    } catch { notice = "Your changes could not be saved on this device." }
  }
  func seed() {
    state.posts = [
      Post(
        author: "demo-ag", text: "The walk to class is somehow uphill in both directions.",
        score: 124,
        comments: [Comment(author: "demo-rev", text: "Especially when you're already late.")]),
      Post(
        author: "demo-espresso", anonymous: false,
        text: "Unofficial campus rule: getting coffee counts as being productive.", score: 86,
        acceptsDM: true),
      Post(
        author: "demo-chem",
        text: "CHEM 107 people: study room, whiteboard, and a very unreasonable amount of snacks?",
        score: 42),
      Post(
        author: "demo-night", community: .nsfw,
        text: "How do you set boundaries with a roommate without making it weird?", score: 18),
    ]
    state.activities = [
      Activity(
        title: "Coffee, then absolutely no plans", kind: .hangout, host: "demo-espresso",
        place: "Memorial Student Center", starts: .now.addingTimeInterval(7200), capacity: 6,
        details:
          "A sample hangout. Pick a public spot, bring a friend, and stay as long as you like."),
      Activity(
        title: "One more pickup game", kind: .recreation, host: "demo-hoops",
        place: "Student Rec Center", starts: .now.addingTimeInterval(10800), capacity: 10,
        details: "Sample basketball plan. All skill levels welcome."),
      Activity(
        title: "CHEM 107 • whiteboard session", kind: .study, host: "demo-chem",
        place: "Evans Library", starts: .now.addingTimeInterval(86400), capacity: 5,
        details: "Practice problems and comparing notes.", course: "CHEM 107"),
      Activity(
        title: "Mario Kart & questionable driving", kind: .gaming, host: "demo-player",
        place: "MSC game area", starts: .now.addingTimeInterval(90000), capacity: 8,
        details: "Sample gaming hangout. Bring your own controller."),
    ]
    state.conversations = [
      Conversation(
        id: "demo-request", title: "Anonymous • coffee post", subtitle: "Message request · sample",
        messages: [Message(author: "Post author", text: "Any good coffee spots near campus?")],
        request: true, anonymous: true)
    ]
  }
  func enter(username: String) {
    state.username = username.lowercased()
    state.onboarded = true
    state.adult = true
    save()
  }
  func vote(_ id: String, _ value: Int) {
    guard let i = state.posts.firstIndex(where: { $0.id == id }) else { return }
    state.posts[i].setVote(value)
    save()
  }
  func toggleSave(_ id: String) {
    guard let i = state.posts.firstIndex(where: { $0.id == id }) else { return }
    state.posts[i].saved.toggle()
    save()
  }
  func joinCourse(_ course: Course) {
    guard !state.courses.contains(course) else { return }
    state.courses.append(course)
    state.conversations.append(
      Conversation(
        id: course.id, title: course.code, subtitle: "\(course.term) · one course, one room"))
    save()
  }
  func joinActivity(_ id: String) {
    guard let i = state.activities.firstIndex(where: { $0.id == id }) else { return }
    do {
      try state.activities[i].join(state.username)
      let a = state.activities[i]
      if !state.conversations.contains(where: { $0.id == id }) {
        state.conversations.append(Conversation(id: id, title: a.title, subtitle: a.kind.rawValue))
      }
      save()
    } catch { notice = error.localizedDescription }
  }
  func send(_ id: String, text: String, media: MediaAttachment? = nil, game: String? = nil) {
    do {
      try MessageValidation.validate(text: text, media: media.map { [$0] } ?? [])
      guard let i = state.conversations.firstIndex(where: { $0.id == id }),
        !state.conversations[i].request
      else { return }
      state.conversations[i].messages.append(
        Message(author: state.username, text: text, media: media, game: game))
      save()
    } catch { notice = error.localizedDescription }
  }
  func report(_ id: String, reason: String) {
    state.reports.append("\(id): \(reason)")
    state.hiddenPosts.insert(id)
    save()
    notice = "Hidden on this device. This preview does not send reports to moderators."
  }
}
