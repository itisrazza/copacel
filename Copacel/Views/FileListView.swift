import CopacelCore
import SwiftUI

enum FileListColumns {
    static let bar: CGFloat = 120
    static let percentage: CGFloat = 64
    static let size: CGFloat = 90
    static let count: CGFloat = 50
}

extension FileNode {
    /// `nil` (no disclosure triangle) for files and empty directories, matching what
    /// `OutlineGroup` expects for a leaf row.
    var outlineChildren: [FileNode]? {
        isDirectory && !children.isEmpty ? children : nil
    }
}

struct FileListView: View {
    var root: FileNode
    /// Denominator for the percentage/proportion-bar columns — the currently displayed
    /// root's size, so it stays 100% at whatever level you've drilled into.
    var totalSize: Int64
    @Binding var selection: FileNode?
    var sortKey: FileSortKey
    var sortAscending: Bool
    var onChangeSort: (FileSortKey) -> Void
    var onDoubleClick: (FileNode) -> Void

    var body: some View {
        VStack(spacing: 0) {
            FileListHeaderView(sortKey: sortKey, sortAscending: sortAscending, onSelect: onChangeSort)
            List(selection: $selection) {
                OutlineGroup(root.outlineChildren ?? [], id: \.self, children: \.outlineChildren) { node in
                    FileRowView(node: node, totalSize: totalSize)
                        .tag(node)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { onDoubleClick(node) }
                }
            }
            .listStyle(.inset)
        }
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
    var node: FileNode
    var totalSize: Int64

    private var fraction: Double {
        totalSize > 0 ? Double(node.physicalSize) / Double(totalSize) : 0
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
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
