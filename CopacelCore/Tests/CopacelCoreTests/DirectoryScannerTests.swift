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
        if case .unreadableDirectory(let path, let failure) = event {
            deniedPaths.add(path)
            // chmod 000 is an ordinary permission denial (EACCES), not macOS privacy
            // protection — Full Disk Access wouldn't make this one readable.
            #expect(failure == .permissionDenied)
            #expect(failure.isResolvedByFullDiskAccess == false)
        }
    }

    #expect(deniedPaths.snapshot().map(\.lastPathComponent) == ["restricted"])
    let restrictedNode = try #require(scanned.children.first { $0.name == "restricted" })
    #expect(restrictedNode.fileCount == 0)
    #expect(restrictedNode.logicalSize == 0)
    // The node records why it's empty, so the UI can tell it from a genuinely empty folder.
    #expect(restrictedNode.readFailure == .permissionDenied)
}

@Test func readableEmptyDirectoriesAreNotMarkedUnreadable() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let empty = root.appendingPathComponent("empty")
    try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let scanned = try await DirectoryScanner().scan(root: root)

    let emptyNode = try #require(scanned.children.first { $0.name == "empty" })
    #expect(emptyNode.children.isEmpty)
    #expect(emptyNode.readFailure == nil)
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

struct ChildPathCase: Sendable, CustomStringConvertible {
    let directoryPath: String
    let name: String
    let expected: String

    var description: String { "\(directoryPath) + \(name) -> \(expected)" }
}

/// A scan rooted at "/" used to build "//System/Volumes/Data", which never matches the
/// mount table's "/System/Volumes/Data" — so the scanner crossed into the Data volume and
/// counted every firmlinked file twice.
@Test(arguments: [
    ChildPathCase(directoryPath: "/", name: "System", expected: "/System"),
    ChildPathCase(directoryPath: "/", name: "Users", expected: "/Users"),
    ChildPathCase(directoryPath: "/System/Volumes", name: "Data", expected: "/System/Volumes/Data"),
    ChildPathCase(directoryPath: "/tmp/folder", name: "file.txt", expected: "/tmp/folder/file.txt"),
    ChildPathCase(directoryPath: "/tmp/folder/", name: "file.txt", expected: "/tmp/folder/file.txt")
])
func childPathNeverDoublesTheSeparator(testCase: ChildPathCase) {
    #expect(DirectoryScanner.childPath(in: testCase.directoryPath, name: testCase.name) == testCase.expected)
}

@Test func pathsBuiltFromTheFilesystemRootMatchTheMountTable() {
    // The mount-table comparison is the only guard against crossing into the Data volume,
    // since it shares st_dev with the sealed system volume it's firmlinked into. That guard
    // is a string match, so descending from "/" has to produce table-shaped paths.
    var path = URL(fileURLWithPath: "/").path
    for component in ["System", "Volumes", "Data"] {
        path = DirectoryScanner.childPath(in: path, name: component)
    }
    #expect(path == "/System/Volumes/Data")
}

/// `/.nofollow` is macOS's firmlink-free view of the boot volume: an empty directory to `ls`,
/// `find` and `du`, but `FileManager.contentsOfDirectory` resolves through it and reports the
/// whole of `/`. Scanning the boot volume then counted every file on it a second time.
@Test(.enabled(if: FileManager.default.fileExists(atPath: "/.nofollow")))
func firmlinkFreeRootViewScansAsTheEmptyDirectoryItIs() async throws {
    let node = try await DirectoryScanner().scan(root: URL(fileURLWithPath: "/.nofollow"))

    #expect(node.children.isEmpty)
    #expect(node.physicalSize == 0)
    #expect(node.fileCount == 0)
}
