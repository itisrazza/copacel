import Foundation
import Testing
@testable import CopacelCore

@Test func removingUpdatesAncestorSizesAndFileCounts() throws {
    func file(_ name: String, size: Int64) -> FileNode {
        FileNode(
            url: URL(fileURLWithPath: "/root/sub/\(name)"), name: name, isDirectory: false, isSymbolicLink: false,
            logicalSize: size, physicalSize: size, children: [], fileCount: 1
        )
    }

    let target = file("delete-me.txt", size: 30)
    let sub = FileNode(
        url: URL(fileURLWithPath: "/root/sub"), name: "sub", isDirectory: true, isSymbolicLink: false,
        logicalSize: 50, physicalSize: 50, children: [file("keep.txt", size: 20), target], fileCount: 2
    )
    let root = FileNode(
        url: URL(fileURLWithPath: "/root"), name: "root", isDirectory: true, isSymbolicLink: false,
        logicalSize: 50, physicalSize: 50, children: [sub], fileCount: 2
    )

    let updated = try #require(root.removing(url: target.url))

    #expect(updated.fileCount == 1)
    #expect(updated.logicalSize == 20)
    let updatedSub = try #require(updated.children.first)
    #expect(updatedSub.fileCount == 1)
    #expect(updatedSub.logicalSize == 20)
    #expect(updatedSub.children.map(\.name) == ["keep.txt"])
}

@Test func removingReturnsNilForTheNodeItself() {
    let root = FileNode(
        url: URL(fileURLWithPath: "/root"), name: "root", isDirectory: true, isSymbolicLink: false,
        logicalSize: 0, physicalSize: 0, children: [], fileCount: 0
    )
    #expect(root.removing(url: root.url) == nil)
}

@Test func removingIsANoOpWhenTargetIsNotInTheSubtree() throws {
    let leaf = FileNode(
        url: URL(fileURLWithPath: "/root/a.txt"), name: "a.txt", isDirectory: false, isSymbolicLink: false,
        logicalSize: 5, physicalSize: 5, children: [], fileCount: 1
    )
    let root = FileNode(
        url: URL(fileURLWithPath: "/root"), name: "root", isDirectory: true, isSymbolicLink: false,
        logicalSize: 5, physicalSize: 5, children: [leaf], fileCount: 1
    )

    let updated = try #require(root.removing(url: URL(fileURLWithPath: "/root/nonexistent.txt")))
    #expect(updated.fileCount == 1)
    #expect(updated.children.map(\.name) == ["a.txt"])
}
