import MaroonCore
import SwiftUI

struct SportsScoresView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  @State private var service: SportsService?
  @State private var filter = "All sports"
  private var games: [SportsGame] {
    (service?.snapshot?.games ?? []).filter { filter == "All sports" || $0.sport == filter }
      .sorted { a, b in
        if (a.starts < .now) != (b.starts < .now) { return a.starts < .now }
        return a.starts < .now ? a.starts > b.starts : a.starts < b.starts
      }
  }
  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 14) {
        if let snapshot = service?.snapshot {
          Picker("Sport", selection: $filter) {
            Text("All sports").tag("All sports")
            ForEach(Array(Set(snapshot.games.map(\.sport))).sorted(), id: \.self) { Text($0).tag($0) }
          }.pickerStyle(.menu).accessibilityIdentifier("sportsFilter")
          Text("Official results & upcoming games").font(.headline)
          Text("Scores update when Texas A&M Athletics publishes them. Open the official tracker for play-by-play.")
            .font(.caption).foregroundStyle(.secondary)
          ForEach(games) { game in SportsScoreCard(game: game, fetchedAt: snapshot.fetchedAt) }
          if games.isEmpty { Text("No games are listed for this sport in the current feed.").foregroundStyle(.secondary) }
          Text("Texas A&M Athletics · updated \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption2).foregroundStyle(.secondary)
          ForEach(snapshot.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
        } else if service?.loading != false {
          HStack { ProgressView(); Text("Loading official scores…") }.padding(.vertical, 24)
        }
        if let error = service?.error {
          Text(error).font(.callout).foregroundStyle(.secondary)
          Button("Retry") { Task { await service?.refresh(force: true) } }.buttonStyle(OutlinedActionStyle())
        }
        Link("Texas A&M Athletics", destination: URL(string: "https://12thman.com")!).font(.subheadline.bold())
      }.padding(16)
    }.appBackground().navigationTitle("Aggie scores").navigationBarTitleDisplayMode(.inline)
      .maroonRefreshable(scope: "sports") { await service?.refresh(force: true) }
      .task {
        if service == nil { service = SportsService(social: store.social) }
        await service?.refresh()
        while !Task.isCancelled {
          do { try await Task.sleep(for: .seconds(120)) } catch { break }
          if scenePhase == .active { await service?.refresh() }
        }
      }
  }
}
struct SportsEventHeader: View {
  @Environment(AppStore.self) private var store
  let event: CampusEvent
  @State private var service: SportsService?
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let snapshot = service?.snapshot, let game = snapshot.game(for: event) {
        SportsScoreCard(game: game, fetchedAt: snapshot.fetchedAt)
      } else {
        if service?.loading == true { HStack { ProgressView(); Text("Checking official scores…").font(.caption) } }
        else { Text("See official scores and trackers in Aggie scores.").font(.caption).foregroundStyle(.secondary) }
        NavigationLink("Aggie scores") { SportsScoresView() }.font(.subheadline.bold())
      }
    }.accessibilityIdentifier("sportsEventHeader")
      .task { if service == nil { service = SportsService(social: store.social) }; await service?.refresh() }
  }
}
private struct SportsScoreCard: View {
  let game: SportsGame
  let fetchedAt: Date
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(game.sport).font(.caption.bold())
        Spacer()
        Text(game.statusText).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
      }
      VStack(spacing: 10) {
        scoreRow("Texas A&M", value: game.aggieScore)
        scoreRow(game.opponent, value: game.opponentScore)
      }
      Text(game.starts, format: game.timeTBA ? .dateTime.month(.abbreviated).day() : .dateTime.month(.abbreviated).day().hour().minute())
        .font(.caption).foregroundStyle(.secondary)
      if game.timeTBA { Text("Time to be announced").font(.caption).foregroundStyle(.secondary) }
      HStack(spacing: 18) {
        if let source = game.source { Link(game.status == "final" ? "Official result" : "Official schedule", destination: source) }
        if let tracker = game.tracker { Link("Play-by-play ↗", destination: tracker).accessibilityLabel("Open official play-by-play for Texas A&M versus \(game.opponent)") }
      }.font(.caption.bold())
      if let quote = game.quote, let url = SportsGame.safeURL(quote.sourceURL, hosts: ["kalshi.com"]) {
        Divider()
        VStack(alignment: .leading, spacing: 5) {
          Text("Kalshi · Texas A&M wins").font(.caption.bold())
          Text(quote.priceText).font(.subheadline.weight(.semibold)).monospacedDigit()
          Text("Market prices per $1 contract, not a predicted win probability.").font(.caption2).foregroundStyle(.secondary)
          Link("View market", destination: url).font(.caption.bold())
          Text("Quote updated \(quote.updatedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption2).foregroundStyle(.secondary)
        }
      }
      if Date.now.timeIntervalSince(fetchedAt) > 300 {
        Label("Saved update · may be out of date", systemImage: "clock").font(.caption2).foregroundStyle(.secondary)
      }
    }.padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
      .accessibilityElement(children: .contain).accessibilityIdentifier("sportsGame-\(game.id)")
  }
  private func scoreRow(_ team: String, value: Double?) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(team).font(.headline).fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 12)
      if game.hasScore, let value { Text(value.formatted(.number.precision(.fractionLength(0...2)))).font(.title2.bold()).monospacedDigit() }
      else { Text("—").font(.title2).foregroundStyle(.secondary).accessibilityLabel("Score not published") }
    }
  }
}

