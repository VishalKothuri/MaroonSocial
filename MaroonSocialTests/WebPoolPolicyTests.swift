import XCTest
@testable import MaroonSocial
final class WebPoolPolicyTests: XCTestCase {
  func testCredentialsOnlyEnterTheExactHostedTableOrigin() throws {
    XCTAssertTrue(WebPoolPolicy.table(try XCTUnwrap(URL(string: "https://games.maroonsocial.chat/"))))
    XCTAssertTrue(WebPoolPolicy.table(try XCTUnwrap(URL(string: "https://maroon-social-games.vercel.app/"))))
    for address in ["https://other.vercel.app/", "https://maroon-social-games.vercel.app.evil.example/", "https://user:pass@maroon-social-games.vercel.app/","https://games.maroonsocial.chat.evil.example/", "http://games.maroonsocial.chat/", "https://games.maroonsocial.chat:8443/", "https://name:pass@games.maroonsocial.chat/", "https://games.maroonsocial.chat/?game=nineball", "https://games.maroonsocial.chat/source.html"] {
      XCTAssertFalse(WebPoolPolicy.table(try XCTUnwrap(URL(string: address))), address)
    }
    XCTAssertTrue(WebPoolPolicy.source(try XCTUnwrap(URL(string: "https://games.maroonsocial.chat/source/maroon-pool-source.tar.gz"))))
    XCTAssertFalse(WebPoolPolicy.source(try XCTUnwrap(URL(string: "https://games.maroonsocial.chat/account"))))
  }
}
