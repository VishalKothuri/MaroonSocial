import XCTest
import MaroonCore
@testable import MaroonSocial

@MainActor final class CampusServiceTests: XCTestCase {
  private func event(_ id: String) -> CampusEvent {
    CampusEvent(id: id, title: "Now Hiring: Lifeguard", category: "Rec",
                starts: Date(timeIntervalSince1970: 1791090000), allDay: true,
                details: "Apply to work at the campus pool.",
                url: "https://calendar.tamu.edu/recsports/event/\(id)-now-hiring-lifeguard",
                source: "https://calendar.tamu.edu/live/json/events/group/Rec%20Sports")
  }
  func testExplicitTitleCancellationHonorsBothSpellingsWithoutMatchingDiscussion() {
    let titles = ["Women’s Soccer vs. SMU (Canceled)", "[Cancelled] Soccer", "Canceled: Soccer", "Soccer — Cancelled",
                  "How to avoid canceled events", "Not canceled", "Canceled plans discussion"]
    let input = titles.enumerated().map { index, title in
      var value = event("\(index)"); value.title = title; return value
    }
    XCTAssertEqual(CampusService.normalizedEvents(input).map(\.cancelled), [true, true, true, true, false, false, false])
    var flagged = event("flagged"); flagged.cancelled = true
    XCTAssertTrue(CampusService.normalizedEvents([flagged])[0].cancelled)
  }
  func testIdenticalListingsCollapseAndSavedOriginalIDRemainsUsable() {
    let service = CampusService()
    service.events = [event("395627"), event("395625"), event("395626")]
    XCTAssertEqual(service.displayEvents().map(\.id), ["395625"])
    XCTAssertEqual(service.displayEvents(savedIDs: ["395627"]).map(\.id), ["395627"])
    XCTAssertEqual(service.events.count, 3, "Original source IDs must stay available for bookmarks and cache persistence")
    service.events.reverse()
    XCTAssertEqual(service.displayEvents().map(\.id), ["395625"], "Feed ordering must not change the representative")
  }
  func testMeaningfullyDifferentOrTruncatedListingsAreNeverCollapsed() {
    var location = event("2"); location.location = "Student Recreation Center"
    var details = event("3"); details.details = "Apply for a different role."
    var date = event("4"); date.starts += 86400
    var link = event("5"); link.url = "https://calendar.tamu.edu/recsports/event/5-other-role"
    var source = event("6"); source.source = "https://calendar.tamu.edu/another-feed"
    var truncated = event("7"); truncated.details = String(repeating: "a", count: 1200)
    var truncatedAgain = truncated; truncatedAgain.id = "8"; truncatedAgain.url = event("8").url
    let service = CampusService()
    service.events = [event("1"), location, details, date, link, source, truncated, truncatedAgain]
    XCTAssertEqual(service.displayEvents().count, 8)
  }
}
