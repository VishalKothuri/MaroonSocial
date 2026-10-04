import XCTest
@testable import MaroonSocial

@MainActor final class AccountControlsServiceTests: XCTestCase {
  func testExportCollectsEveryPageAndDoesNotMixSections() async throws {
    var postOffsets: [Int] = []
    let service = AccountControlsService { action, payload in
      XCTAssertEqual(action, "export")
      let section = payload["section"] as? String
      let offset = payload["offset"] as? Int ?? 0
      if section == "posts" {
        postOffsets.append(offset)
        return try JSONSerialization.data(withJSONObject: ["data": [["body": offset == 0 ? "first" : "second"]], "has_more": offset == 0])
      }
      return try JSONSerialization.data(withJSONObject: ["data": section == "account" ? ["username": "test"] : [], "has_more": false])
    }
    let result = await service.exportData()
    let data = try XCTUnwrap(result)
    let archive = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertEqual(postOffsets, [0, 200])
    XCTAssertEqual((archive["posts"] as? [[String: String]])?.map { $0["body"] ?? "" }, ["first", "second"])
    XCTAssertTrue((archive["messages"] as? [Any])?.isEmpty == true)
    XCTAssertEqual((archive["account"] as? [String: String])?["username"], "test")
    XCTAssertFalse(service.busy)
    XCTAssertNil(service.exportProgress)
  }
  func testFailedExportNeverReturnsPartialArchive() async {
    let service = AccountControlsService { _, payload in
      if payload["section"] as? String == "messages" { throw URLError(.notConnectedToInternet) }
      return Data("{\"data\":[],\"has_more\":false}".utf8)
    }
    let data = await service.exportData()
    XCTAssertNil(data)
    XCTAssertNotNil(service.error)
    XCTAssertFalse(service.busy)
    XCTAssertNil(service.exportProgress)
  }
  func testRevocationClearsPreviouslyLoadedPrivateLists() async {
    var revoked = false
    let service = AccountControlsService { _, _ in
      if revoked { throw SocialServiceError(error: "Account unavailable", code: "unauthorized") }
      return Data("{\"connections\":[{\"id\":\"relation\",\"username\":\"friend\",\"status\":\"accepted\",\"created_at\":1000}],\"blocks\":[{\"id\":\"private-block\",\"label\":\"Anonymous post\",\"created_at\":1000}]}".utf8)
    }
    await service.act("connections")
    XCTAssertEqual(service.connections.count, 1)
    XCTAssertEqual(service.blocks.count, 1)
    revoked = true
    await service.act("connections")
    XCTAssertTrue(service.connections.isEmpty)
    XCTAssertTrue(service.blocks.isEmpty)
    XCTAssertFalse(service.loaded)
  }
}
