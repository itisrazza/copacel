public enum FileSortKey: Sendable {
    case name
    case physicalSize
    case logicalSize
    case fileCount
}

extension FileNode {
    /// Returns a copy of this tree with `children` recursively sorted at every level —
    /// SwiftUI's `OutlineGroup` reads each level's stored order as-is, so the whole tree
    /// needs to already be in the desired order rather than sorted lazily per row.
    public func sorted(by key: FileSortKey, ascending: Bool) -> FileNode {
        let sortedChildren = children
            .map { $0.sorted(by: key, ascending: ascending) }
            .sorted { lhs, rhs in
                // Swap operands (rather than negating) for descending order, so ties
                // still satisfy the strict-weak-ordering `sorted(by:)` requires.
                ascending ? Self.isLess(lhs, rhs, by: key) : Self.isLess(rhs, lhs, by: key)
            }

        return FileNode(
            url: url, name: name, isDirectory: isDirectory, isSymbolicLink: isSymbolicLink,
            logicalSize: logicalSize, physicalSize: physicalSize, children: sortedChildren, fileCount: fileCount
        )
    }

    private static func isLess(_ a: FileNode, _ b: FileNode, by key: FileSortKey) -> Bool {
        switch key {
        case .name: a.name.localizedStandardCompare(b.name) == .orderedAscending
        case .physicalSize: a.physicalSize < b.physicalSize
        case .logicalSize: a.logicalSize < b.logicalSize
        case .fileCount: a.fileCount < b.fileCount
        }
    }
}
