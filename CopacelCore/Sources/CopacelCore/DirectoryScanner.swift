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
            mountPoints: Self.mountPointPaths(),
            semaphore: semaphore,
            onEvent: onEvent
        )
    }

    private func scanDirectory(
        at url: URL,
        path: String,
        deviceID: dev_t,
        mountPoints: Set<String>,
        semaphore: AsyncSemaphore,
        onEvent: (@Sendable (ScanEvent) -> Void)?
    ) async throws -> FileNode {
        await semaphore.acquire()
        let entryNames = Self.directoryEntryNames(path)
        await semaphore.release()

        guard let entryNames else {
            onEvent?(.permissionDenied(path: url))
            return FileNode(
                url: url, name: url.lastPathComponent, isDirectory: true, isSymbolicLink: false,
                logicalSize: 0, physicalSize: 0, children: [], fileCount: 0
            )
        }

        var fileChildren: [FileNode] = []
        var subdirectories: [(path: String, url: URL)] = []

        for name in entryNames {
            let childPath = Self.childPath(in: path, name: name)
            guard let st = Self.lstatInfo(childPath) else { continue }
            let childURL = url.appendingPathComponent(name)

            if (st.st_mode & S_IFMT) == S_IFDIR {
                // Mount point: represent it, but don't cross onto another volume. `st_dev`
                // alone isn't enough — a Data volume firmlinked into the boot volume (e.g.
                // /System/Volumes/Data) reports the *same* st_dev as its System volume despite
                // being a distinct mount, so its content is already reachable through firmlinks
                // like /Users. Cross-check against the real mount table to catch that case too.
                guard st.st_dev == deviceID, !mountPoints.contains(childPath) else {
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
                        mountPoints: mountPoints, semaphore: semaphore, onEvent: onEvent
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

    /// Lists a directory's entry names, or `nil` if it can't be opened at all.
    ///
    /// Uses `readdir` rather than `FileManager.contentsOfDirectory`, which resolves a path
    /// *through* its own final component. That difference matters at the boot volume's root:
    /// `/.nofollow` is macOS's firmlink-free view of the volume, an empty directory to `ls`,
    /// `find` and `du` alike, but `contentsOfDirectory` reports it as holding all of `/` — so
    /// the scan walks the entire volume a second time under that name. `readdir` sees it
    /// empty, as it actually is.
    private static func directoryEntryNames(_ path: String) -> [String]? {
        guard let directory = opendir(path) else { return nil }
        defer { closedir(directory) }

        var names: [String] = []
        while let entry = readdir(directory) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) { raw in
                String(cString: raw.baseAddress!.assumingMemoryBound(to: CChar.self))
            }
            guard name != ".", name != ".." else { continue }
            names.append(name)
        }
        return names
    }

    /// Joins a directory path and an entry name without doubling the separator when the
    /// directory is the filesystem root, whose path is already "/".
    ///
    /// Not cosmetic: the mount-table check in ``scanDirectory`` compares these strings
    /// against `getmntinfo` output, so a scan rooted at "/" building "//System/Volumes/Data"
    /// silently fails to match the table's "/System/Volumes/Data". `lstat` resolves the
    /// doubled slash happily and the Data volume shares its st_dev with the sealed system
    /// volume, so nothing else catches it — the scan crosses into the Data volume and counts
    /// every firmlinked file (the whole of /Users, /Applications, /Library, …) a second time.
    static func childPath(in directoryPath: String, name: String) -> String {
        directoryPath.hasSuffix("/") ? directoryPath + name : directoryPath + "/" + name
    }

    private static func lstatInfo(_ path: String) -> stat? {
        var s = stat()
        return lstat(path, &s) == 0 ? s : nil
    }

    /// All currently mounted filesystems' mount points, via the same BSD API `mount`/`df` use.
    /// `FileManager.mountedVolumeURLs` isn't a substitute here — it omits some mounts
    /// (notably /System/Volumes/Data itself) that `getmntinfo` reports.
    private static func mountPointPaths() -> Set<String> {
        var mountBuffer: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&mountBuffer, MNT_NOWAIT)
        guard count > 0, let mountBuffer else { return [] }

        let entries = UnsafeBufferPointer(start: mountBuffer, count: Int(count))
        return Set(entries.map { entry in
            withUnsafeBytes(of: entry.f_mntonname) { raw in
                String(cString: raw.baseAddress!.assumingMemoryBound(to: CChar.self))
            }
        })
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
