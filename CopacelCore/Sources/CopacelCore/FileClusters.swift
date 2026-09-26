import Foundation

extension FileNode {
    /// The directories where this subtree's space actually sits, largest first.
    ///
    /// Ranking directories by size alone is useless — every ancestor of a big folder outranks
    /// it, so the list just restates one path. A directory is treated as a cluster only when
    /// its space is *spread across* its contents rather than concentrated in a single
    /// subdirectory; otherwise the search descends into the child that actually holds it. So
    /// a games folder whose weight is one disc directory reports the disc directory, while a
    /// samples folder spread over hundreds of subfolders reports itself.
    ///
    /// - Parameters:
    ///   - limit: How many to return.
    ///   - concentration: The share a single subdirectory must hold *more than* for the
    ///     search to descend into it instead of stopping. At the default, two children
    ///     splitting a directory evenly leaves neither dominant, so the parent is reported.
    ///   - maxDepth: A depth past which a directory is reported whether or not it's
    ///     concentrated, so a deep chain still yields something.
    public func largestClusters(
        limit: Int = 25,
        concentration: Double = 0.5,
        maxDepth: Int = 10
    ) -> [FileNode] {
        var clusters: [FileNode] = []

        func isCluster(_ node: FileNode, depth: Int) -> Bool {
            guard depth < maxDepth else { return true }
            let largestSubdirectory = node.children
                .lazy
                .filter(\.isDirectory)
                .map(\.physicalSize)
                .max() ?? 0
            return Double(largestSubdirectory) <= concentration * Double(node.physicalSize)
        }

        func visit(_ node: FileNode, depth: Int) {
            guard node.isDirectory, node.physicalSize > 0 else { return }

            // The scan root is never itself a cluster — it's the thing being broken down.
            if depth > 0, isCluster(node, depth: depth) {
                clusters.append(node)
                return
            }
            for child in node.children {
                visit(child, depth: depth + 1)
            }
        }
        visit(self, depth: 0)

        return Array(clusters.sorted { $0.physicalSize > $1.physicalSize }.prefix(limit))
    }
}
