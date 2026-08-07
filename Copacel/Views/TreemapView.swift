import CopacelCore
import SwiftUI

struct TreemapView: View {
    var root: FileNode
    var selection: FileNode?
    var highlightedExtension: String?
    var onSelect: (FileNode) -> Void
    var onDrillDown: (FileNode) -> Void

    @State private var hoveredTile: TreemapTile?

    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(origin: .zero, size: geometry.size)
            let tiles = TreemapLayout.recursiveTiles(for: root, in: rect)

            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for tile in tiles {
                        draw(tile: tile, in: &context)
                    }
                }
                .gesture(
                    SpatialTapGesture(count: 2)
                        .onEnded { value in
                            if let tile = tile(at: value.location, in: tiles), tile.node.isDirectory {
                                onDrillDown(tile.node)
                            }
                        }
                        .exclusively(before: SpatialTapGesture(count: 1)
                            .onEnded { value in
                                if let tile = tile(at: value.location, in: tiles) {
                                    onSelect(tile.node)
                                }
                            }
                        )
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        hoveredTile = tile(at: location, in: tiles)
                    case .ended:
                        hoveredTile = nil
                    }
                }

                if let hoveredTile {
                    tooltip(for: hoveredTile)
                        .offset(
                            x: min(max(hoveredTile.rect.midX - 60, 4), geometry.size.width - 124),
                            y: max(hoveredTile.rect.minY - 30, 4)
                        )
                }
            }
        }
        .background(Color.black.opacity(0.05))
    }

    private func draw(tile: TreemapTile, in context: inout GraphicsContext) {
        let color = ColorAssignment.color(forExtension: tile.node.fileExtension ?? "")
        let isSelected = selection?.id == tile.node.id
        let isDimmed = highlightedExtension != nil && highlightedExtension != (tile.node.fileExtension ?? "")
        let path = Path(tile.rect.insetBy(dx: 0.5, dy: 0.5))
        context.opacity = isDimmed ? 0.25 : 1
        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(isSelected ? .white : .black.opacity(0.35)), lineWidth: isSelected ? 2 : 0.5)
        context.opacity = 1
    }

    private func tile(at point: CGPoint, in tiles: [TreemapTile]) -> TreemapTile? {
        tiles.first { $0.rect.contains(point) }
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
