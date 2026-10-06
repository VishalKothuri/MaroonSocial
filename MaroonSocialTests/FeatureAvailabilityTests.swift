import MaroonCore
import XCTest
@testable import MaroonSocial

@MainActor final class FeatureAvailabilityTests: XCTestCase {
  private let plain = ["--uitesting"]
  private let enabled = ["--uitesting", "--enable-hidden-features"]

  func testHiddenGamesByKindAndTitle() {
    XCTAssertEqual(FeatureAvailability.hiddenGameKinds, ["pool", "pong"])
    for value in ["pool", "pong", "8 Ball", "Cup Pong", "8 ball", " cup pong "] {
      XCTAssertFalse(FeatureAvailability.isGameAvailable(kind: value, arguments: plain), value)
      XCTAssertFalse(FeatureAvailability.isGameAvailable(title: value, arguments: plain), value)
    }
    for value in ["chess", "Chess"] {
      XCTAssertTrue(FeatureAvailability.isGameAvailable(kind: value, arguments: plain), value)
      XCTAssertTrue(FeatureAvailability.isGameAvailable(title: value, arguments: plain), value)
    }
    XCTAssertEqual(FeatureAvailability.availableGameKinds(arguments: plain), ["chess"])
    XCTAssertEqual(FeatureAvailability.gameKind(for: "8 Ball"), "pool")
    XCTAssertEqual(FeatureAvailability.gameKind(for: "Cup Pong"), "pong")
    XCTAssertEqual(FeatureAvailability.unavailableMessage(for: "pool"), "8 Ball isn’t available right now")
    XCTAssertEqual(FeatureAvailability.unavailableMessage(for: "Cup Pong"), "Cup Pong isn’t available right now")
  }

  func testCampusTagHiddenUnlessOverridden() {
    XCTAssertFalse(FeatureAvailability.campusTagEnabled)
    XCTAssertFalse(FeatureAvailability.isCampusTagAvailable(arguments: plain))
    XCTAssertFalse(FeatureAvailability.isCampusTagAvailable(arguments: []))
    XCTAssertTrue(FeatureAvailability.isCampusTagAvailable(arguments: enabled))
  }

  func testOnlyTheExactLaunchArgumentRestoresEverything() {
    XCTAssertTrue(FeatureAvailability.hiddenFeaturesEnabled(arguments: enabled))
    XCTAssertEqual(FeatureAvailability.availableGameKinds(arguments: enabled), ["pool", "pong", "chess"])
    XCTAssertTrue(FeatureAvailability.isGameAvailable(title: "8 Ball", arguments: enabled))
    XCTAssertTrue(FeatureAvailability.isGameAvailable(kind: "pong", arguments: enabled))
    for near in [["--enable-hidden-feature"], ["enable-hidden-features"], ["--ENABLE-HIDDEN-FEATURES"], ["--uitesting-preserve"]] {
      XCTAssertFalse(FeatureAvailability.hiddenFeaturesEnabled(arguments: near), "\(near)")
      XCTAssertFalse(FeatureAvailability.isGameAvailable(kind: "pool", arguments: near), "\(near)")
    }
  }

  func testUnitTestProcessDoesNotEnableHiddenFeatures() {
    XCTAssertFalse(ProcessInfo.processInfo.arguments.contains(FeatureAvailability.enableHiddenFeaturesArgument))
    XCTAssertFalse(FeatureAvailability.isGameAvailable(kind: "pool"))
    XCTAssertFalse(FeatureAvailability.isCampusTagAvailable())
    XCTAssertTrue(FeatureAvailability.isGameAvailable(kind: "chess"))
  }

  func testGameActivityLeavesOutNoticesOfHiddenKinds() throws {
    let json = """
    [{"id":"a","kind":"game_invite","title":"Game invitation","gameID":"g-pool","created":1,"read":false},
     {"id":"b","kind":"game_turn","title":"Your turn","gameID":"g-chess","created":2,"read":false},
     {"id":"c","kind":"game_invite","title":"Game invitation","gameID":"g-unknown","created":3,"read":true}]
    """
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
    let items = try decoder.decode([PushGameNotice].self, from: Data(json.utf8))
    let kinds = ["g-pool": "pool", "g-chess": "chess"]
    XCTAssertEqual(PushGameInbox.visible(items, kinds: kinds, arguments: plain).map(\.id), ["b", "c"])
    XCTAssertEqual(PushGameInbox.visible(items, kinds: kinds, arguments: enabled).map(\.id), ["a", "b", "c"])
  }

  func testFixtureChatCarriesAHiddenKindInvitation() {
    let message = AppStore.fixtureHiddenGameInvitation
    XCTAssertEqual(message.game, "8 Ball")
    XCTAssertNotNil(message.gameSessionID)
    XCTAssertTrue(ChatView.isHiddenGameInvitation(message))
    var chess = message; chess.game = "Chess"
    XCTAssertFalse(ChatView.isHiddenGameInvitation(chess))
  }

  func testHiddenInvitationTextNeverShowsInQuotesOrReplies() {
    let invitation = AppStore.fixtureHiddenGameInvitation
    XCTAssertEqual(ChatView.displayText(invitation), "8 Ball isn’t available right now")
    XCTAssertEqual(invitation.text, "Pool invitation. Accept to start.", "The stored message is untouched")
    var rematch = invitation; rematch.game = "pool"; rematch.text = "Pool rematch invitation. Accept to start."
    XCTAssertEqual(ChatView.displayText(rematch), "8 Ball isn’t available right now")
    var pong = invitation; pong.game = "Cup Pong"
    XCTAssertEqual(ChatView.displayText(pong), "Cup Pong isn’t available right now")
    var chess = invitation; chess.game = "Chess"; chess.text = "Chess invitation. Accept to start."
    XCTAssertEqual(ChatView.displayText(chess), "Chess invitation. Accept to start.")
    let plainText = Message(author: "Them", text: "See you at the library")
    XCTAssertEqual(ChatView.displayText(plainText), "See you at the library")
    let reply = AppStore.fixtureHiddenGameInvitationReply
    XCTAssertEqual(reply.replyTo, invitation.id, "The fixture chat quotes the hidden invitation")
  }
}
