import XCTest
import MaroonCore
@testable import MaroonSocial

@MainActor final class SportsServiceTests: XCTestCase {
  func testRealShapedResultAndMarketAreSeparateFromLiveStatus() async throws {
    let service = SportsService { self.payload() }
    await service.refresh()
    let snapshot = try XCTUnwrap(service.snapshot)
    let game = try XCTUnwrap(snapshot.games.first)
    XCTAssertEqual(game.statusText, "Scheduled")
    XCTAssertFalse(game.hasScore)
    XCTAssertEqual(game.quote?.priceText, "72¢ bid · 74¢ ask")
    XCTAssertFalse(snapshot.livePlayAvailable)
    XCTAssertNil(SportsGame.safeURL("https://12thman.com@evil.invalid", hosts: ["12thman.com"]))
  }
  func testMatchingRequiresOpponentSportTimeAndNoAmbiguity() async throws {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
    let snapshot = try decoder.decode(SportsSnapshot.self, from: payload())
    let event = CampusEvent(id: "campus", title: "Texas A&M Football vs Missouri", category: "Sports", starts: Date(timeIntervalSince1970: 1_791_648_000), url: "https://calendar.tamu.edu/event/example", source: "calendar")
    XCTAssertEqual(snapshot.game(for: event)?.opponent, "Missouri")
    var other = event; other.title = "Texas A&M Volleyball vs Missouri"
    XCTAssertNil(snapshot.game(for: other))
    other = event; other.starts = event.starts.addingTimeInterval(86400)
    XCTAssertNil(snapshot.game(for: other))
    let duplicate = SportsSnapshot(games: snapshot.games + snapshot.games, fetchedAt: snapshot.fetchedAt, source: snapshot.source, sourceURL: snapshot.sourceURL, livePlayAvailable: false, warnings: [])
    XCTAssertNil(duplicate.game(for: event))
  }
  func testFailedRefreshRetainsLastFactualSnapshotAndNormalRefreshIsThrottled() async {
    var requests = 0
    let service = SportsService {
      requests += 1
      if requests > 1 { throw URLError(.notConnectedToInternet) }
      return self.payload()
    }
    await service.refresh(); await service.refresh()
    XCTAssertEqual(requests, 1)
    await service.refresh(force: true)
    XCTAssertEqual(service.snapshot?.games.first?.id, "3595")
    XCTAssertNotNil(service.error)
  }
  private func payload() -> Data {
    Data("""
    {"games":[{"id":"3595","sport":"Football","sportSlug":"football","opponent":"Missouri","starts":1791648000,"timeTBA":false,"homeAway":"away","status":"scheduled","aggieScore":null,"opponentScore":null,"result":null,"sourceURL":"https://12thman.com/sports/football/schedule","trackerURL":"https://statb.us/v/tam/672834","quote":{"ticker":"fixture","title":"Texas A&M wins","bid":0.72,"ask":0.74,"last":0.73,"updatedAt":1791144000,"sourceURL":"https://kalshi.com/markets/kxncaafgame"}}],"fetchedAt":1791144000,"source":"Texas A&M Athletics","sourceURL":"https://12thman.com","livePlayAvailable":false,"warnings":[]}
    """.utf8)
  }
}
