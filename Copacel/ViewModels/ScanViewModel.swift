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
    /// Path of drilled-into directory URLs, resolved fresh against `rootNode` rather than
    /// stored as snapshots — so it can never go stale after e.g. a delete updates the tree.
    private(set) var navigationPath: [URL] = [] {
        didSet { refreshDerivedState() }
    }
    private(set) var permissionDeniedCount = 0
    var selectedNode: FileNode?
    /// Extension clicked in the legend, to highlight matching tiles in the treemap. Distinct
    /// from `selectedNode`, since this is a "highlight all of this type" filter, not a pick.
    var selectedExtension: String?

    var sortKey: FileSortKey = .physicalSize {
        didSet { refreshDerivedState() }
    }
    var sortAscending = false {
        didSet { refreshDerivedState() }
    }

    /// The directory currently shown in the list/treemap — the drill-down target, or the scan root.
    var currentRoot: FileNode? {
        var node = rootNode
        for url in navigationPath {
            node = node?.children.first { $0.url == url }
        }
        return node
    }

    /// `rootNode` followed by the resolved node for each `navigationPath` entry, for breadcrumb UI.
    var breadcrumbTrail: [FileNode] {
        guard let rootNode else { return [] }
        var trail = [rootNode]
        for url in navigationPath {
            guard let child = trail.last?.children.first(where: { $0.url == url }) else { break }
            trail.append(child)
        }
        return trail
    }

    /// `currentRoot`, sorted at every level per `sortKey`/`sortAscending`. Cached on change
    /// rather than recomputed per SwiftUI body evaluation, since sorting a large tree isn't free.
    private(set) var displayRoot: FileNode?

    /// Per-extension totals for `currentRoot`'s subtree, for the legend panel. Recalculates
    /// as you drill down, same as the list/treemap.
    private(set) var extensionStats: [ExtensionStat] = []

    private var derivedStateTask: Task<Void, Never>?

    /// Recomputes `displayRoot`/`extensionStats` off the main actor: on a large tree, sorting
    /// and aggregating together take long enough to visibly stall a sort-header click or a
    /// drill-down. The previous values are left in place until the new ones land, so the UI
    /// briefly shows the old level rather than flashing a placeholder.
    private func refreshDerivedState() {
        derivedStateTask?.cancel()
        guard let root = currentRoot else {
            displayRoot = nil
            extensionStats = []
            derivedStateTask = nil
            return
        }

        let sortKey = self.sortKey
        let ascending = self.sortAscending
        // Inherits @MainActor from this method, so the assignments below land back on the
        // main actor once `derive` returns.
        derivedStateTask = Task { [weak self] in
            let derived = await derive(from: root, sortKey: sortKey, ascending: ascending)
            guard !Task.isCancelled, let self else { return }
            self.displayRoot = derived.displayRoot
            self.extensionStats = derived.stats
        }
    }

    private let scanner = DirectoryScanner()
    private var scanTask: Task<Void, Never>?

    func scan(root: URL) {
        scanTask?.cancel()
        rootNode = nil
        rootURL = root
        navigationPath = []
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
                // Wait for the derived state that assignment kicked off, so the UI goes
                // straight from "Scanning…" to the finished view instead of flashing the
                // empty-folder placeholder while the first sort runs.
                await self.derivedStateTask?.value
                guard !Task.isCancelled else { return }
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
        navigationPath.append(node.url)
        selectedNode = nil
    }

    /// Pops the navigation path back to `url`, or to the scan root if `url` is `nil`.
    func drillUp(to url: URL?) {
        guard let url else {
            navigationPath = []
            selectedNode = nil
            return
        }
        if let index = navigationPath.firstIndex(of: url) {
            navigationPath = Array(navigationPath[0...index])
        }
        selectedNode = nil
    }

    /// Removes `node` (file or whole subtree) from the in-memory tree and re-aggregates
    /// every ancestor's size/count, without a full rescan.
    func removeFromTree(_ node: FileNode) {
        guard let rootNode else { return }
        self.rootNode = rootNode.removing(url: node.url)
        if selectedNode?.id == node.id {
            selectedNode = nil
        }
    }
}

/// `nonisolated` so it runs on the global executor instead of the main actor, while still
/// inheriting cancellation from the task awaiting it.
private nonisolated func derive(
    from root: FileNode,
    sortKey: FileSortKey,
    ascending: Bool
) async -> (displayRoot: FileNode, stats: [ExtensionStat]) {
    (root.sorted(by: sortKey, ascending: ascending), ExtensionStats.aggregate(from: root))
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
