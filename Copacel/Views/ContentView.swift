import CopacelCore
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ScanViewModel()
    @State private var isChoosingFolder = false
    @State private var pendingDeletion: FileNode?
    @State private var dismissedFullDiskAccessTip = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if viewModel.permissionDeniedCount > 0, !dismissedFullDiskAccessTip {
                FullDiskAccessTipView(deniedCount: viewModel.permissionDeniedCount) {
                    dismissedFullDiskAccessTip = true
                }
                Divider()
            }
            content
        }
        .frame(minWidth: 640, minHeight: 400)
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            if let url = try? result.get() {
                dismissedFullDiskAccessTip = false
                viewModel.scan(root: url)
            }
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { node in
            Button("Move to Trash", role: .destructive) {
                FileActions.moveToTrash(node) { viewModel.removeFromTree(node) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { node in
            Text(node.isDirectory
                ? "\"\(node.name)\" and everything inside it will be moved to the Trash."
                : "\"\(node.name)\" will be moved to the Trash.")
        }
    }

    private var isScanning: Bool {
        if case .scanning = viewModel.state { return true }
        return false
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("Choose Folder…") { isChoosingFolder = true }

                if let rootURL = viewModel.rootURL {
                    Button {
                        viewModel.scan(root: rootURL)
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .disabled(isScanning)
                }

                if isScanning {
                    Button {
                        viewModel.stopScan()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                }

                Spacer()

                switch viewModel.state {
                case .scanning(let count):
                    ProgressView("Scanning… \(count) items")
                        .controlSize(.small)
                case .failed(let message):
                    Label("Scan failed: \(message)", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                default:
                    EmptyView()
                }
            }

            if !viewModel.breadcrumbTrail.isEmpty {
                breadcrumb
            }
        }
        .padding(8)
    }

    private var breadcrumb: some View {
        let trail = viewModel.breadcrumbTrail
        return HStack(spacing: 4) {
            ForEach(Array(trail.enumerated()), id: \.element.id) { index, node in
                Button(node.name) {
                    viewModel.drillUp(to: index == 0 ? nil : node.url)
                }
                .buttonStyle(.plain)
                .foregroundStyle(index == trail.count - 1 ? .primary : .secondary)

                if index < trail.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .font(.callout)
        .lineLimit(1)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            StatusPlaceholderView(
                systemImage: "internaldrive",
                title: "No folder scanned yet",
                message: "Choose a folder to see what's using your disk space."
            )
        case .scanning(let count):
            StatusPlaceholderView(
                systemImage: "magnifyingglass",
                title: "Scanning…",
                message: "\(count) items found so far"
            )
        case .failed(let message):
            StatusPlaceholderView(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't scan this folder",
                message: message
            )
        case .completed:
            if let root = viewModel.displayRoot, let treemapRoot = viewModel.currentRoot, !root.children.isEmpty {
                scanResultView(root: root, treemapRoot: treemapRoot)
            } else {
                StatusPlaceholderView(systemImage: "tray", title: "This folder is empty")
            }
        }
    }

    private func scanResultView(root: FileNode, treemapRoot: FileNode) -> some View {
        VSplitView {
            HSplitView {
                FileListView(
                    root: root,
                    totalSize: root.physicalSize,
                    selection: $viewModel.selectedNode,
                    sortKey: viewModel.sortKey,
                    sortAscending: viewModel.sortAscending,
                    onChangeSort: { key in
                        if viewModel.sortKey == key {
                            viewModel.sortAscending.toggle()
                        } else {
                            viewModel.sortKey = key
                            viewModel.sortAscending = false
                        }
                    },
                    onDoubleClick: { node in
                        if node.isDirectory {
                            viewModel.drillDown(into: node)
                        }
                    },
                    onRequestDelete: { pendingDeletion = $0 }
                )
                .frame(minWidth: 360)

                ExtensionLegendView(stats: viewModel.extensionStats, selectedExtension: $viewModel.selectedExtension)
                    .frame(minWidth: 220, idealWidth: 260)
            }
            .frame(minHeight: 200)

            TreemapView(
                root: treemapRoot,
                selection: viewModel.selectedNode,
                highlightedExtension: viewModel.selectedExtension,
                onSelect: { viewModel.selectedNode = $0 },
                onDrillDown: { viewModel.drillDown(into: $0) },
                onRequestDelete: { pendingDeletion = $0 }
            )
            .frame(minHeight: 160)
        }
    }
}

private struct StatusPlaceholderView: View {
    var systemImage: String
    var title: String
    var message: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(title)
                .foregroundStyle(.secondary)
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    ContentView()
}
