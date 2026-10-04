import MaroonCore
import XCTest
@testable import MaroonSocial

final class InboxCountsTests: XCTestCase {
  private func meta(_ id: String, kind: String = "dm", unread: Int, status: String = "active", outgoing: Bool = false) -> SocialConversationMeta {
    SocialConversationMeta(id: id, kind: kind, status: status, role: "member", canSend: status == "active", unread: unread, lastRead: 0, pendingOutgoing: outgoing)
  }
  func testDistinctMessageRequestAndGroupBadgesHaveExactAggregate() {
    let chats = [Conversation(id:"dm",title:"DM"),Conversation(id:"group",title:"Group"),Conversation(id:"request",title:"Request",request:true),Conversation(id:"outgoing",title:"Sent")]
    let values = ["dm":meta("dm",unread:3),"group":meta("group",kind:"group",unread:7),"request":meta("request",unread:8,status:"pending"),"outgoing":meta("outgoing",unread:1,status:"pending",outgoing:true)]
    let count = InboxCounts(conversations:chats,metadata:values)
    XCTAssertEqual(count.messages,3);XCTAssertEqual(count.groups,7);XCTAssertEqual(count.requests,1);XCTAssertEqual(count.total,11)
    XCTAssertEqual(count.entries["outgoing"]?.category,.requests)
    XCTAssertEqual(count.entries["outgoing"]?.badge,0)
  }
  func testGroupInvitationCountsOnlyAsRequestUntilAccepted() {
    var chat=Conversation(id:"room",title:"Group",request:true)
    let metadata=["room":meta("room",kind:"group",unread:9)]
    let pending=InboxCounts(conversations:[chat],metadata:metadata)
    XCTAssertEqual(pending.requests,1);XCTAssertEqual(pending.groups,0);XCTAssertEqual(pending.total,1)
    chat.request=false
    let accepted=InboxCounts(conversations:[chat],metadata:metadata)
    XCTAssertEqual(accepted.requests,0);XCTAssertEqual(accepted.groups,9)
  }
  func testDuplicateRoomsAndOrphanMetadataNeverInflateBadges() {
    let chat=Conversation(id:"same",title:"Same")
    let count=InboxCounts(conversations:[chat,chat],metadata:["same":meta("same",unread:4),"hidden":meta("hidden",unread:200)])
    XCTAssertEqual(count.total,4);XCTAssertEqual(count.entries.count,1)
  }
  func testClosedRoomsNegativeCountsAndMissingMetadataDoNotBadge() {
    let chats=[Conversation(id:"closed",title:"Closed"),Conversation(id:"negative",title:"Negative"),Conversation(id:"cached",title:"Cached",request:true)]
    let count=InboxCounts(conversations:chats,metadata:["closed":meta("closed",unread:4,status:"closed"),"negative":meta("negative",unread:-2)])
    XCTAssertEqual(count.total,0)
  }
  func testReadingRequestDoesNotDismissRequiredDecisionButReadingMessageClearsCount() {
    let pending=Conversation(id:"invite",title:"Invite",request:true)
    let chat=Conversation(id:"chat",title:"Chat")
    let before=InboxCounts(conversations:[pending,chat],metadata:["invite":meta("invite",unread:1,status:"pending"),"chat":meta("chat",unread:2)])
    let after=InboxCounts(conversations:[pending,chat],metadata:["invite":meta("invite",unread:0,status:"pending"),"chat":meta("chat",unread:0)])
    XCTAssertEqual(before.total,3);XCTAssertEqual(after.total,1);XCTAssertEqual(after.requests,1)
  }
  func testFixturesCountOnlyExplicitIncomingRequestsWithoutInventedUnread() {
    let chats=[Conversation(id:"request",title:"Request",request:true),Conversation(id:"local",title:"Local",messages:[Message(author:"another",text:"Fixture message")])]
    let count=InboxCounts(conversations:chats,metadata:[:],fixtureMode:true)
    XCTAssertEqual(count.requests,1);XCTAssertEqual(count.messages,0);XCTAssertEqual(count.total,1)
  }
}
