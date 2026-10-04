import XCTest
import MaroonCore
@testable import MaroonSocial

@MainActor final class DurableCompositionsTests: XCTestCase {
  private func file() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("drafts-" + UUID().uuidString).appendingPathComponent("document.json") }
  func testDraftRestoresMediaPollReplyAndNonceAfterRelaunch() async throws {
    let file = file(); defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let first = DurableCompositions(); first.configure(file: file, owner: "owner")
    let media = MediaAttachment(kind: .image, data: Data([1,2,3]))
    let draft = CompositionDraft(text: "saved text", media: media, fields: ["replyID":"original","link":"https://tamu.edu"], poll: PostPollDraft(question:"Study?",options:["Today","Tomorrow"]), nonce:"stable-nonce", hasContent:true)
    let saved = await first.saveDraft(draft,key:"message:room"); XCTAssertTrue(saved)
    let second = DurableCompositions(); second.configure(file:file,owner:"owner")
    let restored = try XCTUnwrap(second.draft("message:room"))
    XCTAssertEqual(restored.text,draft.text); XCTAssertEqual(restored.media,media)
    XCTAssertEqual(restored.poll,draft.poll); XCTAssertEqual(restored.fields,draft.fields); XCTAssertEqual(restored.nonce,draft.nonce)
  }
  func testQueuePersistsUploadAcknowledgementAndRejectsNonceReuse() async throws {
    let file = file(); defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let first = DurableCompositions(); first.configure(file:file,owner:"owner")
    var message = QueuedMessage(nonce:"one",roomID:"room",text:"hello",media:nil,replyID:"parent")
    try await first.enqueue(message); try await first.enqueue(message)
    XCTAssertEqual(first.queue.count,1)
    do { try await first.enqueue(QueuedMessage(nonce:"one",roomID:"room",text:"different",media:nil,replyID:"parent")); XCTFail("Conflicting nonce accepted") } catch {}
    message.attachmentID = "uploaded"; message.requiresRetry = true; message.failure = "Not permitted"
    try await first.update(message)
    let second = DurableCompositions(); second.configure(file:file,owner:"owner")
    XCTAssertEqual(second.queue.first?.attachmentID,"uploaded"); XCTAssertEqual(second.queue.first?.replyID,"parent"); XCTAssertEqual(second.queue.first?.requiresRetry,true)
    try await second.retry("one"); XCTAssertEqual(second.queue.first?.requiresRetry,false)
    try await second.remove("one")
    let third = DurableCompositions(); third.configure(file:file,owner:"owner"); XCTAssertTrue(third.queue.isEmpty)
  }
  func testAccountBoundaryAndFreshFixtureNeverRestoreOthersDrafts() async throws {
    let file = file(); defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
    let first = DurableCompositions(); first.configure(file:file,owner:"original")
    await first.saveDraft(CompositionDraft(text:"private",nonce:"nonce",hasContent:true),key:"post")
    try await first.enqueue(QueuedMessage(nonce:"one",roomID:"room",text:"private",media:nil,replyID:nil))
    let other = DurableCompositions(); other.configure(file:file,owner:"other")
    XCTAssertNil(other.draft("post")); XCTAssertTrue(other.queue.isEmpty)
    let fresh = DurableCompositions(); fresh.configure(file:file,owner:"original",reset:true)
    XCTAssertNil(fresh.draft("post")); XCTAssertTrue(fresh.queue.isEmpty)
  }
  func testQueueCapacityDoesNotDiscardOlderUnsentMessages() async throws {
    let first = DurableCompositions(); first.configure(file:nil,owner:"owner")
    for n in 0..<50 { try await first.enqueue(QueuedMessage(nonce:String(n),roomID:"room",text:String(n),media:nil,replyID:nil)) }
    do { try await first.enqueue(QueuedMessage(nonce:"overflow",roomID:"room",text:"new",media:nil,replyID:nil)); XCTFail("Exceeded queue bound") } catch {}
    XCTAssertEqual(first.queue.count,50); XCTAssertEqual(first.queue.first?.text,"0")
  }
  func testWriteFailureNeverClaimsMessageQueued() async throws {
    let directory = file().deletingLastPathComponent(); try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    defer { try? FileManager.default.removeItem(at:directory) }
    let first = DurableCompositions(); first.configure(file:directory,owner:"owner")
    do { try await first.enqueue(QueuedMessage(nonce:"one",roomID:"room",text:"hello",media:nil,replyID:nil)); XCTFail("Directory write succeeded") } catch {}
    XCTAssertTrue(first.queue.isEmpty)
  }
}

