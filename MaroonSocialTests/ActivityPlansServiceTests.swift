import XCTest
@testable import MaroonSocial

@MainActor final class ActivityPlansServiceTests:XCTestCase {
  func testWeeklyPreviewKeepsChicagoClockAcrossFallDST()throws {
    var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:"America/Chicago")!
    let first=try XCTUnwrap(calendar.date(from:DateComponents(year:2026,month:10,day:25,hour:10)))
    let dates=ActivityPlansService.weeklyDates(start:first,weeks:3)
    XCTAssertEqual(dates.count,3)
    XCTAssertEqual(dates.map{calendar.component(.hour,from:$0)},[10,10,10])
    XCTAssertEqual(dates[1].timeIntervalSince(dates[0]),7*86400+3600)
    XCTAssertTrue(ActivityPlansService.weeklyDates(start:first,weeks:9).isEmpty)
  }
  func testSeriesCreationPreservesNonceAndApprovalAndDoesNotFakeOfflineSuccess()async throws {
    var captured:[String:Any]=[:]
    let service=ActivityPlansService{action,payload in
      XCTAssertEqual(action,"series.create");captured=payload
      return Data(#"{"activity_ids":["first","second"]}"#.utf8)
    }
    let ids=try await service.createSeries(["nonce":"original","weeks":2,"approval_required":true,"title":"Study"])
    XCTAssertEqual(ids,["first","second"]);XCTAssertEqual(captured["nonce"]as?String,"original");XCTAssertEqual(captured["approval_required"]as?Bool,true)
    let failing=ActivityPlansService{_,_ in throw URLError(.notConnectedToInternet)}
    do{_=try await failing.createSeries(["nonce":"same"]);XCTFail("Offline creation falsely succeeded")}catch{}
  }
  func testSeriesInfoDecodesAuthoritativeDatesAndHostPermission()async throws {
    let service=ActivityPlansService{action,payload in
      XCTAssertEqual(action,"series.cancel_future");XCTAssertEqual(payload["activity_id"]as?String,"chosen")
      return Data(#"{"is_series":true,"can_manage":true,"series_id":"series","occurrences":[{"id":"chosen","starts":1800000000,"cancelled":true}]}"#.utf8)
    }
    let result=try await service.series(activity:"chosen",cancelFuture:true)
    XCTAssertEqual(result.canManage,true);XCTAssertEqual(result.occurrences?.first?.starts,Date(timeIntervalSince1970:1800000000));XCTAssertEqual(result.occurrences?.first?.cancelled,true)
  }
  func testPromotionAndPosterFailuresDoNotAcknowledgePublication()async throws {
    let missing=ActivityPlansService{_,_ in Data(#"{"activity_id":""}"#.utf8)}
    do{_=try await missing.publish([:]);XCTFail("Missing publication ID accepted")}catch{}
    let refused=ActivityPlansService{_,_ in Data(#"{"saved":false}"#.utf8)}
    do{try await refused.savePoster(Data([1]),activity:"event");XCTFail("Uncommitted poster accepted")}catch{}
    let absent=ActivityPlansService{_,_ in Data(#"{"has_poster":false}"#.utf8)}
    let value=try await absent.poster(activity:"event");XCTAssertNil(value)
  }
}
