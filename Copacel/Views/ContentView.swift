import CopacelCore
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ScanViewModel()
    @State private var isChoosingFolder = false
    @State private var pendingDeletion: FileNode?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .frame(minWidth: 640, minHeight: 400)
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            if let url = try? result.get() {
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

    private var toolbar: some View {
        HStack {
            Button("Choose Folder…") { isChoosingFolder = true }

            if !viewModel.navigationPath.isEmpty {
                Button {
                    viewModel.drillUp(to: viewModel.navigationPath.dropLast().last)
                } label: {
                    Label("Up", systemImage: "arrow.up")
                }
            }

            Spacer()

            switch viewModel.state {
            case .scanning(let count):
                ProgressView("Scanning… \(count) items")
            case .failed(let message):
                Text("Scan failed: \(message)").foregroundStyle(.red)
            default:
                EmptyView()
            }
        }
        .padding(8)
    }

    @ViewBuilder
    private var content: some View {
        if let root = viewModel.displayRoot, let treemapRoot = viewModel.currentRoot {
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
        } else {
            VStack {
                Spacer()
                Text("Choose a folder to scan")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

#Preview {
    ContentView()
}