/// Compact scoreboard pinned above a game-day chat: the official score once it
/// is published, the status until then, and the official play-by-play. It
/// refreshes every minute while the chat is open; the feed only carries final
/// scores, so a game in progress shows "In progress" rather than a live count.
struct GameChatHeader: View {
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  let event: CampusEvent
  @State private var service: SportsService?
  private var game: SportsGame? { service?.snapshot.flatMap { $0.game(for: event) } }
  private var live: Bool { event.canOpenSportsChat(at: .now) && event.starts <= .now }
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Circle().fill(live ? Color.red : Palette.secondary).frame(width: 7, height: 7)
        Text(game?.sport ?? "Game day").font(.caption.bold())
        Spacer()
        Text(statusLine).font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text("Texas A&M").font(.subheadline.weight(.semibold)).lineLimit(1)
        Text(score(game?.aggieScore)).font(.title3.bold()).monospacedDigit()
        Text("–").foregroundStyle(.secondary)
        Text(score(game?.opponentScore)).font(.title3.bold()).monospacedDigit()
        Text(game?.opponent ?? opponentName).font(.subheadline.weight(.semibold)).lineLimit(1)
        Spacer(minLength: 8)
        if let tracker = game?.tracker { Link("Play-by-play ↗", destination: tracker).font(.caption.bold()) }
      }
    }.padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
      .background(Palette.surface).overlay(alignment: .bottom) { Divider() }
      .accessibilityElement(children: .combine).accessibilityIdentifier("gameChatHeader")
      .task {
        if service == nil { service = SportsService(social: store.social) }
        await service?.refresh()
        while !Task.isCancelled {
          do { try await Task.sleep(for: .seconds(60)) } catch { break }
          if scenePhase == .active { await service?.refresh() }
        }
      }
  }
  private var statusLine: String {
    if let game, game.status != "scheduled" { return game.statusText }
    if event.starts > .now { return "Starts " + event.starts.formatted(date: .omitted, time: .shortened) }
    return "In progress · official score posts at the final"
  }
  /// "Texas A&M University Football vs Arkansas" → "Arkansas" when athletics has no matching record yet.
  private var opponentName: String {
    for separator in [" vs. ", " vs ", " at "] {
      if let range = event.title.range(of: separator) { return String(event.title[range.upperBound...]).trimmingCharacters(in: .whitespaces) }
    }
    return "Opponent"
  }
  private func score(_ value: Double?) -> String {
    guard let game, game.hasScore, let value else { return "—" }
    return value.formatted(.number.precision(.fractionLength(0...2)))
  }
}
