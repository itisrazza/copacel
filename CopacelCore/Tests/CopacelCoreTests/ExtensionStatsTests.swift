import Foundation
import Testing
@testable import CopacelCore

@Test func extensionStatsAggregatesAcrossSubdirectories() throws {
    func file(_ name: String, logical: Int64) -> FileNode {
        FileNode(
            url: URL(fileURLWithPath: "/root/\(name)"), name: name, isDirectory: false, isSymbolicLink: false,
            logicalSize: logical, physicalSize: logical, children: [], fileCount: 1
        )
    }

    let sub = FileNode(
        url: URL(fileURLWithPath: "/root/sub"), name: "sub", isDirectory: true, isSymbolicLink: false,
        logicalSize: 30, physicalSize: 30, children: [file("b.txt", logical: 30)], fileCount: 1
    )
    let root = FileNode(
        url: URL(fileURLWithPath: "/root"), name: "root", isDirectory: true, isSymbolicLink: false,
        logicalSize: 60, physicalSize: 60,
        children: [file("a.txt", logical: 10), file("noext", logical: 20), sub],
        fileCount: 3
    )

    let stats = ExtensionStats.aggregate(from: root)

    let txt = try #require(stats.first { $0.fileExtension == "txt" })
    #expect(txt.fileCount == 2)
    #expect(txt.totalLogicalSize == 40)

    let noExtension = stats.first { $0.fileExtension == "" }
    #expect(noExtension?.fileCount == 1)
    #expect(noExtension?.totalLogicalSize == 20)
}
