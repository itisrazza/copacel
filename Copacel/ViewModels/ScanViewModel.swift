import CopacelCore
import Foundation
import Observation

@MainActor
@Observable
final class ScanViewModel {
    enum ScanState: Equatable {
        case idle
        case scanning(scannedCount: Int)
        case completed
        case failed(String)
    }

    private(set) var state: ScanState = .idle
    private(set) var rootNode: FileNode? {
        didSet { refreshDerivedState() }
    }
    private(set) var rootURL: URL?
    private(set) var navigationStack: [FileNode] = [] {
        didSet { refreshDerivedState() }
    }
    private(set) var permissionDeniedCount = 0
    var selectedNode: FileNode?

    var sortKey: FileSortKey = .physicalSize {
        didSet { refreshDerivedState() }
    }
    var sortAscending = false {
        didSet { refreshDerivedState() }
    }

    /// The directory currently shown in the list/treemap — the drill-down target, or the scan root.
    var currentRoot: FileNode? { navigationStack.last ?? rootNode }

    /// `currentRoot`, sorted at every level per `sortKey`/`sortAscending`. Cached on change
    /// rather than recomputed per SwiftUI body evaluation, since sorting a large tree isn't free.
    private(set) var displayRoot: FileNode?

    /// Per-extension totals for `currentRoot`'s subtree, for the legend panel. Recalculates
    /// as you drill down, same as the list/treemap.
    private(set) var extensionStats: [ExtensionStat] = []

    private func refreshDerivedState() {
        let root = currentRoot
        displayRoot = root?.sorted(by: sortKey, ascending: sortAscending)
        extensionStats = root.map(ExtensionStats.aggregate(from:)) ?? []
    }

    private let scanner = DirectoryScanner()
    private var scanTask: Task<Void, Never>?

    func scan(root: URL) {
        scanTask?.cancel()
        rootNode = nil
        rootURL = root
        navigationStack = []
        selectedNode = nil
        permissionDeniedCount = 0
        state = .scanning(scannedCount: 0)

        let scanner = self.scanner
        let counter = ScanProgressCounter()

        // This Task inherits @MainActor isolation from this method, so after the
        // `await` below resumes we're back on the main actor without an explicit hop —
        // only the onEvent closure (called from the scanner's background tasks) needs one.
        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let node = try await scanner.scan(root: root) { event in
                    switch event {
                    case .scanned:
                        let count = counter.increment()
                        guard count.isMultiple(of: 500) else { return }
                        Task { @MainActor in
                            guard case .scanning = self.state else { return }
                            self.state = .scanning(scannedCount: count)
                        }
                    case .permissionDenied:
                        Task { @MainActor in
                            self.permissionDeniedCount += 1
                        }
                    }
                }
                guard !Task.isCancelled else { return }
                self.rootNode = node
                self.state = .completed
            } catch {
                guard !Task.isCancelled else { return }
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        state = .idle
    }

    func drillDown(into node: FileNode) {
        guard node.isDirectory else { return }
        navigationStack.append(node)
        selectedNode = nil
    }

    /// Pops the navigation stack back to `node`, or to the scan root if `node` is `nil`.
    func drillUp(to node: FileNode?) {
        guard let node else {
            navigationStack = []
            selectedNode = nil
            return
        }
        if let index = navigationStack.firstIndex(where: { $0.id == node.id }) {
            navigationStack = Array(navigationStack[0...index])
        }
        selectedNode = nil
    }
}

/// Lock-protected counter for tallying scan progress reported from the scanner's
/// concurrent background tasks, off the main actor.
private final class ScanProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }
}
