import XCTest
import MaroonCore
@testable import MaroonSocial

final class CommentThreadTests: XCTestCase {
  private func comment(_ id: String, parent: String? = nil, time: Double = 0, deleted: Bool = false) -> Comment {
    var value = Comment(author: deleted ? "" : "author_\(id)", text: deleted ? "" : "Reply \(id)")
    value.id = id; value.parentID = parent; value.created = Date(timeIntervalSince1970: time); value.deleted = deleted
    return value
  }
  func testParentsPrecedeChildrenWithChronologicalSiblingsAndStableRootOrder() {
    let input = [comment("new-child", parent: "first", time: 5), comment("second", time: 3),
                 comment("nested", parent: "old-child", time: 4), comment("first", time: 1),
                 comment("old-child", parent: "first", time: 2)]
    let rows = CommentThread.flatten(input)
    XCTAssertEqual(rows.map(\.id), ["first", "old-child", "nested", "new-child", "second"])
    XCTAssertEqual(rows.map(\.depth), [0, 1, 2, 1, 0])
    XCTAssertFalse(rows.contains { $0.isOrphan || $0.isCycleRoot })
    XCTAssertEqual(CommentThread.flatten(input.reversed()), rows, "Snapshot order must not reorder a thread")
  }
  func testDeletedParentRemainsAPlaceholderAndKeepsItsRepliesAttached() {
    let parent = comment("removed", time: 1, deleted: true)
    let child = comment("child", parent: "removed", time: 2)
    let rows = CommentThread.flatten([child, parent])
    XCTAssertEqual(rows.map(\.id), ["removed", "child"])
    XCTAssertEqual(rows.first?.comment, parent)
    XCTAssertEqual(rows.first?.comment.deleted, true)
    XCTAssertEqual(rows.last?.depth, 1)
    XCTAssertEqual(rows.last?.isOrphan, false)
  }
  func testMissingOrFilteredParentDoesNotCreateOrGuessAnIdentity() {
    let child = comment("visible", parent: "unavailable", time: 2)
    let grandchild = comment("descendant", parent: "visible", time: 3)
    let rows = CommentThread.flatten([grandchild, child])
    XCTAssertEqual(rows.map(\.id), ["visible", "descendant"])
    XCTAssertEqual(rows.map(\.depth), [0, 1])
    XCTAssertEqual(rows.map(\.isOrphan), [true, false])
    XCTAssertEqual(rows[0].comment.parentID, "unavailable")
    XCTAssertEqual(rows[0].comment, child, "Missing parent data must never be fabricated")
  }
  func testCyclesAndSelfReferencesKeepEveryCommentExactlyOnce() {
    let input = [comment("a", parent: "b", time: 3), comment("b", parent: "c", time: 2),
                 comment("c", parent: "a", time: 1), comment("child", parent: "a", time: 4),
                 comment("self", parent: "self", time: 5)]
    let rows = CommentThread.flatten(input)
    XCTAssertEqual(rows.map(\.id), ["c", "b", "a", "child", "self"])
    XCTAssertEqual(rows.map(\.depth), [0, 1, 2, 3, 0])
    XCTAssertEqual(rows.filter(\.isCycleRoot).map(\.id), ["c", "self"])
    XCTAssertEqual(Set(rows.map(\.id)).count, input.count)
    XCTAssertEqual(rows[0].comment.parentID, "a", "Presentation repair must preserve the original relationship")
    XCTAssertEqual(CommentThread.flatten(input.reversed()), rows)
  }
  func testDuplicateTombstoneCannotResurrectDeletedContent() {
    let stale = comment("parent", time: 1)
    let tombstone = comment("parent", time: 1, deleted: true)
    let child = comment("child", parent: "parent", time: 2)
    for input in [[stale, child, tombstone, stale], [tombstone, stale, child]] {
      let rows = CommentThread.flatten(input)
      XCTAssertEqual(rows.map(\.id), ["parent", "child"])
      XCTAssertEqual(rows[0].comment, tombstone)
      XCTAssertEqual(rows[1].depth, 1)
    }
  }
  func testDeepThreadIsIterativeAndKeepsFullRelationshipsForCappedVisualIndentation() {
    var input: [Comment] = []
    for index in 0..<5000 {
      let parent: String? = index == 0 ? nil : String(index - 1)
      input.append(comment(String(index), parent: parent, time: Double(index)))
    }
    input[4999].score = 12; input[4999].vote = -1
    let rows = CommentThread.flatten(input.reversed())
    XCTAssertEqual(rows.count, 5000)
    XCTAssertEqual(rows.last?.depth, 4999)
    XCTAssertEqual(rows.last?.comment.parentID, "4998")
    XCTAssertEqual(rows.last?.comment.score, 12)
    XCTAssertEqual(rows.last?.comment.vote, -1)
    XCTAssertEqual(rows.map { min(3, $0.depth) }.max(), 3, "The UI may cap indentation without truncating descendants")
  }
  func testEqualTimestampsUseIDsForStableSiblingOrderingAndEmptyInputIsSafe() {
    let root = comment("root")
    let a = comment("a", parent: "root"), b = comment("b", parent: "root")
    XCTAssertEqual(CommentThread.flatten([b, root, a]).map(\.id), ["root", "a", "b"])
    XCTAssertTrue(CommentThread.flatten([]).isEmpty)
  }
}
