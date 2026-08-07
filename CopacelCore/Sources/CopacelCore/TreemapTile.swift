import CoreGraphics
import Foundation

/// One rendered leaf in a recursively-laid-out treemap: a file, an empty directory, or a
/// directory whose subtree became too small to keep subdividing.
public struct TreemapTile: Identifiable, Sendable {
    public let node: FileNode
    public let rect: CGRect
    public let depth: Int

    public var id: URL { node.url }
}

extension TreemapLayout {
    /// Recursively subdivides `node`'s subtree into leaf tiles: each directory's rect is
    /// squarified among its own children, which are in turn subdivided the same way, down
    /// to actual files. Directory boundaries aren't drawn separately — a small inset is
    /// applied at each level instead, which reads as a grouping gap between clusters.
    public static func recursiveTiles(
        for node: FileNode,
        sizeKeyPath: KeyPath<FileNode, Int64> = \.physicalSize,
        in rect: CGRect,
        depth: Int = 0,
        minTileArea: Double = 4,
        maxDepth: Int = 48
    ) -> [TreemapTile] {
        guard rect.width > 0, rect.height > 0 else { return [] }

        guard node.isDirectory, !node.children.isEmpty, depth < maxDepth else {
            return [TreemapTile(node: node, rect: rect, depth: depth)]
        }

        let innerRect = depth > 0 ? rect.insetBy(dx: 1, dy: 1) : rect
        guard innerRect.width > 0, innerRect.height > 0 else {
            return [TreemapTile(node: node, rect: rect, depth: depth)]
        }

        let placements = squarify(items: node.children, size: { Double($0[keyPath: sizeKeyPath]) }, in: innerRect)

        return placements.flatMap { placement -> [TreemapTile] in
            let area = Double(placement.rect.width) * Double(placement.rect.height)
            guard area >= minTileArea else { return [] }
            return recursiveTiles(
                for: placement.item, sizeKeyPath: sizeKeyPath, in: placement.rect,
                depth: depth + 1, minTileArea: minTileArea, maxDepth: maxDepth
            )
        }
    }
}
