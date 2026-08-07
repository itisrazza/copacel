import CoreGraphics

/// Squarified treemap layout (Bruls, Huizing, van Wijk, 2000).
///
/// Generic over `Item` so it has no dependency on ``FileNode`` — callers
/// decide what "size" means (physical vs. logical bytes) via the `size`
/// closure.
public enum TreemapLayout {
    public static func squarify<Item>(
        items: [Item],
        size: (Item) -> Double,
        in rect: CGRect
    ) -> [(item: Item, rect: CGRect)] {
        let positiveItems = items
            .map { (item: $0, size: max(size($0), 0)) }
            .filter { $0.size > 0 }
            .sorted { $0.size > $1.size }

        guard !positiveItems.isEmpty, rect.width > 0, rect.height > 0 else { return [] }

        let totalSize = positiveItems.reduce(0) { $0 + $1.size }
        let totalArea = Double(rect.width) * Double(rect.height)
        guard totalSize > 0 else { return [] }
        let scale = totalArea / totalSize

        var results: [(item: Item, rect: CGRect)] = []
        var remaining = ArraySlice(positiveItems)
        var container = rect

        while !remaining.isEmpty {
            let rowCount = bestRowCount(in: remaining, scale: scale, shortSide: min(container.width, container.height))
            let row = remaining.prefix(rowCount).map { (item: $0.item, area: $0.size * scale) }
            remaining = remaining.dropFirst(rowCount)
            container = layout(row: row, in: container, appendingTo: &results)
        }

        return results
    }

    /// Grows a row one item at a time while the worst aspect ratio in the row keeps improving.
    /// Once it stops improving it only gets worse from there (given descending-sorted sizes), so
    /// we can stop at the first regression instead of scanning every possible row length.
    private static func bestRowCount<Item>(
        in remaining: ArraySlice<(item: Item, size: Double)>,
        scale: Double,
        shortSide: CGFloat
    ) -> Int {
        var best = 1
        var bestRatio = Double.infinity
        var rowAreas: [Double] = []

        for count in 1...remaining.count {
            let area = remaining[remaining.startIndex + count - 1].size * scale
            rowAreas.append(area)
            let ratio = worstAspectRatio(areas: rowAreas, shortSide: Double(shortSide))
            guard ratio <= bestRatio else { break }
            bestRatio = ratio
            best = count
        }
        return best
    }

    private static func worstAspectRatio(areas: [Double], shortSide: Double) -> Double {
        guard shortSide > 0, let maxArea = areas.max(), let minArea = areas.min(), minArea > 0 else {
            return .infinity
        }
        let sum = areas.reduce(0, +)
        let sideSquared = shortSide * shortSide
        return max(
            (sideSquared * maxArea) / (sum * sum),
            (sum * sum) / (sideSquared * minArea)
        )
    }

    /// Lays out one row as a strip along the container's shorter side, then returns the
    /// remaining rect with that strip removed.
    private static func layout<Item>(
        row: [(item: Item, area: Double)],
        in rect: CGRect,
        appendingTo results: inout [(item: Item, rect: CGRect)]
    ) -> CGRect {
        let rowTotalArea = row.reduce(0) { $0 + $1.area }

        if rect.width >= rect.height {
            let stripWidth = rect.height > 0 ? CGFloat(rowTotalArea / Double(rect.height)) : 0
            var y = rect.minY
            for entry in row {
                let height = stripWidth > 0 ? CGFloat(entry.area) / stripWidth : 0
                results.append((entry.item, CGRect(x: rect.minX, y: y, width: stripWidth, height: height)))
                y += height
            }
            return CGRect(x: rect.minX + stripWidth, y: rect.minY, width: rect.width - stripWidth, height: rect.height)
        } else {
            let stripHeight = rect.width > 0 ? CGFloat(rowTotalArea / Double(rect.width)) : 0
            var x = rect.minX
            for entry in row {
                let width = stripHeight > 0 ? CGFloat(entry.area) / stripHeight : 0
                results.append((entry.item, CGRect(x: x, y: rect.minY, width: width, height: stripHeight)))
                x += width
            }
            return CGRect(x: rect.minX, y: rect.minY + stripHeight, width: rect.width, height: rect.height - stripHeight)
        }
    }
}