extension DurableCompositionsTests {
  func testStaleComposerCannotSaveOrDiscardReplacementAccountsDraft() async throws {
    let drafts=DurableCompositions();drafts.configure(file:nil,owner:"old")
    let old=CompositionDraft(text:"old private text",nonce:"old-nonce",hasContent:true)
    await drafts.saveDraft(old,key:"group-create",owner:"old")
    drafts.reset(owner:"new")
    let replacement=CompositionDraft(text:"replacement draft",nonce:"new-nonce",hasContent:true)
    let newSaved=await drafts.saveDraft(replacement,key:"group-create",owner:"new");XCTAssertTrue(newSaved)
    let oldSaved=await drafts.saveDraft(old,key:"group-create",owner:"old");XCTAssertFalse(oldSaved)
    await drafts.removeDraft("group-create",owner:"old")
    XCTAssertEqual(drafts.draft("group-create")?.text,"replacement draft")
    XCTAssertEqual(drafts.draft("group-create")?.nonce,"new-nonce")
    await drafts.removeDraft("group-create",owner:"new");XCTAssertNil(drafts.draft("group-create"))
  }
  func testGroupCreationRecoveryRestoresPhotosAndPartialInvitationAcknowledgements() async throws {
    let file=file();defer{try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
    let drafts=DurableCompositions();drafts.configure(file:file,owner:"owner")
    let group=CompositionIdentity.image(Data([1,2]),identity:"group-photo")
    let member=CompositionIdentity.image(Data([3,4]),identity:"member-photo")
    let fields=["createdID":"existing-room","creationKey":"unchanged-payload","step":"2","alias":"Room nickname","invited":"[\"already_invited\"]","failures":"{\"retry_user\":\"Network failed\"}","groupPhotoSaved":"true","memberPhotoSaved":"false"]
    let saved=await drafts.saveDraft(CompositionDraft(media:group,additionalMedia:[member],fields:fields,nonce:"creation-nonce",hasContent:true),key:"group-create")
    XCTAssertTrue(saved)
    let restored=DurableCompositions();restored.configure(file:file,owner:"owner")
    let value=try XCTUnwrap(restored.draft("group-create"))
    XCTAssertEqual(value.media,group);XCTAssertEqual(value.additionalMedia,[member]);XCTAssertEqual(value.fields,fields)
    XCTAssertEqual(value.nonce,"creation-nonce");XCTAssertEqual(value.mediaBytes,4)
  }
  func testRequestScopesAndFingerprintsCannotReuseDifferentRecipientOrContent() {
    XCTAssertNotEqual(CompositionIdentity.requestKey(scope:.post("post-one"),initialUsername:""),CompositionIdentity.requestKey(scope:.post("post-two"),initialUsername:""))
    XCTAssertNotEqual(CompositionIdentity.requestKey(scope:.post("same"),initialUsername:""),CompositionIdentity.requestKey(scope:.reply("same"),initialUsername:""))
    XCTAssertEqual(CompositionIdentity.requestKey(scope:.username,initialUsername:" @Aggie "),"request:named:aggie")
    let a=CompositionIdentity.signature(MessageRequestScope.username.payload(text:"Hello",username:"first_user",nonce:""))
    let b=CompositionIdentity.signature(MessageRequestScope.username.payload(text:"Hello",username:"second_user",nonce:""))
    let c=CompositionIdentity.signature(MessageRequestScope.username.payload(text:"Changed",username:"first_user",nonce:""))
    XCTAssertNotEqual(a,b);XCTAssertNotEqual(a,c)
    XCTAssertEqual(CompositionIdentity.signature(["b":2,"a":1]),CompositionIdentity.signature(["a":1,"b":2]))
    XCTAssertEqual(CompositionIdentity.image(Data([1]),identity:"meme-photo"),CompositionIdentity.image(Data([1]),identity:"meme-photo"),"Recomputing a binding must not invent a new attachment identity")
  }
  func testReplyRequestAndMemeRestorationStayScopedAndExplicitDiscardPersists() async throws {
    let file=file();defer{try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
    let first=DurableCompositions();first.configure(file:file,owner:"owner")
    let reply=CompositionDraft(text:"Nested draft",fields:["parentID":"original-parent","anonymous":"true","submissionKey":"unchanged"],nonce:"reply-send",hasContent:true)
    let request=CompositionDraft(text:"Private request",fields:["username":"same_recipient","submissionKey":"request-input"],nonce:"request-send",hasContent:true)
    let meme=CompositionDraft(text:"Top caption",media:CompositionIdentity.image(Data([1,2,3]),identity:"meme-photo"),fields:["bottom":"Bottom caption","template":"maroon","allCaps":"false"],nonce:"meme",hasContent:true)
    await first.saveDraft(reply,key:"reply:original-post")
    await first.saveDraft(request,key:"request:reply:original-parent")
    await first.saveDraft(meme,key:"meme:message:original-room")
    let second=DurableCompositions();second.configure(file:file,owner:"owner")
    XCTAssertEqual(second.draft("reply:original-post")?.fields,reply.fields)
    XCTAssertEqual(second.draft("request:reply:original-parent")?.nonce,"request-send")
    XCTAssertEqual(second.draft("meme:message:original-room")?.media,meme.media)
    XCTAssertNil(second.draft("reply:different-post"));XCTAssertNil(second.draft("meme:message:different-room"))
    await second.removeDraft("reply:original-post",owner:"owner")
    let third=DurableCompositions();third.configure(file:file,owner:"owner")
    XCTAssertNil(third.draft("reply:original-post"));XCTAssertNotNil(third.draft("request:reply:original-parent"))
  }
}
