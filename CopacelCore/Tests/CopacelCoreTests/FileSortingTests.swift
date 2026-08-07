import Foundation
import Testing
@testable import CopacelCore

@Test func sortedOrdersChildrenByPhysicalSizeDescending() {
    func file(_ name: String, size: Int64) -> FileNode {
        FileNode(
            url: URL(fileURLWithPath: "/root/\(name)"), name: name, isDirectory: false, isSymbolicLink: false,
            logicalSize: size, physicalSize: size, children: [], fileCount: 1
        )
    }

    let root = FileNode(
        url: URL(fileURLWithPath: "/root"), name: "root", isDirectory: true, isSymbolicLink: false,
        logicalSize: 60, physicalSize: 60,
        children: [file("small", size: 10), file("big", size: 50), file("tied-a", size: 20), file("tied-b", size: 20)],
        fileCount: 4
    )

    let descending = root.sorted(by: .physicalSize, ascending: false)
    #expect(descending.children.map(\.name) == ["big", "tied-a", "tied-b", "small"])

    let ascending = root.sorted(by: .physicalSize, ascending: true)
    #expect(ascending.children.map(\.name) == ["small", "tied-a", "tied-b", "big"])
}

@Test func sortedRecursesIntoSubdirectories() {
    let leaf = FileNode(
        url: URL(fileURLWithPath: "/root/sub/z.txt"), name: "z.txt", isDirectory: false, isSymbolicLink: false,
        logicalSize: 1, physicalSize: 1, children: [], fileCount: 1
    )
    let leaf2 = FileNode(
        url: URL(fileURLWithPath: "/root/sub/a.txt"), name: "a.txt", isDirectory: false, isSymbolicLink: false,
        logicalSize: 1, physicalSize: 1, children: [], fileCount: 1
    )
    let sub = FileNode(
        url: URL(fileURLWithPath: "/root/sub"), name: "sub", isDirectory: true, isSymbolicLink: false,
        logicalSize: 2, physicalSize: 2, children: [leaf, leaf2], fileCount: 2
    )
    let root = FileNode(
        url: URL(fileURLWithPath: "/root"), name: "root", isDirectory: true, isSymbolicLink: false,
        logicalSize: 2, physicalSize: 2, children: [sub], fileCount: 2
    )

    let sorted = root.sorted(by: .name, ascending: true)
    #expect(sorted.children[0].children.map(\.name) == ["a.txt", "z.txt"])
}
