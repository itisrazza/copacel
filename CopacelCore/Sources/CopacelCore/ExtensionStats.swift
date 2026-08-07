public struct ExtensionStat: Identifiable, Sendable, Hashable {
    /// Lowercased extension, or `""` for files with no extension.
    public let fileExtension: String
    public let fileCount: Int
    public let totalLogicalSize: Int64
    public let totalPhysicalSize: Int64

    public var id: String { fileExtension }
}

public enum ExtensionStats {
    /// Aggregates every file (not directory) in `node`'s subtree by extension.
    public static func aggregate(from node: FileNode) -> [ExtensionStat] {
        var totals: [String: (count: Int, logical: Int64, physical: Int64)] = [:]

        func visit(_ node: FileNode) {
            if !node.isDirectory {
                let key = node.fileExtension ?? ""
                var entry = totals[key] ?? (0, 0, 0)
                entry.count += 1
                entry.logical += node.logicalSize
                entry.physical += node.physicalSize
                totals[key] = entry
            }
            for child in node.children {
                visit(child)
            }
        }
        visit(node)

        return totals
            .map { ExtensionStat(fileExtension: $0.key, fileCount: $0.value.count, totalLogicalSize: $0.value.logical, totalPhysicalSize: $0.value.physical) }
            .sorted { $0.totalPhysicalSize > $1.totalPhysicalSize }
    }
}
