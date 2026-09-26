import Foundation
import Testing
@testable import CopacelCore

private func file(_ path: String, size: Int64 = 10) -> FileNode {
    let url = URL(fileURLWithPath: path)
    return FileNode(
        url: url, name: url.lastPathComponent, isDirectory: false, isSymbolicLink: false,
        logicalSize: size, physicalSize: size, children: [], fileCount: 1
    )
}

private func directory(_ path: String, _ children: [FileNode]) -> FileNode {
    let url = URL(fileURLWithPath: path)
    return FileNode(
        url: url, name: url.lastPathComponent, isDirectory: true, isSymbolicLink: false,
        logicalSize: children.reduce(0) { $0 + $1.logicalSize },
        physicalSize: children.reduce(0) { $0 + $1.physicalSize },
        children: children, fileCount: children.reduce(0) { $0 + $1.fileCount }
    )
}

/// root
///  ├ docs/          (deep/ inside it)
///  │   └ deep/ → note.txt
///  ├ empty/
///  └ top.txt
private let tree = directory("/root", [
    directory("/root/docs", [
        directory("/root/docs/deep", [file("/root/docs/deep/note.txt")])
    ]),
    directory("/root/empty", []),
    file("/root/top.txt")
])

@Test func flatteningWithNothingExpandedYieldsOnlyTheTopLevel() {
    let rows = tree.flattenedChildren(expandedURLs: [])

    #expect(rows.map(\.node.name) == ["docs", "empty", "top.txt"])
    #expect(rows.allSatisfy { $0.depth == 0 })
}

@Test func flatteningDescendsOnlyIntoExpandedDirectories() {
    let rows = tree.flattenedChildren(expandedURLs: [URL(fileURLWithPath: "/root/docs")])

    #expect(rows.map(\.node.name) == ["docs", "deep", "empty", "top.txt"])
    #expect(rows.map(\.depth) == [0, 1, 0, 0])
}

@Test func flatteningReportsDepthForEveryExpandedLevel() {
    let rows = tree.flattenedChildren(expandedURLs: [
        URL(fileURLWithPath: "/root/docs"),
        URL(fileURLWithPath: "/root/docs/deep")
    ])

    #expect(rows.map(\.node.name) == ["docs", "deep", "note.txt", "empty", "top.txt"])
    #expect(rows.map(\.depth) == [0, 1, 2, 0, 0])
}

@Test func onlyDirectoriesWithChildrenAreExpandable() {
    let rows = tree.flattenedChildren(expandedURLs: [])
    let expandable = rows.filter(\.isExpandable).map(\.node.name)

    // "empty" is a directory but has nothing in it, so it gets no disclosure control.
    #expect(expandable == ["docs"])
}

struct AncestorCase: Sendable, CustomStringConvertible {
    let root: String
    let target: String
    let expected: [String]?

    var description: String { "\(root) -> \(target)" }
}

@Test(arguments: [
    AncestorCase(root: "/root", target: "/root/docs/deep/note.txt",
                 expected: ["/root", "/root/docs", "/root/docs/deep"]),
    AncestorCase(root: "/root", target: "/root/top.txt", expected: ["/root"]),
    // A drilled-into root reports only the ancestors below itself.
    AncestorCase(root: "/root/docs", target: "/root/docs/deep/note.txt",
                 expected: ["/root/docs", "/root/docs/deep"]),
    // Sibling prefixes must not look like ancestors.
    AncestorCase(root: "/root", target: "/rootless/file.txt", expected: nil),
    AncestorCase(root: "/root", target: "/elsewhere/file.txt", expected: nil),
    AncestorCase(root: "/root", target: "/root", expected: nil)
])
func ancestorURLsWalkDownFromTheRoot(testCase: AncestorCase) {
    let ancestors = FileNode.ancestorURLs(
        from: URL(fileURLWithPath: testCase.root),
        to: URL(fileURLWithPath: testCase.target)
    )

    #expect(ancestors?.map(\.path) == testCase.expected)
}

@Test func expandingTheReportedAncestorsMakesTheTargetVisible() {
    let target = URL(fileURLWithPath: "/root/docs/deep/note.txt")
    let ancestors = FileNode.ancestorURLs(from: tree.url, to: target)

    let rows = tree.flattenedChildren(expandedURLs: Set(ancestors ?? []))

    #expect(rows.contains { $0.node.url == target })
}
