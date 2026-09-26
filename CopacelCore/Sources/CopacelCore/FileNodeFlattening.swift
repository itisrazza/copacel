import Foundation

/// One row of a partially-expanded tree: a node plus how deep it sits, so a flat `List` can
/// draw the indentation an outline would otherwise handle.
public struct FlattenedNode: Identifiable, Sendable {
    public let node: FileNode
    public let depth: Int

    public init(node: FileNode, depth: Int) {
        self.node = node
        self.depth = depth
    }

    public var id: URL { node.url }

    /// Whether this row gets a disclosure control.
    public var isExpandable: Bool { node.isDirectory && !node.children.isEmpty }
}

extension FileNode {
    /// This node's descendants in display order, descending only into directories listed in
    /// `expandedURLs`.
    ///
    /// The tree is flattened here rather than handed to `OutlineGroup` because that type owns
    /// its expansion state privately: with it, nothing outside the list can open the path down
    /// to a particular node, and a row inside a collapsed parent doesn't exist to scroll to.
    public func flattenedChildren(expandedURLs: Set<URL>) -> [FlattenedNode] {
        var rows: [FlattenedNode] = []

        func visit(_ nodes: [FileNode], depth: Int) {
            for node in nodes {
                rows.append(FlattenedNode(node: node, depth: depth))
                guard expandedURLs.contains(node.url), !node.children.isEmpty else { continue }
                visit(node.children, depth: depth + 1)
            }
        }
        visit(children, depth: 0)

        return rows
    }

    /// Every directory URL between `root` and `target`, `root` included and `target` excluded —
    /// exactly the set that has to be expanded for `target` to become a visible row.
    ///
    /// Derived from the path components rather than by searching the tree, since a scanned
    /// node's URL is always its parent's URL plus one component. Returns `nil` when `target`
    /// isn't under `root`.
    public static func ancestorURLs(from root: URL, to target: URL) -> [URL]? {
        let rootComponents = root.pathComponents
        let targetComponents = target.pathComponents
        guard targetComponents.count > rootComponents.count,
              Array(targetComponents.prefix(rootComponents.count)) == rootComponents
        else {
            return nil
        }

        var ancestors = [root]
        var current = root
        // Every component except the last, which addresses `target` itself.
        for component in targetComponents[rootComponents.count..<(targetComponents.count - 1)] {
            current = current.appendingPathComponent(component)
            ancestors.append(current)
        }
        return ancestors
    }
}
