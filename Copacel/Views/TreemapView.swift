import CopacelCore
import SwiftUI

struct TreemapView: View {
    var root: FileNode
    var selection: FileNode?
    var highlightedExtension: String?
    var onSelect: (FileNode) -> Void
    var onDrillDown: (FileNode) -> Void
    var onRequestDelete: (FileNode) -> Void

    var body: some View {
        // The tiling depends on the available size, but it's far too expensive to redo per
        // body evaluation, so it's cached in the child's state rather than computed here.
        GeometryReader { geometry in
            TreemapContentView(
                root: root,
                viewSize: geometry.size,
                selection: selection,
                highlightedExtension: highlightedExtension,
                onSelect: onSelect,
                onDrillDown: onDrillDown,
                onRequestDelete: onRequestDelete
            )
        }
        .background(Color.black.opacity(0.05))
    }
}

/// The inputs that actually invalidate the tiling. Hover, selection and the legend
/// highlight deliberately aren't part of it — they change the overlay, not the layout, and
/// must never trigger a relayout. Size and file count stand in for the tree's contents, so
/// trashing a file still re-tiles without deep-comparing the whole tree.
private struct TreemapLayoutRequest: Equatable {
    let rootURL: URL
    let rootPhysicalSize: Int64
    let rootFileCount: Int
    let viewSize: CGSize

    init(root: FileNode, viewSize: CGSize) {
        self.rootURL = root.url
        self.rootPhysicalSize = root.physicalSize
        self.rootFileCount = root.fileCount
        self.viewSize = viewSize
    }
}

/// A computed tiling, tagged with a generation so SwiftUI can tell one layout from the next
/// in O(1) instead of comparing thousands of tiles.
private struct TreemapTiling: Equatable {
    var tiles: [TreemapTile] = []
    var generation = 0

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.generation == rhs.generation }

    func replaced(with tiles: [TreemapTile]) -> Self {
        TreemapTiling(tiles: tiles, generation: generation + 1)
    }
}

/// `nonisolated` so the tiling runs on the global executor rather than the main actor, while
/// still inheriting cancellation from the `task(id:)` awaiting it — a resize that supersedes
/// an in-flight layout stops it rather than leaving it to finish for nothing.
private nonisolated func computeTiles(for root: FileNode, in rect: CGRect) async -> [TreemapTile] {
    TreemapLayout.recursiveTiles(for: root, in: rect)
}

private struct TreemapContentView: View {
    var root: FileNode
    var viewSize: CGSize
    var selection: FileNode?
    var highlightedExtension: String?
    var onSelect: (FileNode) -> Void
    var onDrillDown: (FileNode) -> Void
    var onRequestDelete: (FileNode) -> Void

    @State private var tiling = TreemapTiling()
    @State private var hoveredTile: TreemapTile?

    var body: some View {
        ZStack(alignment: .topLeading) {
            TreemapTileCanvas(tiling: tiling, highlightedExtension: highlightedExtension)
                .equatable()
                .gesture(tileGesture)
                .onContinuousHover(perform: updateHover)
                .contextMenu {
                    // Canvas has no per-shape hit testing for context menus, so this acts on
                    // whichever tile the continuous-hover tracking last saw the cursor over.
                    if let hoveredTile {
                        fileContextMenu(for: hoveredTile.node, requestDelete: onRequestDelete)
                    }
                }

            // The selection outline is a separate layer so that picking or hovering a tile
            // repaints two rectangles instead of every tile in the treemap.
            Canvas { context, _ in
                guard let tile = selectedTile else { return }
                context.stroke(
                    Path(tile.rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(.white), lineWidth: 2)
            }
            .allowsHitTesting(false)

            if let hoveredTile {
                tooltip(for: hoveredTile)
                    .offset(
                        x: min(max(hoveredTile.rect.midX - 60, 4), viewSize.width - 124),
                        y: max(hoveredTile.rect.minY - 30, 4)
                    )
                    // Without this the tooltip steals the hover it was created by, which
                    // ends the hover, which removes the tooltip, in a loop.
                    .allowsHitTesting(false)
            }
        }
        .task(id: TreemapLayoutRequest(root: root, viewSize: viewSize)) {
            await relayout()
        }
    }

    private func relayout() async {
        let rect = CGRect(origin: .zero, size: viewSize)
        guard rect.width > 0, rect.height > 0 else {
            tiling = tiling.replaced(with: [])
            return
        }
        let tiles = await computeTiles(for: root, in: rect)
        guard !Task.isCancelled else { return }
        tiling = tiling.replaced(with: tiles)
        // The old tile's rect no longer means anything against the new layout.
        hoveredTile = nil
    }

    private var selectedTile: TreemapTile? {
        guard let selection else { return nil }
        return tiling.tiles.first { $0.node.url == selection.url }
    }

    private var tileGesture: some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                if let tile = tile(at: value.location), tile.node.isDirectory {
                    onDrillDown(tile.node)
                }
            }
            .exclusively(before: SpatialTapGesture(count: 1)
                .onEnded { value in
                    if let tile = tile(at: value.location) {
                        onSelect(tile.node)
                    }
                }
            )
    }

    private func updateHover(_ phase: HoverPhase) {
        switch phase {
        case .active(let location):
            // Only write state when the tile under the cursor actually changes — a raw
            // mouse-move stream would otherwise invalidate the view on every event.
            let tile = tile(at: location)
            if tile?.id != hoveredTile?.id {
                hoveredTile = tile
            }
        case .ended:
            if hoveredTile != nil {
                hoveredTile = nil
            }
        }
    }

    private func tile(at point: CGPoint) -> TreemapTile? {
        tiling.tiles.first { $0.rect.contains(point) }
    }

    private func tooltip(for tile: TreemapTile) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tile.node.name).font(.caption.bold()).lineLimit(1)
            Text(tile.node.physicalSize, format: .byteCount(style: .file)).font(.caption2)
        }
        .padding(6)
        .frame(width: 120, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .shadow(radius: 2)
    }
}

/// Draws the tiles themselves. Wrapped in `.equatable()` by its caller so SwiftUI skips the
/// redraw entirely unless the tiling or the legend highlight changed.
private struct TreemapTileCanvas: View, Equatable {
    let tiling: TreemapTiling
    let highlightedExtension: String?

    // `nonisolated` because `View` is main-actor isolated, and SwiftUI compares views
    // outside that isolation.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tiling == rhs.tiling && lhs.highlightedExtension == rhs.highlightedExtension
    }

    var body: some View {
        Canvas { context, _ in
            for tile in tiling.tiles {
                draw(tile: tile, in: &context)
            }
        }
    }

    private func draw(tile: TreemapTile, in context: inout GraphicsContext) {
        let color = ColorAssignment.color(forExtension: tile.node.fileExtension ?? "")
        let isDimmed = highlightedExtension != nil && highlightedExtension != (tile.node.fileExtension ?? "")
        context.opacity = isDimmed ? 0.25 : 1

        // A directory with hundreds of thousands of files can produce tiles just a few
        // points wide. Insetting/stroking those would eat the fill entirely, so below a
        // small size just fill the tile flush instead — better a borderless speck than
        // nothing visible at all.
        guard tile.rect.width >= 3, tile.rect.height >= 3 else {
            context.fill(Path(tile.rect), with: .color(color))
            context.opacity = 1
            return
        }

        let path = Path(tile.rect.insetBy(dx: 0.5, dy: 0.5))
        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 0.5)
        context.opacity = 1
    }
}
