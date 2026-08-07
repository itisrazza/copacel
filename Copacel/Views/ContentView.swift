import SwiftUI

struct ContentView: View {
    @State private var viewModel = ScanViewModel()
    @State private var isChoosingFolder = false

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
    }

    private var toolbar: some View {
        HStack {
            Button("Choose Folder…") { isChoosingFolder = true }

            if !viewModel.navigationStack.isEmpty {
                Button {
                    viewModel.drillUp(to: viewModel.navigationStack.dropLast().last)
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
                        }
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
                    onDrillDown: { viewModel.drillDown(into: $0) }
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
