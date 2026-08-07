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
