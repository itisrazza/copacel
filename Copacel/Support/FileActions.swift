import AppKit
import CopacelCore

enum FileActions {
    static func revealInFinder(_ node: FileNode) {
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }

    static func copyPath(_ node: FileNode) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(node.url.path, forType: .string)
    }

    /// Moves `node` to the Trash (recoverable) and, on success, removes it from the
    /// in-memory tree via `onRemoved` — no rescan needed.
    static func moveToTrash(_ node: FileNode, onRemoved: @escaping @Sendable () -> Void) {
        NSWorkspace.shared.recycle([node.url]) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.async {
                onRemoved()
            }
        }
    }
}
