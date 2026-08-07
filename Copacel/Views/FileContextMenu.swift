import CopacelCore
import SwiftUI

@MainActor
@ViewBuilder
func fileContextMenu(for node: FileNode, requestDelete: @escaping (FileNode) -> Void) -> some View {
    Button("Reveal in Finder") { FileActions.revealInFinder(node) }
    Button("Copy Path") { FileActions.copyPath(node) }
    Divider()
    Button("Move to Trash…", role: .destructive) { requestDelete(node) }
}
