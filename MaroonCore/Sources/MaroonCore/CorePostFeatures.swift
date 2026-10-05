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
