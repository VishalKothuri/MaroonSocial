import Foundation

public enum Community: String, Codable, CaseIterable, Identifiable {
  case campus = "Texas A&M"
  case freshmen = "Freshmen"
  case sophomores = "Sophomores"
  case juniors = "Juniors"
  case seniors = "Seniors"
  case graduates = "Graduates"
  case nsfw = "NSFW"
  public static var campusCommunities: [Community] { allCases.filter { $0 != .nsfw } }
  public var id: String { rawValue }
}
public struct Post: Identifiable, Codable, Equatable {
  public var id: String
  public var author: String
  public var anonymous: Bool
  public var community: Community
  public var text: String
  public var score: Int
  public var vote: Int
  public var comments: [Comment]
  public var created: Date
  public var saved: Bool
  public var acceptsDM: Bool
  public var media: MediaAttachment? = nil
  public var attachmentID: String? = nil
  public var poll: PostPoll? = nil
  public var linkURL: String? = nil
  public var tags: [String]? = nil
  public var deleted: Bool? = nil
  public var quote: PostQuote? = nil
  public var repostCount: Int = 0
  /// Every reply the server holds for this post; `comments` may carry only the newest ones.
  public var commentCount: Int? = nil
  /// The post's one topic slug (`topics.list`); nil for posts without one, for deleted posts
  /// and from servers that predate topics.
  public var topic: String? = nil
  /// Server time at which this copy was read. Merges keep the most recently read copy; the
  /// device cache does not persist it (anything fetched after a launch is newer than the cache).
  public var syncedAt: Date? = nil
  /// The organization byline of a post published under an organization's name; nil for member
  /// posts and from servers that do not project one.
  public var organization: PostOrganization? = nil
  public init(
    id: String = UUID().uuidString, author: String, anonymous: Bool = true,
    community: Community = .campus, text: String, score: Int = 0, comments: [Comment] = [],
    created: Date = .now, acceptsDM: Bool = false
  ) {
    self.id = id
    self.author = author
    self.anonymous = anonymous
    self.community = community
    self.text = text
    self.score = score
    self.vote = 0
    self.comments = comments
    self.created = created
    self.saved = false
    self.acceptsDM = acceptsDM
  }
  enum CodingKeys: String, CodingKey { case id, author, anonymous, community, text, score, vote, comments, created, saved, acceptsDM, media, attachmentID, poll, linkURL, tags, deleted, quote, repostCount, commentCount, topic, syncedAt, organization }
  // Cached feeds written before reposts existed carry neither key; synthesized
  // decoding would reject them because repostCount is not optional.
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    author = try values.decode(String.self, forKey: .author)
    anonymous = try values.decode(Bool.self, forKey: .anonymous)
    community = try values.decode(Community.self, forKey: .community)
    text = try values.decode(String.self, forKey: .text)
    score = try values.decode(Int.self, forKey: .score)
    vote = try values.decode(Int.self, forKey: .vote)
    comments = try values.decode([Comment].self, forKey: .comments)
    created = try values.decode(Date.self, forKey: .created)
    saved = try values.decode(Bool.self, forKey: .saved)
    acceptsDM = try values.decode(Bool.self, forKey: .acceptsDM)
    media = try values.decodeIfPresent(MediaAttachment.self, forKey: .media)
    attachmentID = try values.decodeIfPresent(String.self, forKey: .attachmentID)
    poll = try values.decodeIfPresent(PostPoll.self, forKey: .poll)
    linkURL = try values.decodeIfPresent(String.self, forKey: .linkURL)
    tags = try values.decodeIfPresent([String].self, forKey: .tags)
    deleted = try values.decodeIfPresent(Bool.self, forKey: .deleted)
    quote = try values.decodeIfPresent(PostQuote.self, forKey: .quote)
    repostCount = try values.decodeIfPresent(Int.self, forKey: .repostCount) ?? 0
    commentCount = try values.decodeIfPresent(Int.self, forKey: .commentCount)
    topic = try values.decodeIfPresent(String.self, forKey: .topic)
    syncedAt = try values.decodeIfPresent(Date.self, forKey: .syncedAt)
    // A malformed byline never costs the post.
    organization = (try? values.decodeIfPresent(PostOrganization.self, forKey: .organization)) ?? nil
  }
  public mutating func setVote(_ newValue: Int) {
    let next = newValue == vote ? 0 : max(-1, min(1, newValue))
    score += next - vote
    vote = next
  }
  public var displayName: String { anonymous ? "Anonymous" : "@\(author)" }
  /// The name a card shows: the organization's for an organization post, else `displayName`.
  public var bylineName: String { organization.map(\.name) ?? displayName }
  /// An organization post whose organization is verified carries the verified seal.
  public var showsVerifiedSeal: Bool { deleted != true && organization?.verified == true }
}
/// The organization a post (or a quoted post) was published under.
public struct PostOrganization: Codable, Equatable, Sendable {
  public var id: String
  public var name: String
  public var verified: Bool
  public init(id: String, name: String, verified: Bool) { self.id = id; self.name = name; self.verified = verified }
  enum CodingKeys: String, CodingKey { case id, name, verified }
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    name = try values.decode(String.self, forKey: .name)
    verified = try values.decodeIfPresent(Bool.self, forKey: .verified) ?? false
  }
}
/// The one level of a quoted post that a repost carries. Only the projected display
/// name travels, never the author's identity, karma or vote; an unavailable quote keeps
/// just the id so the reposting post still stands when its source is gone.
public struct PostQuote: Codable, Equatable, Identifiable {
  public var id: String
  public var unavailable: Bool
  public var author: String? = nil
  public var anonymous: Bool? = nil
  public var community: Community? = nil
  public var text: String? = nil
  public var created: Date? = nil
  public var attachmentID: String? = nil
  /// The quoted post itself quotes another post (only one level is projected).
  public var quotes: Bool? = nil
  /// The quoted post's organization byline, when it was published under one.
  public var organization: PostOrganization? = nil
  public init(id: String, unavailable: Bool = false, author: String? = nil, anonymous: Bool? = nil, community: Community? = nil, text: String? = nil, created: Date? = nil, attachmentID: String? = nil, quotes: Bool? = nil, organization: PostOrganization? = nil) {
    self.id = id; self.unavailable = unavailable; self.author = author; self.anonymous = anonymous
    self.community = community; self.text = text; self.created = created; self.attachmentID = attachmentID
    self.quotes = quotes; self.organization = organization
  }
  enum CodingKeys: String, CodingKey { case id, unavailable, author, anonymous, community, text, created, attachmentID, quotes, organization }
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    unavailable = try values.decode(Bool.self, forKey: .unavailable)
    author = try values.decodeIfPresent(String.self, forKey: .author)
    anonymous = try values.decodeIfPresent(Bool.self, forKey: .anonymous)
    community = try values.decodeIfPresent(Community.self, forKey: .community)
    text = try values.decodeIfPresent(String.self, forKey: .text)
    created = try values.decodeIfPresent(Date.self, forKey: .created)
    attachmentID = try values.decodeIfPresent(String.self, forKey: .attachmentID)
    quotes = try values.decodeIfPresent(Bool.self, forKey: .quotes)
    organization = (try? values.decodeIfPresent(PostOrganization.self, forKey: .organization)) ?? nil
  }
  /// The feed's own copy of a post, reduced the way the server's quote_view projects it.
  public init(quoting post: Post) {
    self.init(id: post.id, unavailable: post.deleted == true, author: post.anonymous ? "Anonymous" : post.author, anonymous: post.anonymous,
      community: post.community, text: String(post.text.prefix(280)), created: post.created, attachmentID: post.attachmentID,
      quotes: post.quote != nil, organization: post.organization)
    if unavailable { author = nil; anonymous = nil; community = nil; text = nil; created = nil; attachmentID = nil; quotes = nil; organization = nil }
  }
  public var displayName: String { organization?.name ?? (anonymous == true ? "Anonymous" : "@\(author ?? "")") }
  public var showsVerifiedSeal: Bool { !unavailable && organization?.verified == true }
}
public struct Comment: Identifiable, Codable, Equatable {
  public var id = UUID().uuidString
  public var author: String
  public var text: String
  public var anonymous: Bool
  public var created = Date.now
  public var isOP: Bool? = nil
  public var deleted: Bool? = nil
  public var parentID: String? = nil
  public var score = 0
  public var vote = 0
  public init(author: String, text: String, anonymous: Bool = true, parentID: String? = nil) {
    self.author = author
    self.text = text
    self.anonymous = anonymous
    self.parentID = parentID
  }
  enum CodingKeys: String, CodingKey { case id, author, text, anonymous, created, isOP, deleted, parentID, score, vote }
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    author = try values.decode(String.self, forKey: .author)
    text = try values.decode(String.self, forKey: .text)
    anonymous = try values.decode(Bool.self, forKey: .anonymous)
    created = try values.decode(Date.self, forKey: .created)
    isOP = try values.decodeIfPresent(Bool.self, forKey: .isOP)
    deleted = try values.decodeIfPresent(Bool.self, forKey: .deleted)
    parentID = try values.decodeIfPresent(String.self, forKey: .parentID)
    score = try values.decodeIfPresent(Int.self, forKey: .score) ?? 0
    vote = try values.decodeIfPresent(Int.self, forKey: .vote) ?? 0
  }
  public mutating func setVote(_ newValue: Int) {
    let next = newValue == vote ? 0 : max(-1, min(1, newValue))
    score += next - vote
    vote = next
  }
}
public struct Course: Identifiable, Codable, Equatable, Sendable {
  public var id: String { "\(code)-\(term)" }
  public var code: String
  public var title: String
  public var term: String
  public var icon: String
  public init(
    _ code: String, _ title: String, term: String = "Fall 2026", icon: String = "book.closed"
  ) {
    self.code = code
    self.title = title
    self.term = term
    self.icon = icon
  }
  public static let catalog = [
    Course("CHEM 107", "General Chemistry for Engineering", icon: "flask"),
    Course("MATH 151", "Engineering Mathematics I", icon: "function"),
    Course("ENGL 104", "Composition and Rhetoric", icon: "text.book.closed"),
    Course(
      "CSCE 120", "Program Design and Concepts", icon: "chevron.left.forwardslash.chevron.right"),
    Course("PHYS 206", "Newtonian Mechanics", icon: "atom"),
    Course("BIOL 111", "Introductory Biology I", icon: "leaf"),
  ]
}
public struct KlipyReference: Codable, Equatable, Sendable {
  public var provider = "klipy"
  public var id: String
  public var slug: String
  public var title: String
  public var category: String
  public var kind: String
  public var mime: String
  public var url: String
  public var previewURL: String
  public var size: Int
  public init(id: String, slug: String, title: String, category: String, kind: String, mime: String, url: String, previewURL: String, size: Int) {
    self.id = id; self.slug = slug; self.title = title; self.category = category; self.kind = kind
    self.mime = mime; self.url = url; self.previewURL = previewURL; self.size = size
  }
}
public struct MediaAttachment: Identifiable, Codable, Equatable, Sendable {
  public enum Kind: String, Codable, Sendable { case image, gif, video }
  public var id = UUID().uuidString
  public var kind: Kind
  public var data: Data
  public var klipy: KlipyReference? = nil
  public var thumbnail: Data? = nil
  public var duration: Double? = nil
  public init(klipy: KlipyReference) {
    self.klipy = klipy; self.kind = klipy.kind == "gif" ? .gif : .image; self.data = Data()
  }
  public init(kind: Kind, data: Data) {
    self.kind = kind
    self.data = data
  }
}
public enum MessageValidation: Error, LocalizedError {
  case empty, tooManyAttachments, tooLarge
  public var errorDescription: String? {
    switch self {
    case .empty: return "Write a message or add a photo, GIF, or video."
    case .tooManyAttachments: return "One attachment per message."
    case .tooLarge: return "Choose media smaller than 5 MB."
    }
  }
  public static func validate(text: String, media: [MediaAttachment]) throws {
    guard media.count <= 1 else { throw tooManyAttachments }
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !media.isEmpty else {
      throw empty
    }
    guard media.allSatisfy({ ($0.klipy?.size ?? $0.data.count) <= 5_000_000 }) else { throw tooLarge }
  }
}
public struct Message: Identifiable, Codable, Equatable {
  public var id = UUID().uuidString
  public var author: String
  public var text: String
  public var media: MediaAttachment?
  public var game: String?
  public var gameSessionID: String? = nil
  public var avatar: String? = nil
  public var memberKey: String? = nil
  public var attachmentID: String? = nil
  public var replyTo: String? = nil
  public var reactions: [String: Int]? = nil
  public var myReactions: [String]? = nil
  public var deleted: Bool? = nil
  public var sequence: Int? = nil
  public var created = Date.now
  public init(author: String, text: String, media: MediaAttachment? = nil, game: String? = nil) {
    self.author = author
    self.text = text
    self.media = media
    self.game = game
  }
}
public struct Conversation: Identifiable, Codable, Equatable {
  public var id: String
  public var title: String
  public var subtitle: String
  public var messages: [Message]
  public var request: Bool
  public var anonymous: Bool
  public init(
    id: String = UUID().uuidString, title: String, subtitle: String = "", messages: [Message] = [],
    request: Bool = false, anonymous: Bool = false
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.messages = messages
    self.request = request
    self.anonymous = anonymous
  }
}
public enum ActivityKind: String, Codable, CaseIterable, Identifiable {
  case hangout = "Hangouts"
  case study = "Study"
  case recreation = "Rec"
  case gaming = "Gaming"
  case organization = "Organizations"
  public var id: String { rawValue }
  public var icon: String {
    switch self {
    case .hangout: return "cup.and.saucer"
    case .study: return "book"
    case .recreation: return "basketball"
    case .gaming: return "gamecontroller"
    case .organization: return "person.3"
    }
  }
}
public struct Activity: Identifiable, Codable, Equatable {
  public var id = UUID().uuidString
  public var title: String
  public var kind: ActivityKind
  public var host: String
  public var place: String
  public var starts: Date
  public var capacity: Int
  public var participants: [String]
  public var details: String
  public var course: String?
  public var cancelled = false
  public var participantCount: Int? = nil
  public var waitlisted: Bool? = nil
  public var membershipStatus: String? = nil
  public var joinRequests: [String]? = nil
  public var approvalRequired: Bool? = nil
  public init(
    title: String, kind: ActivityKind, host: String, place: String, starts: Date, capacity: Int,
    details: String, course: String? = nil
  ) {
    self.title = title
    self.kind = kind
    self.host = host
    self.place = place
    self.starts = starts
    self.capacity = capacity
    self.participants = [host]
    self.details = details
    self.course = course
  }
  public mutating func join(_ username: String) throws {
    guard !cancelled && starts > Date.now else { throw ActivityError.unavailable }
    guard !participants.contains(username) else { return }
    guard participants.count < capacity else { throw ActivityError.full }
    participants.append(username)
  }
}
public enum ActivityError: Error, LocalizedError {
  case full, unavailable
  public var errorDescription: String? {
    self == .full ? "This activity is full." : "This activity is no longer available."
  }
}
public struct CampusEvent: Identifiable, Codable, Equatable {
  public var id: String
  public var title: String
  public var category: String
  public var starts: Date
  public var ends: Date?
  public var allDay: Bool
  public var location: String
  public var details: String
  public var url: String
  public var imageURL: String?
  public var source: String
  public var fetchedAt: Date
  public var cancelled: Bool
  public init(
    id: String, title: String, category: String, starts: Date, ends: Date? = nil,
    allDay: Bool = false, location: String = "", details: String = "", url: String,
    imageURL: String? = nil, source: String, fetchedAt: Date = .now, cancelled: Bool = false
  ) {
    self.id = id
    self.title = title
    self.category = category
    self.starts = starts
    self.ends = ends
    self.allDay = allDay
    self.location = location
    self.details = details
    self.url = url
    self.imageURL = imageURL
    self.source = source
    self.fetchedAt = fetchedAt
    self.cancelled = cancelled
  }
  public var chatOpenDate: Date { starts.addingTimeInterval(-1800) }
  public func canOpenSportsChat(at now: Date) -> Bool {
    !cancelled && !allDay && category == "Sports" && now >= chatOpenDate
      && now < (ends ?? starts.addingTimeInterval(6 * 3600))
  }
}
public struct BusRoute: Identifiable, Codable, Equatable {
  public var id: String
  public var name: String
  public var color: String
  public var stops: [BusStop]
  public init(id: String, name: String, color: String = "500000", stops: [BusStop] = []) {
    self.id = id
    self.name = name
    self.color = color
    self.stops = stops
  }
}
public struct BusStop: Identifiable, Codable, Equatable {
  public var id: String
  public var name: String
  public var latitude: Double
  public var longitude: Double
  public init(id: String, name: String, latitude: Double, longitude: Double) {
    self.id = id
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
  }
}
public struct DiningLocation: Identifiable, Codable, Equatable {
  public var id: String
  public var name: String
  public var hours: String
  public var menus: [String]
  public var date: String
  public var sourceURL: String
  public init(
    id: String, name: String, hours: String, menus: [String], date: String, sourceURL: String
  ) {
    self.id = id
    self.name = name
    self.hours = hours
    self.menus = menus
    self.date = date
    self.sourceURL = sourceURL
  }
}
public struct DataStatus: Codable, Equatable {
  public var source: String
  public var fetchedAt: Date?
  public var error: String?
  public init(source: String, fetchedAt: Date? = nil, error: String? = nil) {
    self.source = source
    self.fetchedAt = fetchedAt
    self.error = error
  }
}
public enum Eligibility {
  public static func allows(_ email: String, domains: Set<String> = ["tamu.edu"]) -> Bool {
    let value = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let parts = value.split(separator: "@", omittingEmptySubsequences: false)
    return parts.count == 2 && !parts[0].isEmpty && !value.contains(where: { $0.isWhitespace })
      && domains.contains(String(parts[1]))
  }
}
