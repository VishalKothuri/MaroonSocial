import XCTest
@testable import MaroonSocial

@MainActor final class CourseCatalogTests: XCTestCase {
  func testBundledOfficialCatalogSearchCoversUndergraduateAndProfessionalCourses() throws {
    let catalog = try XCTUnwrap(CourseCatalog.bundled)
    XCTAssertEqual(catalog.courses.count, 10182)
    XCTAssertEqual(Set(catalog.courses.map(\.code)).count, catalog.courses.count)
    XCTAssertEqual(catalog.search("CHEM107").first?.code, "CHEM 107")
    XCTAssertTrue(catalog.search("DDHS 3020").contains { $0.code == "DDHS 3020" })
    XCTAssertTrue(catalog.search("disaster management", level: "Graduate").contains { $0.code == "AAMD 601" })
    XCTAssertTrue(catalog.courses.allSatisfy { $0.sourceURL.host == "catalog.tamu.edu" })
    XCTAssertTrue(catalog.search("unmatched-zzzzzzzz").isEmpty)
  }
  func testParticipationRanksExistingClassesWithoutHidingEmptyCourses() throws {
    let catalog = try XCTUnwrap(CourseCatalog.bundled)
    let sorted = catalog.search("", counts: ["MATH 151": 7, "CHEM 107": 3])
    XCTAssertEqual(Array(sorted.prefix(2)).map(\.code), ["MATH 151", "CHEM 107"])
    XCTAssertEqual(sorted.count, catalog.courses.count)
  }
  func testActivityErrorClearsOldCountsAndNeverInventsParticipation() async {
    var fails = false
    let service = CourseActivityService { _ in
      if fails { throw URLError(.notConnectedToInternet) }
      return Data(#"{"courses":[{"code":"CHEM 107","members":2}]}"#.utf8)
    }
    await service.refresh(term: "Fall 2026")
    XCTAssertEqual(service.counts["CHEM 107"], 2)
    fails = true
    await service.refresh(term: "Spring 2027")
    XCTAssertTrue(service.counts.isEmpty)
    XCTAssertNotNil(service.error)
  }
  func testSemesterChoicesFollowCurrentChicagoAcademicSeason() {
    XCTAssertEqual(CourseCatalog.terms(now: ISO8601DateFormatter().date(from: "2026-10-03T12:00:00Z")!), ["Fall 2026", "Spring 2027", "Summer 2027"])
    XCTAssertEqual(CourseCatalog.terms(now: ISO8601DateFormatter().date(from: "2027-02-03T12:00:00Z")!).first, "Spring 2027")
  }
}
