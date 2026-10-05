import XCTest
import MaroonCore
@testable import MaroonSocial

@MainActor final class RepostTests: XCTestCase {
  private func store() throws -> (AppStore, URL) {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appending(path: "posts.json")
    let store = AppStore(storageURL: file, arguments: []); store.enter(username: "repost_tester")
    return (store, file)
  }
  func testPostsCachedBeforeRepostsDecodeWithoutQuoteOrCount() throws {
    let legacy = Data(#"{"id":"legacy","author":"Aggie","anonymous":true,"community":"Texas A&M","text":"Old post","score":1,"vote":0,"comments":[],"created":100,"saved":false,"acceptsDM":false}"#.utf8)
    let decoded = try JSONDecoder().decode(Post.self, from: legacy)
    XCTAssertNil(decoded.quote); XCTAssertEqual(decoded.repostCount, 0)
    let server = JSONDecoder(); server.dateDecodingStrategy = .secondsSince1970
    let projected = Data(#"{"id":"p","author":"Anonymous","anonymous":true,"community":"Texas A&M","text":"","score":1,"vote":1,"comments":[],"created":1700000000,"saved":false,"acceptsDM":true,"repostCount":2,"quote":{"id":"q","unavailable":false,"author":"Anonymous","anonymous":true,"community":"Texas A&M","text":"Quoted body","created":1699999000,"attachmentID":null}}"#.utf8)
    let post = try server.decode(Post.self, from: projected)
    XCTAssertEqual(post.repostCount, 2); XCTAssertEqual(post.quote?.text, "Quoted body"); XCTAssertEqual(post.quote?.created, Date(timeIntervalSince1970: 1_699_999_000))
    XCTAssertEqual(post.quote?.displayName, "Anonymous")
    let gone = try server.decode(Post.self, from: Data(#"{"id":"p2","author":"a","anonymous":false,"community":"NSFW","text":"x","score":0,"vote":0,"comments":[],"created":1,"saved":false,"acceptsDM":false,"repostCount":0,"quote":{"id":"missing","unavailable":true}}"#.utf8))
    XCTAssertEqual(gone.quote, PostQuote(id: "missing", unavailable: true))
    XCTAssertEqual(try JSONDecoder().decode(Post.self, from: JSONEncoder().encode(post)), post, "Local caches round-trip the quote with the default date strategy.")
  }
  func testFixtureQuoteCarriesTheSourceAndBumpsItsRepostCount() async throws {
    let (store, file) = try store()
    let source = try XCTUnwrap(store.state.posts.first { $0.id == "demo-coffee-post" })
    XCTAssertEqual(source.repostCount, 1, "The seeded quote post counts against its source")
    XCTAssertTrue(store.state.posts.contains { $0.quote?.id == "demo-coffee-post" && $0.quote?.unavailable == false })
    XCTAssertTrue(store.state.posts.contains { $0.id == "demo-missing-quote-post" && $0.quote?.unavailable == true })
    let created = await store.createPost(text: "", anonymous: true, community: .campus, acceptsDM: true, quoting: "demo-coffee-post")
    XCTAssertTrue(created)
    let post = try XCTUnwrap(store.state.posts.first)
    XCTAssertEqual(post.text, ""); XCTAssertEqual(post.quote?.id, "demo-coffee-post"); XCTAssertEqual(post.quote?.unavailable, false)
    XCTAssertEqual(post.quote?.text, source.text); XCTAssertEqual(post.quote?.author, "demo-espresso"); XCTAssertEqual(post.quote?.displayName, "@demo-espresso")
    XCTAssertEqual(store.state.posts.first { $0.id == "demo-coffee-post" }?.repostCount, 2)
    let restored = AppStore(storageURL: file, arguments: [])
    XCTAssertEqual(restored.state.posts.first, post)
    XCTAssertEqual(restored.state.posts.first { $0.id == "demo-coffee-post" }?.repostCount, 2)
  }
  func testQuotingDeletedOrMissingPostsYieldsUnavailableWithoutCounting() async throws {
    let (store, _) = try store()
    var tombstone = Post(id: "gone", author: "demo-x", text: "Removed"); tombstone.deleted = true
    store.state.posts.append(tombstone)
    let tombstoned = await store.createPost(text: "Quoting a tombstone", anonymous: true, community: .campus, acceptsDM: false, quoting: "gone")
    XCTAssertTrue(tombstoned)
    XCTAssertEqual(store.state.posts.first?.quote, PostQuote(id: "gone", unavailable: true))
    XCTAssertEqual(store.state.posts.first { $0.id == "gone" }?.repostCount, 0)
    let missing = await store.createPost(text: "Quoting nothing", anonymous: true, community: .campus, acceptsDM: false, quoting: "never-existed")
    XCTAssertTrue(missing)
    XCTAssertEqual(store.state.posts.first?.quote, PostQuote(id: "never-existed", unavailable: true))
    XCTAssertEqual(PostQuote(quoting: tombstone), PostQuote(id: "gone", unavailable: true))
  }
  func testValidationAcceptsAnEmptyBodyOnlyWhenSomethingIsQuoted() throws {
    XCTAssertThrowsError(try PostFeatureRules.validate(text: " \n")) { XCTAssertEqual($0 as? PostFeatureError, .empty) }
    XCTAssertEqual(try PostFeatureRules.validate(text: " \n", hasQuote: true).text, "")
    XCTAssertThrowsError(try PostFeatureRules.validate(text: String(repeating: "a", count: 1001), hasQuote: true)) { XCTAssertEqual($0 as? PostFeatureError, .textTooLong) }
    XCTAssertEqual(try PostFeatureRules.validate(text: "Agree", tags: ["#Chem"], hasQuote: true).tags, ["chem"])
  }
  func testQuoteOfAQuoteCarriesTheQuotesFlagAndOldCachesDecodeWithoutIt() throws {
    var source = Post(author: "demo-a", text: "")
    source.quote = PostQuote(id: "earlier", unavailable: true)
    XCTAssertEqual(PostQuote(quoting: source).quotes, true)
    XCTAssertEqual(PostQuote(quoting: Post(author: "demo-b", text: "Plain")).quotes, false)
    let legacy = Data(#"{"id":"q1","unavailable":false,"author":"a","anonymous":false,"text":"hi"}"#.utf8)
    XCTAssertNil(try JSONDecoder().decode(PostQuote.self, from: legacy).quotes)
  }
}
