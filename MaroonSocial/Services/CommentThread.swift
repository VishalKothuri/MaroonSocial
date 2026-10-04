import Foundation
import MaroonCore

/// Converts a flat snapshot into a stable depth-first thread without changing
/// its comments or inventing data about a filtered/blocked parent.
enum CommentThread {
  struct Row: Identifiable, Equatable {
    let comment: Comment
    /// Logical depth. The view caps visual indentation without losing lineage.
    let depth: Int
    let isOrphan: Bool
    let isCycleRoot: Bool
    var id: String { comment.id }
  }

  static func flatten(_ comments: [Comment]) -> [Row] {
    var unique: [String: Comment] = [:]
    for comment in comments {
      // A duplicate tombstone must not resurrect stale content. Otherwise the
      // first snapshot entry is canonical; there is no edit timestamp to guess.
      if let previous = unique[comment.id] {
        if comment.deleted == true && previous.deleted != true { unique[comment.id] = comment }
      } else { unique[comment.id] = comment }
    }
    func precedes(_ left: String, _ right: String) -> Bool {
      let lhs = unique[left]!, rhs = unique[right]!
      return lhs.created == rhs.created ? left < right : lhs.created < rhs.created
    }
    let ordered = unique.keys.sorted(by: precedes)
    var parents: [String: String] = [:]
    var orphans = Set<String>()
    for id in ordered {
      if let parent = unique[id]?.parentID {
        if unique[parent] != nil { parents[id] = parent }
        else { orphans.insert(id) }
      }
    }

    // Each node has at most one parent. Walk those chains iteratively and break
    // only a cycle's oldest edge. This keeps all descendants and avoids recursion
    // over malformed or very deep cached data. Original parentID stays untouched.
    var completed = Set<String>(), cycleRoots = Set<String>()
    for seed in ordered where !completed.contains(seed) {
      var path: [String] = [], positions: [String: Int] = [:]
      var cursor: String? = seed
      while let id = cursor, !completed.contains(id) {
        if let index = positions[id] {
          let root = path[index...].min(by: precedes)!
          parents.removeValue(forKey: root)
          cycleRoots.insert(root)
          break
        }
        positions[id] = path.count
        path.append(id)
        cursor = parents[id]
      }
      completed.formUnion(path)
    }

    var children: [String: [String]] = [:], roots: [String] = []
    for id in ordered {
      if let parent = parents[id] { children[parent, default: []].append(id) }
      else { roots.append(id) }
    }
    var stack = roots.reversed().map { (id: $0, depth: 0) }
    var rows: [Row] = []
    rows.reserveCapacity(unique.count)
    while let entry = stack.popLast() {
      rows.append(Row(comment: unique[entry.id]!, depth: entry.depth,
                      isOrphan: orphans.contains(entry.id), isCycleRoot: cycleRoots.contains(entry.id)))
      for child in (children[entry.id] ?? []).reversed() {
        stack.append((id: child, depth: entry.depth + 1))
      }
    }
    return rows
  }
}
