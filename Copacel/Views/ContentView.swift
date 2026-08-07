import SwiftUI

struct ContentView: View {
    @State private var viewModel = ScanViewModel()
    @State private var isChoosingFolder = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Copăcel")
                .font(.title)

            Button("Choose Folder…") {
                isChoosingFolder = true
            }

            statusView
        }
        .padding()
        .frame(minWidth: 360, minHeight: 200)
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            if let url = try? result.get() {
                viewModel.scan(root: url)
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.state {
        case .idle:
            Text("No scan yet")
                .foregroundStyle(.secondary)
        case .scanning(let scannedCount):
            ProgressView("Scanning… \(scannedCount) items")
        case .completed:
            if let root = viewModel.rootNode {
                VStack(alignment: .leading) {
                    Text(root.name).bold()
                    Text("\(root.fileCount) files, \(ByteCountFormatter.string(fromByteCount: root.physicalSize, countStyle: .file))")
                        .foregroundStyle(.secondary)
                    if viewModel.permissionDeniedCount > 0 {
                        Text("\(viewModel.permissionDeniedCount) folders skipped (permission denied)")
                            .foregroundStyle(.orange)
                    }
                }
            }
        case .failed(let message):
            Text("Scan failed: \(message)")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    ContentView()
}
