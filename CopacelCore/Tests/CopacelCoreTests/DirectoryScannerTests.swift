import Foundation
import Testing
@testable import CopacelCore

@Test func scanAggregatesSizesAndFileCountBottomUp() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let subdirectory = root.appendingPathComponent("sub")
    try FileManager.default.createDirectory(at: subdirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try Data("hello".utf8).write(to: root.appendingPathComponent("fileA.txt"))
    try Data("hi".utf8).write(to: subdirectory.appendingPathComponent("fileB.txt"))

    let scanned = try await DirectoryScanner().scan(root: root)

    #expect(scanned.isDirectory)
    #expect(scanned.fileCount == 2)
    #expect(scanned.logicalSize == 7)
    #expect(scanned.physicalSize >= scanned.logicalSize)
    #expect(scanned.children.count == 2)

    let sub = try #require(scanned.children.first { $0.name == "sub" })
    #expect(sub.fileCount == 1)
    #expect(sub.logicalSize == 2)
}

@Test func scanRecordsSymbolicLinksWithoutFollowingThem() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let targetContent = "hello world, this is the link target's content"
    let target = root.appendingPathComponent("target.txt")
    try Data(targetContent.utf8).write(to: target)
    let link = root.appendingPathComponent("link.txt")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

    let scanned = try await DirectoryScanner().scan(root: root)

    #expect(scanned.children.count == 2)
    let linkNode = try #require(scanned.children.first { $0.name == "link.txt" })
    #expect(linkNode.isSymbolicLink)
    #expect(!linkNode.isDirectory)
    // A symlink's st_size is the length of the stored destination path, not the target's
    // content — asserting it's different from the target's size confirms we didn't follow it.
    #expect(linkNode.logicalSize != Int64(targetContent.utf8.count))
    // fileCount should also only ever count each entry once (the link, not link + target-again).
    #expect(scanned.fileCount == 2)
}

@Test func scanReportsPermissionDeniedDirectoriesWithoutThrowing() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let restricted = root.appendingPathComponent("restricted")
    try FileManager.default.createDirectory(at: restricted, withIntermediateDirectories: true)
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: restricted.path)
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: restricted.path)
        try? FileManager.default.removeItem(at: root)
    }

    let deniedPaths = DeniedPathCollector()
    let scanned = try await DirectoryScanner().scan(root: root) { event in
        if case .permissionDenied(let path) = event {
            deniedPaths.add(path)
        }
    }

    #expect(deniedPaths.snapshot().map(\.lastPathComponent) == ["restricted"])
    let restrictedNode = try #require(scanned.children.first { $0.name == "restricted" })
    #expect(restrictedNode.fileCount == 0)
    #expect(restrictedNode.logicalSize == 0)
}

private final class DeniedPathCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var paths: [URL] = []

    func add(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        paths.append(url)
    }

    func snapshot() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return paths
    }
}
