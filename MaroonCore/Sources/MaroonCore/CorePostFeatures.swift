import Foundation

public struct PostPollOption: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var text: String
  public var votes: Int
  public init(id: String = UUID().uuidString, text: String, votes: Int = 0) {
    self.id = id; self.text = text; self.votes = votes
  }
}

public struct PostPoll: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var question: String
  public var options: [PostPollOption]
  public var endsAt: Date
  public var totalVotes: Int
  public var myOptionID: String?
  public init(id: String = UUID().uuidString, question: String, options: [PostPollOption], endsAt: Date, totalVotes: Int = 0, myOptionID: String? = nil) {
    self.id = id; self.question = question; self.options = options; self.endsAt = endsAt
    self.totalVotes = totalVotes; self.myOptionID = myOptionID
  }
  /// Fixture voting follows the same one-current-choice rule as the server.
  /// Selecting the same answer is idempotent; changing it moves one vote.
  @discardableResult public mutating func select(_ optionID: String, now: Date = .now) -> Bool {
    guard now < endsAt, let next = options.firstIndex(where: { $0.id == optionID }) else { return false }
    guard myOptionID != optionID else { return true }
    if let previous = options.firstIndex(where: { $0.id == myOptionID }) {
      options[previous].votes = max(0, options[previous].votes - 1)
    }
    options[next].votes += 1
    totalVotes = options.reduce(0) { $0 + $1.votes }
    myOptionID = optionID
    return true
  }
}

public struct PostPollDraft: Codable, Equatable, Sendable {
  public var question: String
  public var options: [String]
  public var durationHours: Int
  public init(question: String = "", options: [String] = ["", ""], durationHours: Int = 24) {
    self.question = question; self.options = options; self.durationHours = durationHours
  }
}

public struct ValidatedPostFeatures: Equatable, Sendable {
  public let text: String
  public let poll: PostPollDraft?
  public let linkURL: String?
  public let tags: [String]
}

public enum PostFeatureError: Error, LocalizedError, Equatable {
  case empty, textTooLong, invalidLink, invalidTags, invalidQuestion, invalidOptions, invalidDuration
  public var errorDescription: String? {
    switch self {
    case .empty: "Write something, add a link, or create a poll."
    case .textTooLong: "Keep your post within 1,000 characters."
    case .invalidLink: "Enter a web address using http or https, without a username or password (up to 2,048 characters)."
    case .invalidTags: "Add up to 5 tags using letters, numbers, or underscores, with 1–24 characters each."
    case .invalidQuestion: "Write a poll question with 1–180 characters."
    case .invalidOptions: "Add 2–4 different answers with 1–80 characters each."
    case .invalidDuration: "Choose a poll duration of 1, 3, or 7 days."
    }
  }
}

public enum PostFeatureRules {
  public static func normalizeLink(_ value: String?) throws -> String? {
    guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
    guard raw.count <= 2048, !raw.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }) else { throw PostFeatureError.invalidLink }
    let candidate = raw.contains("://") ? raw : "https://" + raw
    guard let components = URLComponents(string: candidate),
          let scheme = components.scheme?.lowercased(), ["https", "http"].contains(scheme),
          let host = components.host, !host.isEmpty,
          components.user == nil, components.password == nil,
          let url = components.url, url.absoluteString.count <= 2048 else { throw PostFeatureError.invalidLink }
    return url.absoluteString
  }
  public static func normalizeTags(_ values: [String]) throws -> [String] {
    var result: [String] = []
    for value in values {
      var tag = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      if tag.hasPrefix("#") { tag.removeFirst() }
      guard !tag.isEmpty, tag.count <= 24, tag.unicodeScalars.allSatisfy({ (97...122).contains($0.value) || (48...57).contains($0.value) || $0.value == 95 }) else { throw PostFeatureError.invalidTags }
      if !result.contains(tag) { result.append(tag) }
    }
    guard result.count <= 5 else { throw PostFeatureError.invalidTags }
    return result
  }
  public static func validate(text: String, poll: PostPollDraft? = nil, linkURL: String? = nil, tags: [String] = [], hasQuote: Bool = false) throws -> ValidatedPostFeatures {
    let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard body.count <= 1000 else { throw PostFeatureError.textTooLong }
    let link = try normalizeLink(linkURL)
    let cleanTags = try normalizeTags(tags)
    var cleanPoll: PostPollDraft?
    if let poll {
      let question = poll.question.trimmingCharacters(in: .whitespacesAndNewlines)
      let options = poll.options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      guard (1...180).contains(question.count) else { throw PostFeatureError.invalidQuestion }
      guard (2...4).contains(options.count), options.allSatisfy({ (1...80).contains($0.count) }), Set(options.map { $0.lowercased() }).count == options.count else { throw PostFeatureError.invalidOptions }
      guard [24, 72, 168].contains(poll.durationHours) else { throw PostFeatureError.invalidDuration }
      cleanPoll = PostPollDraft(question: question, options: options, durationHours: poll.durationHours)
    }
    guard !body.isEmpty || link != nil || cleanPoll != nil || hasQuote else { throw PostFeatureError.empty }
    return ValidatedPostFeatures(text: body, poll: cleanPoll, linkURL: link, tags: cleanTags)
  }
}

