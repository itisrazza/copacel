import CopacelCore
import SwiftUI

enum FileListColumns {
    static let bar: CGFloat = 120
    static let percentage: CGFloat = 64
    static let size: CGFloat = 90
    static let count: CGFloat = 50
    static let disclosure: CGFloat = 14
    static let indentPerLevel: CGFloat = 14
}

struct FileListView: View {
    var root: FileNode
    /// Denominator for the percentage/proportion-bar columns — the currently displayed
    /// root's size, so it stays 100% at whatever level you've drilled into.
    var totalSize: Int64
    @Binding var selection: FileNode?
    @Binding var expandedURLs: Set<URL>
    /// Bumped by the view model when a pick made elsewhere (the treemap) should be scrolled to.
    var revealTarget: ScanViewModel.RevealTarget?
    var sortKey: FileSortKey
    var sortAscending: Bool
    var onChangeSort: (FileSortKey) -> Void
    var onDoubleClick: (FileNode) -> Void
    var onRequestDelete: (FileNode) -> Void

    /// Cached so the flatten only reruns when the tree or the expansion actually changes,
    /// not on every selection or hover that invalidates this body.
    @State private var rows: [FlattenedNode] = []

    var body: some View {
        VStack(spacing: 0) {
            FileListHeaderView(sortKey: sortKey, sortAscending: sortAscending, onSelect: onChangeSort)
            ScrollViewReader { proxy in
                List(selection: $selection) {
                    ForEach(rows) { row in
                        FileRowView(
                            row: row,
                            totalSize: totalSize,
                            isExpanded: expandedURLs.contains(row.node.url),
                            onToggleExpansion: { toggleExpansion(of: row.node) }
                        )
                        .tag(row.node)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { onDoubleClick(row.node) }
                        .contextMenu { fileContextMenu(for: row.node, requestDelete: onRequestDelete) }
                    }
                }
                .listStyle(.inset)
                .onChange(of: revealTarget) { _, target in
                    guard let target else { return }
                    // The update that set this also expanded the target's ancestors, but the
                    // rows are rebuilt by a separate `onChange` and SwiftUI doesn't order the
                    // two. Scroll once the update has committed, so the row exists by then.
                    Task { @MainActor in
                        withAnimation { proxy.scrollTo(target.url, anchor: .center) }
                    }
                }
            }
        }
        .onChange(of: RowsKey(root: root, expandedURLs: expandedURLs), initial: true) { _, _ in
            rows = root.flattenedChildren(expandedURLs: expandedURLs)
        }
    }

    private func toggleExpansion(of node: FileNode) {
        if expandedURLs.contains(node.url) {
            expandedURLs.remove(node.url)
        } else {
            expandedURLs.insert(node.url)
        }
    }
}

/// What the flattened row set depends on. Size and file count stand in for the tree's
/// contents, so trashing a file rebuilds the rows without deep-comparing the whole tree.
private struct RowsKey: Equatable {
    let rootURL: URL
    let rootPhysicalSize: Int64
    let rootFileCount: Int
    let expandedURLs: Set<URL>

    init(root: FileNode, expandedURLs: Set<URL>) {
        self.rootURL = root.url
        self.rootPhysicalSize = root.physicalSize
        self.rootFileCount = root.fileCount
        self.expandedURLs = expandedURLs
    }
}

private struct FileListHeaderView: View {
    var sortKey: FileSortKey
    var sortAscending: Bool
    var onSelect: (FileSortKey) -> Void

    var body: some View {
        HStack(spacing: 8) {
            headerButton("Name", key: .name, width: nil)
            headerButton("Size Proportion", key: nil, width: FileListColumns.bar)
            headerButton("Percentage", key: .physicalSize, width: FileListColumns.percentage)
            headerButton("Physical Size", key: .physicalSize, width: FileListColumns.size)
            headerButton("Logical Size", key: .logicalSize, width: FileListColumns.size)
            headerButton("Files", key: .fileCount, width: FileListColumns.count)
        }
        .font(.caption.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }

    @ViewBuilder
    private func headerButton(_ title: String, key: FileSortKey?, width: CGFloat?) -> some View {
        let button = Button {
            if let key { onSelect(key) }
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if let key, key == sortKey {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
            }
        }
        .buttonStyle(.plain)

        if let width {
            button.frame(width: width, alignment: .leading)
        } else {
            button.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct FileRowView: View {
    var row: FlattenedNode
    var totalSize: Int64
    var isExpanded: Bool
    var onToggleExpansion: () -> Void

    private var node: FileNode { row.node }

    private var fraction: Double {
        totalSize > 0 ? Double(node.physicalSize) / Double(totalSize) : 0
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                // Indentation and disclosure, which the outline used to draw for us.
                Color.clear
                    .frame(width: CGFloat(row.depth) * FileListColumns.indentPerLevel, height: 1)
                disclosureControl

                Image(systemName: node.isDirectory ? "folder.fill" : "doc")
                    .foregroundStyle(node.isDirectory ? .blue : .secondary)
                Text(node.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SizeProportionBar(fraction: fraction)
                .frame(width: FileListColumns.bar, height: 12)

            Text(fraction, format: .percent.precision(.fractionLength(2)))
                .frame(width: FileListColumns.percentage, alignment: .trailing)

            Text(node.physicalSize, format: .byteCount(style: .file))
                .frame(width: FileListColumns.size, alignment: .trailing)

            Text(node.logicalSize, format: .byteCount(style: .file))
                .frame(width: FileListColumns.size, alignment: .trailing)

            Text("\(node.fileCount)")
                .frame(width: FileListColumns.count, alignment: .trailing)
        }
        .font(.system(size: 12))
        .lineLimit(1)
    }

    @ViewBuilder
    private var disclosureControl: some View {
        if row.isExpandable {
            Button(action: onToggleExpansion) {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: FileListColumns.disclosure, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: isExpanded)
        } else {
            Color.clear.frame(width: FileListColumns.disclosure, height: 1)
        }
    }
}

private struct SizeProportionBar: View {
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
