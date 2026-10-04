import Foundation
import MaroonCore
import Observation

struct CatalogCourse: Codable, Identifiable, Equatable {
  let code: String
  let title: String
  let levels: [String]
  let sourceURL: URL
  var id: String { code }
  var subject: String { String(code.prefix { $0 != " " }) }
  var displayTitle: String { title.isEmpty ? "View the official catalog for details" : title }
  func course(term: String) -> Course { Course(code, title.isEmpty ? code : title, term: term, icon: "book.closed.fill") }
}
struct CourseCatalog: Codable {
  let edition: String
  let fetchedAt: String
  let sourcePages: Int
  let courses: [CatalogCourse]
  static let bundled: CourseCatalog? = {
    guard let url = Bundle.main.url(forResource: "CourseCatalog", withExtension: "json"),
      let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(CourseCatalog.self, from: data)
  }()
  func search(_ query: String, subject: String = "All", level: String = "All", counts: [String: Int] = [:]) -> [CatalogCourse] {
    let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
    let compact = query.uppercased().filter { !$0.isWhitespace }
    return courses.filter { course in
      (subject == "All" || course.subject == subject) && (level == "All" || course.levels.contains(level)) &&
      (words.isEmpty || course.code.replacingOccurrences(of: " ", with: "").contains(compact) || words.allSatisfy { "\(course.code) \(course.title)".localizedCaseInsensitiveContains($0) })
    }.sorted {
      let a = counts[$0.code, default: 0], b = counts[$1.code, default: 0]
      return a == b ? $0.code < $1.code : a > b
    }
  }
  static func terms(now: Date = .now) -> [String] {
    CourseTermSchedule.bundled.slots(now: now).map(\.id)
  }
}

struct CourseTerm: Codable, Identifiable, Equatable {
  enum Status: Equatable { case locked, open, closed, purged }
  let id: String
  let season: String
  let year: Int
  let opensAt: Date
  let closesAt: Date?
  let purgeAt: Date?
  let endsOn: String?
  let sourceURL: URL
  let sourceSection: String?
  let endBasis: String
  let verified: Bool

  func status(at now: Date) -> Status {
    guard verified, let closesAt, let purgeAt else { return .locked }
    if now >= purgeAt { return .purged }
    if now >= closesAt { return .closed }
    return now >= opensAt ? .open : .locked
  }
  var openingLabel: String { "Opens " + Self.displayDate(opensAt) }
  var closingLabel: String {
    guard let closesAt else { return "Calendar dates pending" }
    return (endBasis == "last_final_exam" ? "Closes after finals on " : "Closes on ") + Self.displayDate(closesAt.addingTimeInterval(-1))
  }
  static func displayDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = CourseTermSchedule.calendar.timeZone
    formatter.dateFormat = "MMM d, yyyy"
    return formatter.string(from: date)
  }
  static func placeholder(season: String, year: Int) -> CourseTerm {
    CourseTerm(id: "\(season) \(year)", season: season, year: year,
      opensAt: CourseTermSchedule.opening(season: season, year: year), closesAt: nil, purgeAt: nil,
      endsOn: nil, sourceURL: URL(string: "https://catalog.tamu.edu/undergraduate/academic-calendar/")!,
      sourceSection: nil, endBasis: "unpublished", verified: false)
  }
}

struct CourseTermSchedule: Codable, Equatable {
  let schemaVersion: Int
  let timeZone: String
  let verifiedAt: String
  let terms: [CourseTerm]
  var serverNow: Date?
  static var calendar: Calendar {
    var result = Calendar(identifier: .gregorian)
    result.timeZone = TimeZone(identifier: "America/Chicago")!
    return result
  }
  static let bundled: CourseTermSchedule = {
    guard let url = Bundle.main.url(forResource: "CourseTerms", withExtension: "json"),
      let data = try? Data(contentsOf: url), let schedule = try? decode(data) else {
      return CourseTermSchedule(schemaVersion: 1, timeZone: "America/Chicago", verifiedAt: "", terms: [])
    }
    return schedule
  }()
  static func opening(season: String, year: Int) -> Date {
    calendar.date(from: DateComponents(year: season == "Spring" ? year - 1 : year,
      month: season == "Spring" ? 12 : season == "Summer" ? 5 : 8, day: 1))!
  }
  func term(id: String) -> CourseTerm? { terms.first { $0.id == id } }
  /// Each season keeps its own slot and advances only after that term has closed.
  func slots(now: Date) -> [CourseTerm] {
    let year = Self.calendar.component(.year, from: now)
    return ["Spring", "Summer", "Fall"].map { season in
      let current = term(id: "\(season) \(year)") ?? .placeholder(season: season, year: year)
      guard let closesAt = current.closesAt, now >= closesAt else { return current }
      return term(id: "\(season) \(year + 1)") ?? .placeholder(season: season, year: year + 1)
    }.sorted { $0.opensAt < $1.opensAt }
  }
  static func decode(_ data: Data) throws -> CourseTermSchedule {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let value = try decoder.singleValueContainer().decode(String.self)
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let result = formatter.date(from: value) { return result }
      formatter.formatOptions = [.withInternetDateTime]
      guard let result = formatter.date(from: value) else {
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid semester date"))
      }
      return result
    }
    let result = try decoder.decode(Self.self, from: data)
    guard result.schemaVersion == 1, result.timeZone == "America/Chicago",
      Set(result.terms.map(\.id)).count == result.terms.count,
      result.terms.allSatisfy({ term in
        guard ["Spring", "Summer", "Fall"].contains(term.season), (2000...2200).contains(term.year),
          term.id == "\(term.season) \(term.year)",
          term.opensAt == opening(season: term.season, year: term.year) else { return false }
        if !term.verified { return term.closesAt == nil && term.purgeAt == nil }
        guard let closes = term.closesAt, let purge = term.purgeAt, closes > term.opensAt,
          calendar.startOfDay(for: closes) == closes, term.endsOn != nil,
          ["catalog.tamu.edu", "registrar.tamu.edu"].contains(term.sourceURL.host ?? "") else { return false }
        return calendar.date(byAdding: .month, value: 1, to: closes) == purge
      }) else { throw CocoaError(.coderReadCorrupt) }
    return result
  }
}

