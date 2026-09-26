import Foundation

extension FileNode {
    /// Returns a copy of this tree with the node at `target` (and its whole subtree, if it's
    /// a directory) removed, and every ancestor's size/fileCount recomputed — so a delete can
    /// update the in-memory tree without a full rescan. Returns `nil` if `target` is this node.
    public func removing(url target: URL) -> FileNode? {
        guard url != target else { return nil }
        guard isDirectory, !children.isEmpty else { return self }

        let newChildren = children.compactMap { $0.removing(url: target) }
        return FileNode(
            url: url,
            name: name,
            isDirectory: isDirectory,
            isSymbolicLink: isSymbolicLink,
            logicalSize: newChildren.reduce(0) { $0 + $1.logicalSize },
            physicalSize: newChildren.reduce(0) { $0 + $1.physicalSize },
            children: newChildren,
            fileCount: newChildren.reduce(0) { $0 + $1.fileCount },
            readFailure: readFailure
        )
    }
}