/// One topic a post can carry (`posts.topic`), as `topics.list` describes it. A post has at most one.
/// `recentCount` is the server's 7-day count of readable posts in the requested community.
public struct Topic: Identifiable, Codable, Hashable, Sendable {
  public var slug: String
  public var title: String
  public var emoji: String
  /// Text and underline tone, `#RRGGBB`.
  public var textHex: String
  /// Opaque pill fill on `surface`, `#RRGGBB`.
  public var fillHex: String
  public var order: Int
  public var active: Bool
  public var recentCount: Int?
  public var id: String { slug }
  public init(slug: String, title: String, emoji: String, textHex: String, fillHex: String, order: Int, active: Bool = true, recentCount: Int? = nil) {
    self.slug = slug; self.title = title; self.emoji = emoji; self.textHex = textHex; self.fillHex = fillHex
    self.order = order; self.active = active; self.recentCount = recentCount
  }
  enum CodingKeys: String, CodingKey {
    case slug, title, emoji, active
    case textHex = "text_hex", fillHex = "fill_hex", order = "sort_order", recentCount = "recent_count"
  }
  // `topics.list` lists active topics only, so `active` is absent there.
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    slug = try values.decode(String.self, forKey: .slug)
    title = try values.decode(String.self, forKey: .title)
    emoji = try values.decode(String.self, forKey: .emoji)
    textHex = try values.decode(String.self, forKey: .textHex)
    fillHex = try values.decode(String.self, forKey: .fillHex)
    order = try values.decode(Int.self, forKey: .order)
    active = try values.decodeIfPresent(Bool.self, forKey: .active) ?? true
    recentCount = try values.decodeIfPresent(Int.self, forKey: .recentCount)
  }
  /// The slug format the server enforces (`^[a-z0-9_]{1,24}$`).
  public static func isValidSlug(_ value: String) -> Bool {
    !value.isEmpty && value.count <= 24 && value.unicodeScalars.allSatisfy { (97...122).contains($0.value) || (48...57).contains($0.value) || $0.value == 95 }
  }
}

