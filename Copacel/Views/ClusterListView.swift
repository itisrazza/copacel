import CopacelCore
import SwiftUI

/// Ranks the folders holding the bulk of the scanned space.
///
/// Answers a question neither other pane does: the treemap shows individual files and the
/// file list shows hierarchy, but neither says *where the space actually sits* without a lot
/// of drilling.
struct ClusterListView: View {
    var clusters: [FileNode]
    var root: FileNode
    @Binding var selection: FileNode?
    var onDrillDown: (FileNode) -> Void
    var onRequestDelete: (FileNode) -> Void

    private var largestSize: Int64 { clusters.first?.physicalSize ?? 0 }

    var body: some View {
        if clusters.isEmpty {
            ContentUnavailableView(
                "No clusters to show",
                systemImage: "square.stack.3d.up.slash",
                description: Text("Everything here sits directly in this folder rather than in subfolders.")
            )
        } else {
            List(selection: $selection) {
                ForEach(Array(clusters.enumerated()), id: \.element.id) { index, cluster in
                    ClusterRowView(
                        rank: index + 1,
                        cluster: cluster,
                        root: root,
                        largestSize: largestSize
                    )
                    .tag(cluster)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { onDrillDown(cluster) }
                    .contextMenu { fileContextMenu(for: cluster, requestDelete: onRequestDelete) }
                }
            }
            .listStyle(.inset)
        }
    }
}

private struct ClusterRowView: View {
    var rank: Int
    var cluster: FileNode
    var root: FileNode
    var largestSize: Int64

    /// Bar is relative to the biggest cluster, not to the scan total — the point is comparing
    /// clusters with each other, and against the total they'd all be slivers.
    private var fraction: Double {
        largestSize > 0 ? Double(cluster.physicalSize) / Double(largestSize) : 0
    }

    /// The path below the scanned root, since repeating the root on every row tells you nothing.
    private var relativePath: String {
        let rootPath = root.url.path
        let path = cluster.url.path
        guard path.hasPrefix(rootPath) else { return path }
        let remainder = path.dropFirst(rootPath.count)
        return remainder.hasPrefix("/") ? String(remainder.dropFirst()) : String(remainder)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 20, alignment: .trailing)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(cluster.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(cluster.physicalSize, format: .byteCount(style: .file))
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(cluster.fileCount) files")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                Text(relativePath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)

                ClusterBar(fraction: fraction)
                    .frame(height: 4)
            }
        }
        .padding(.vertical, 3)
        .help(cluster.url.path)
    }
}

private struct ClusterBar: View {
    var fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(.quaternary)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.blue)
                    .frame(width: geometry.size.width * max(0, min(1, fraction)))
            }
        }
    }
}
