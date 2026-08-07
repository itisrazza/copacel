import Foundation

/// An immutable snapshot of a file or directory produced by ``DirectoryScanner``.
///
/// Sizes and ``fileCount`` are aggregated bottom-up at scan time, so reading
/// them is O(1) — nothing needs to walk `children` again.
public struct FileNode: Identifiable, Sendable {
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let isSymbolicLink: Bool
    public let logicalSize: Int64
    public let physicalSize: Int64
    public let children: [FileNode]
    public let fileCount: Int

    public init(
        url: URL,
        name: String,
        isDirectory: Bool,
        isSymbolicLink: Bool,
        logicalSize: Int64,
        physicalSize: Int64,
        children: [FileNode],
        fileCount: Int
    ) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.isSymbolicLink = isSymbolicLink
        self.logicalSize = logicalSize
        self.physicalSize = physicalSize
        self.children = children
        self.fileCount = fileCount
    }

    public var id: URL { url }

    public var fileExtension: String? {
        guard !isDirectory, !isSymbolicLink else { return nil }
        let ext = url.pathExtension
        return ext.isEmpty ? nil : ext.lowercased()
    }
}

extension FileNode: Equatable, Hashable {
    // `url` (== `id`) is unique per scan, so identity-based conformances are both
    // correct and far cheaper than the synthesized structural ones, which would
    // otherwise deep-compare/hash entire subtrees on every SwiftUI selection change.
    public static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs.url == rhs.url }

    public func hash(into hasher: inout Hasher) { hasher.combine(url) }
}