public enum TopicCatalog {
  /// The bundled catalog (all 14 seeded rows; the 6 reserve topics are inactive). It supplies the
  /// colours and emoji for a slug the server's list does not describe; it never makes topics available.
  public static let fallback: [Topic] = [
    Topic(slug: "academics", title: "Academics", emoji: "📚", textHex: "#93C5FD", fillHex: "#21304C", order: 1),
    Topic(slug: "aggie_life", title: "Aggie Life", emoji: "👍", textHex: "#FDA4AF", fillHex: "#431C29", order: 2),
    Topic(slug: "questions", title: "Questions", emoji: "❓", textHex: "#67E8F9", fillHex: "#173B45", order: 3),
    Topic(slug: "housing", title: "Housing", emoji: "🏠", textHex: "#5EEAD4", fillHex: "#1A3B3C", order: 4),
    Topic(slug: "sports", title: "Sports", emoji: "🏈", textHex: "#FDBA74", fillHex: "#472D1F", order: 5),
    Topic(slug: "relationships", title: "Relationships", emoji: "💘", textHex: "#F9A8D4", fillHex: "#452539", order: 6),
    Topic(slug: "confessions", title: "Confessions", emoji: "🤫", textHex: "#F0ABFC", fillHex: "#41244A", order: 7),
    Topic(slug: "memes", title: "Memes", emoji: "😂", textHex: "#FDE047", fillHex: "#443A1C", order: 8),
    Topic(slug: "food", title: "Food", emoji: "🌮", textHex: "#FCD34D", fillHex: "#47361D", order: 9, active: false),
    Topic(slug: "events", title: "Events", emoji: "🎉", textHex: "#C4B5FD", fillHex: "#31294C", order: 10, active: false),
    Topic(slug: "careers", title: "Careers", emoji: "💼", textHex: "#6EE7B7", fillHex: "#193B34", order: 11, active: false),
    Topic(slug: "greek_life", title: "Greek Life", emoji: "🏛️", textHex: "#A5B4FC", fillHex: "#292B4B", order: 12, active: false),
    Topic(slug: "mental_health", title: "Mental Health", emoji: "🫶", textHex: "#7DD3FC", fillHex: "#183749", order: 13, active: false),
    Topic(slug: "lost_found", title: "Lost & Found", emoji: "🔎", textHex: "#BEF264", fillHex: "#303F1F", order: 14, active: false),
  ]
  /// Topics with fewer posts than this over the last 7 days (in the current community) fold into "More".
  public static let foldThreshold = 5
  /// Topics whose composer shows the reminder about other students.
  public static let guardrailSlugs: Set<String> = ["confessions", "relationships"]
  public static let guardrailCopy = "Don't name, initial or picture other students."

  /// The server's active topics in catalog order (inactive or malformed rows dropped, first copy of a slug wins).
  public static func active(_ topics: [Topic]) -> [Topic] {
    var seen = Set<String>()
    return topics.filter { $0.active && Topic.isValidSlug($0.slug) && seen.insert($0.slug).inserted }
      .sorted { ($0.order, $0.slug) < ($1.order, $1.slug) }
  }
  /// How to draw a slug: the server's row, else the bundled row, else a neutral row titled from the slug.
  public static func display(_ slug: String, in catalog: [Topic]) -> Topic {
    if let topic = catalog.first(where: { $0.slug == slug }) ?? fallback.first(where: { $0.slug == slug }) { return topic }
    let title = slug.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    return Topic(slug: slug, title: title, emoji: "#", textHex: "#B6B0B5", fillHex: "#27272D", order: Int.max, active: false)
  }
  /// Splits the strip into shown tabs and the "More" menu. A topic without a count is shown; the
  /// selected topic stays a tab until the member leaves it, even when it is quiet.
  public static func fold(_ topics: [Topic], selected: String?, threshold: Int = foldThreshold) -> (shown: [Topic], more: [Topic]) {
    var shown: [Topic] = [], more: [Topic] = []
    for topic in active(topics) {
      if topic.slug == selected || (topic.recentCount ?? threshold) >= threshold { shown.append(topic) } else { more.append(topic) }
    }
    return (shown, more)
  }
  /// The composer's rule: a topic is required (and must be active) only while topics are available.
  public static func canPublish(topic: String?, topicsAvailable: Bool, catalog: [Topic]) -> Bool {
    guard topicsAvailable else { return true }
    guard let topic else { return false }
    return active(catalog).contains { $0.slug == topic }
  }
  public static func needsGuardrail(_ slug: String?) -> Bool { slug.map(guardrailSlugs.contains) ?? false }
}

/// Reasons the feed's report menu offers. "Wrong topic" is offered only for a post with a topic
/// while topics are available. The `report` action stores any 1–500 character reason.
public enum PostReportReason {
  public static let wrongTopic = "Wrong topic"
  public static func options(topicsAvailable: Bool, postHasTopic: Bool) -> [String] {
    var reasons = ["Harassment or bullying", "Hate or threats", "Sexual content", "Names or targets a student", "Spam"]
    if topicsAvailable && postHasTopic { reasons.append(wrongTopic) }
    reasons.append("Something else")
    return reasons
  }
}
