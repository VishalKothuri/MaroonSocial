import XCTest
@testable import MaroonSocial

@MainActor final class CommunitiesServiceTests: XCTestCase {
  private func row(_ id: String, joined: Bool = false) -> [String: Any] {
    ["id": id, "title": id, "description": "A campus community", "category": "General", "capacity": 200,
     "member_count": 2, "joined": joined, "owner": false, "closed": false, "is_public": true, "created_at": 1000]
  }
  func testReportPreservesLoadedDetailAndRoster() async throws {
    let service = CommunitiesService { action, _ in
      if action == "report" { return Data(#"{"reported":true}"#.utf8) }
      return try JSONSerialization.data(withJSONObject: ["community": self.row("room", joined: true), "members": [["username": "classmate", "role": "member"]], "bans": []])
    }
    let detail = await service.act("detail")
    XCTAssertEqual(detail, "room")
    let report = await service.act("report")
    XCTAssertEqual(report, "ok")
    XCTAssertEqual(service.community?.id, "room")
    XCTAssertEqual(service.members.map(\.username), ["classmate"])
  }
  func testRemovedMemberLosesCachedDetailAndRoster() async throws {
    var removed = false
    let service = CommunitiesService { _, _ in
      if removed { throw SocialServiceError(error: "Community unavailable", code: "unavailable") }
      return try JSONSerialization.data(withJSONObject: ["community": self.row("private-room", joined: true), "members": [["username": "classmate", "role": "member"]]])
    }
    _ = await service.act("detail")
    XCTAssertNotNil(service.community)
    removed = true
    _ = await service.act("detail")
    XCTAssertNil(service.community)
    XCTAssertTrue(service.members.isEmpty)
    XCTAssertFalse(service.loaded)
  }
  func testPaginationDeduplicatesAndUsesCurrentOffset() async {
    var offsets: [Int] = []
    let service = CommunitiesService { _, payload in
      let offset = payload["offset"] as? Int ?? -1; offsets.append(offset)
      return try JSONSerialization.data(withJSONObject: ["communities": offset == 0 ? [self.row("a"), self.row("b")] : [self.row("b"), self.row("c")], "has_more": offset == 0])
    }
    await service.list(search: "", category: "All", joinedOnly: false)
    await service.list(search: "", category: "All", joinedOnly: false, more: true)
    XCTAssertEqual(offsets, [0, 2])
    XCTAssertEqual(service.communities.map(\.id), ["a", "b", "c"])
    XCTAssertFalse(service.hasMore)
  }
  func testSlowerOldSearchNeverOverwritesNewSearch() async {
    var oldStarted = false
    let service = CommunitiesService { _, payload in
      let query = payload["search"] as? String ?? ""
      if query == "old" { oldStarted = true; try await Task.sleep(for: .milliseconds(50)) }
      return try JSONSerialization.data(withJSONObject: ["communities": [self.row(query)], "has_more": false])
    }
    let oldRequest = Task { await service.list(search: "old", category: "All", joinedOnly: false) }
    while !oldStarted { await Task.yield() }
    await service.list(search: "new", category: "All", joinedOnly: false)
    await oldRequest.value
    XCTAssertEqual(service.communities.map(\.id), ["new"])
    XCTAssertFalse(service.busy)
  }
  func testFixtureDirectoryAndMutationNeverUseLiveTransport() async {
    var requests = 0
    let social = SocialService(credentials: SocialCredentialStore(read: { nil }, save: { _ in }, deletionPending: { false }, markDeletionPending: {}, clear: {}), transport: { _, _, _, _ in
      requests += 1
      throw URLError(.badServerResponse)
    })
    let service = CommunitiesService(social: social, fixtureMode: true)
    await service.list(search: "", category: "All", joinedOnly: false)
    XCTAssertTrue(service.loaded)
    XCTAssertTrue(service.communities.isEmpty)
    let result = await service.act("create", ["title": "Fixture only"])
    XCTAssertNil(result)
    XCTAssertNotNil(service.error)
    XCTAssertEqual(requests, 0)
  }
}