@Observable @MainActor final class CourseTermsService {
  typealias Transport = @MainActor () async throws -> Data
  private let transport: Transport
  private let uptime: () -> TimeInterval
  private let cacheURL: URL?
  private var anchor: (date: Date, uptime: TimeInterval)
  @ObservationIgnored nonisolated(unsafe) private var clockTask: Task<Void, Never>?
  private var generation = 0
  private var lastPersistedStatus: [String: CourseTerm.Status] = [:]
  private(set) var schedule: CourseTermSchedule
  private(set) var now: Date
  private(set) var error: String?
  private(set) var busy = false
  var onChange: (() -> Void)?

  init(schedule: CourseTermSchedule = .bundled, now: Date = .now, cacheURL: URL? = nil,
       uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
       automaticClock: Bool = true, transport: @escaping Transport) {
    let cached = cacheURL.flatMap { try? Data(contentsOf: $0) }.flatMap { try? CourseTermSchedule.decode($0) }
    self.schedule = cached ?? schedule
    // A previously observed expiry cannot reopen merely because the wall clock moves backwards offline.
    let start = max(now, cached?.serverNow ?? .distantPast)
    self.now = start; anchor = (start, uptime())
    self.uptime = uptime; self.cacheURL = cacheURL; self.transport = transport
    if automaticClock {
      clockTask = Task { [weak self] in
        while !Task.isCancelled {
          guard let delay = self?.advanceClock() else { return }
          do { try await Task.sleep(for: .seconds(delay)) } catch { return }
        }
      }
    }
  }
  convenience init(social: SocialService, fixtureMode: Bool) {
    let cache = fixtureMode ? nil : URL.applicationSupportDirectory.appending(path: "course-terms.json")
    self.init(cacheURL: cache) {
      if fixtureMode {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        var result = CourseTermSchedule.bundled; result.serverNow = .now
        return try encoder.encode(result)
      }
      return try await social.sendData(endpoint: "courses", action: "terms", payload: [:])
    }
  }
  deinit { clockTask?.cancel() }
  var slots: [CourseTerm] { schedule.slots(now: now) }
  func canAccess(term: String) -> Bool { schedule.term(id: term)?.status(at: now) == .open }
  /// Monotonic elapsed time keeps an open screen's deadline independent of wall-clock edits.
  @discardableResult func advanceClock() -> TimeInterval {
    now = anchor.date.addingTimeInterval(max(0, uptime() - anchor.uptime))
    let statuses = Dictionary(uniqueKeysWithValues: schedule.terms.map { ($0.id, $0.status(at: now)) })
    if statuses != lastPersistedStatus { lastPersistedStatus = statuses; persist(); onChange?() }
    let deadlines = schedule.terms.flatMap { [$0.opensAt, $0.closesAt, $0.purgeAt].compactMap { $0 } }.filter { $0 > now }
    return max(0.01, min(60, deadlines.min()?.timeIntervalSince(now) ?? 60))
  }
  func refresh() async {
    generation += 1; let own = generation
    busy = true; error = nil
    defer { if own == generation { busy = false } }
    do {
      let result = try CourseTermSchedule.decode(await transport())
      guard own == generation, !Task.isCancelled else { return }
      guard let serverNow = result.serverNow else { throw CocoaError(.coderReadCorrupt) }
      schedule = result; anchor = (serverNow, uptime())
      advanceClock(); persist()
    } catch {
      guard own == generation, !Task.isCancelled else { return }
      advanceClock()
      self.error = "Couldn’t refresh semester dates. The last verified calendar is still in use."
    }
  }
  private func persist() {
    guard let cacheURL else { return }
    var cached = schedule; cached.serverNow = now
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    do {
      try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try encoder.encode(cached).write(to: cacheURL, options: .atomic)
    } catch { /* Calendar caching is optional; server authorization still enforces the term. */ }
  }
}

@Observable @MainActor final class CourseActivityService {
  typealias Transport = @MainActor (String) async throws -> Data
  private let transport: Transport
  var counts: [String: Int] = [:]
  var error: String?
  var busy = false
  private var generation = 0
  init(transport: @escaping Transport) { self.transport = transport }
  convenience init(social: SocialService, fixtureMode: Bool) {
    self.init { term in
      if fixtureMode { return Data(#"{"courses":[]}"#.utf8) }
      return try await social.sendData(endpoint: "courses", action: "activity", payload: ["term": term])
    }
  }
  func refresh(term: String) async {
    generation += 1; let own = generation
    busy = true; error = nil
    defer { if generation == own { busy = false } }
    do {
      struct Response: Decodable { struct Row: Decodable { let code: String; let members: Int }; let courses: [Row] }
      let response = try JSONDecoder().decode(Response.self, from: await transport(term))
      guard own == generation, !Task.isCancelled else { return }
      counts = Dictionary(response.courses.map { ($0.code, max(0, $0.members)) }, uniquingKeysWith: max)
    } catch {
      guard own == generation, !Task.isCancelled else { return }
      self.error = "Couldn’t refresh class activity. You can still search the catalog."
      counts = [:]
    }
  }
}
