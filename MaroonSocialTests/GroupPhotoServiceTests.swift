import XCTest
@testable import MaroonSocial

@MainActor final class GroupPhotoServiceTests: XCTestCase {
  func testMemberPhotoUsesScopedKeyAndNoAccountName() async throws {
    var calls: [(String,[String:Any])] = []
    let service = GroupPhotoService { action,payload in calls.append((action,payload)); return Data(#"{"saved":true}"#.utf8) }
    try await service.save(Data([1,2,3]), room: "room-one", memberKey: "self")
    XCTAssertEqual(calls.count, 1); XCTAssertEqual(calls[0].0, "upload")
    XCTAssertEqual(calls[0].1["scope"] as? String, "member")
    XCTAssertEqual(calls[0].1["member_key"] as? String, "self")
    XCTAssertNil(calls[0].1["username"]); XCTAssertNil(calls[0].1["member_id"])
  }
  func testNoPhotoAndOversizedReadAreDistinct() async throws {
    let empty = GroupPhotoService { _,_ in Data(#"{"has_photo":false}"#.utf8) }
    let absent = try await empty.read(room: "room-one"); XCTAssertNil(absent)
    let large = GroupPhotoService { _,_ in try JSONSerialization.data(withJSONObject:["has_photo":true,"media_data":Data(repeating:1,count:350001).base64EncodedString()]) }
    do { _ = try await large.read(room: "room-one"); XCTFail("Oversized response accepted") } catch {}
  }
  func testFailedSaveDoesNotInvalidateVisiblePhotosOrPretendSuccess() async throws {
    let revision = GroupPhotoRevision.shared.value
    let service = GroupPhotoService { _,_ in throw URLError(.notConnectedToInternet) }
    do { try await service.save(nil, room: "room-one"); XCTFail("Failure accepted") } catch {}
    XCTAssertEqual(GroupPhotoRevision.shared.value, revision)
  }
}
