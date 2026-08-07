import Darwin
import Foundation

public enum ScanEvent: Sendable {
    case scanned(path: URL)
    case permissionDenied(path: URL)
}

public enum ScanError: Error, Sendable {
    case rootNotAccessible(URL)
}

/// Concurrently walks a directory tree and builds an aggregated ``FileNode`` tree.
///
/// Only directories are recursed into on their own child task — files are
/// `lstat`'d synchronously in the parent's loop, since spawning a task per
/// file would dwarf the actual syscall cost. Directory listings are gated by
/// a semaphore so a wide tree can't oversubscribe Swift's cooperative thread
/// pool with blocking `readdir` calls.
public struct DirectoryScanner: Sendable {
    private let maxConcurrentDirectoryReads: Int

    public init(maxConcurrentDirectoryReads: Int = 8) {
        self.maxConcurrentDirectoryReads = maxConcurrentDirectoryReads
    }

    public func scan(root: URL, onEvent: (@Sendable (ScanEvent) -> Void)? = nil) async throws -> FileNode {
        let path = root.path
        guard let rootStat = Self.lstatInfo(path) else {
            throw ScanError.rootNotAccessible(root)
        }

        if (rootStat.st_mode & S_IFMT) != S_IFDIR {
            return Self.leafNode(url: root, name: root.lastPathComponent, stat: rootStat)
        }

        let semaphore = AsyncSemaphore(value: maxConcurrentDirectoryReads)
        return try await scanDirectory(
            at: root,
            path: path,
            deviceID: rootStat.st_dev,
            semaphore: semaphore,
            onEvent: onEvent
        )
    }

    private func scanDirectory(
        at url: URL,
        path: String,
        deviceID: dev_t,
        semaphore: AsyncSemaphore,
        onEvent: (@Sendable (ScanEvent) -> Void)?
    ) async throws -> FileNode {
        await semaphore.acquire()
        let entryNames: [String]
        do {
            entryNames = try FileManager.default.contentsOfDirectory(atPath: path)
        } catch {
            await semaphore.release()
            onEvent?(.permissionDenied(path: url))
            return FileNode(
                url: url, name: url.lastPathComponent, isDirectory: true, isSymbolicLink: false,
                logicalSize: 0, physicalSize: 0, children: [], fileCount: 0
            )
        }
        await semaphore.release()

        var fileChildren: [FileNode] = []
        var subdirectories: [(path: String, url: URL)] = []

        for name in entryNames {
            let childPath = path + "/" + name
            guard let st = Self.lstatInfo(childPath) else { continue }
            let childURL = url.appendingPathComponent(name)

            if (st.st_mode & S_IFMT) == S_IFDIR {
                guard st.st_dev == deviceID else {
                    // Mount point: represent it, but don't cross onto another volume.
                    fileChildren.append(FileNode(
                        url: childURL, name: name, isDirectory: true, isSymbolicLink: false,
                        logicalSize: 0, physicalSize: 0, children: [], fileCount: 0
                    ))
                    continue
                }
                subdirectories.append((childPath, childURL))
            } else {
                fileChildren.append(Self.leafNode(url: childURL, name: name, stat: st))
                onEvent?(.scanned(path: childURL))
            }
        }

        let scannedSubdirectories = try await withThrowingTaskGroup(of: FileNode.self) { group in
            for subdirectory in subdirectories {
                group.addTask {
                    try await self.scanDirectory(
                        at: subdirectory.url, path: subdirectory.path, deviceID: deviceID,
                        semaphore: semaphore, onEvent: onEvent
                    )
                }
            }
            var results: [FileNode] = []
            for try await node in group {
                results.append(node)
            }
            return results
        }

        onEvent?(.scanned(path: url))

        let children = fileChildren + scannedSubdirectories
        return FileNode(
            url: url,
            name: url.lastPathComponent,
            isDirectory: true,
            isSymbolicLink: false,
            logicalSize: children.reduce(0) { $0 + $1.logicalSize },
            physicalSize: children.reduce(0) { $0 + $1.physicalSize },
            children: children,
            fileCount: children.reduce(0) { $0 + $1.fileCount }
        )
    }

    private static func leafNode(url: URL, name: String, stat st: stat) -> FileNode {
        FileNode(
            url: url,
            name: name,
            isDirectory: false,
            isSymbolicLink: (st.st_mode & S_IFMT) == S_IFLNK,
            logicalSize: Int64(st.st_size),
            // st_blocks is always counted in 512-byte units, regardless of the filesystem's actual block size.
            physicalSize: Int64(st.st_blocks) * 512,
            children: [],
            fileCount: 1
        )
    }

    private static func lstatInfo(_ path: String) -> stat? {
        var s = stat()
        return lstat(path, &s) == 0 ? s : nil
    }
}

/// Minimal counting semaphore for bounding concurrent blocking work from async tasks.
private actor AsyncSemaphore {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.permits = value
    }

    func acquire() async {
        if permits > 0 {
            permits -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty {
            permits += 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}
