import Foundation
import Testing
@testable import CopacelCore

private func file(_ path: String, _ size: Int64) -> FileNode {
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

@Test func aChainOfSingleHeavyFoldersReportsTheOneHoldingTheSpace() {
    // ~/Games -> Nintendo -> Wii -> Disc, where all the weight is in Disc: reporting
    // "Games" would just restate the path.
    let tree = directory("/home", [
        directory("/home/Games", [
            directory("/home/Games/Nintendo", [
                directory("/home/Games/Nintendo/Wii", [
                    directory("/home/Games/Nintendo/Wii/Disc", [
                        file("/home/Games/Nintendo/Wii/Disc/a.wbfs", 500),
                        file("/home/Games/Nintendo/Wii/Disc/b.wbfs", 500)
                    ])
                ])
            ])
        ])
    ])

    let clusters = tree.largestClusters()

    #expect(clusters.map(\.url.path) == ["/home/Games/Nintendo/Wii/Disc"])
}

@Test func aFolderWhoseSpaceIsSpreadAcrossChildrenReportsItself() {
    // No single child dominates, so this folder is the natural boundary.
    let tree = directory("/home", [
        directory("/home/Samples", [
            directory("/home/Samples/a", [file("/home/Samples/a/1.wav", 100)]),
            directory("/home/Samples/b", [file("/home/Samples/b/1.wav", 100)]),
            directory("/home/Samples/c", [file("/home/Samples/c/1.wav", 100)])
        ])
    ])

    let clusters = tree.largestClusters()

    #expect(clusters.map(\.url.path) == ["/home/Samples"])
}

@Test func separateBranchesAreRankedAgainstEachOther() {
    let tree = directory("/home", [
        directory("/home/small", [
            directory("/home/small/x", [file("/home/small/x/1", 10)]),
            directory("/home/small/y", [file("/home/small/y/1", 10)])
        ]),
        directory("/home/big", [
            directory("/home/big/x", [file("/home/big/x/1", 400)]),
            directory("/home/big/y", [file("/home/big/y/1", 400)])
        ])
    ])

    let clusters = tree.largestClusters()

    #expect(clusters.map(\.url.lastPathComponent) == ["big", "small"])
    #expect(clusters.map(\.physicalSize) == [800, 20])
}

@Test func aDirectoryOfOnlyFilesIsACluster() {
    let tree = directory("/home", [
        directory("/home/ISOs", [
            file("/home/ISOs/a.iso", 900),
            file("/home/ISOs/b.iso", 900)
        ])
    ])

    #expect(tree.largestClusters().map(\.url.lastPathComponent) == ["ISOs"])
}

@Test func theScanRootIsNeverReportedAsItsOwnCluster() {
    let tree = directory("/home", [file("/home/loose.bin", 100)])

    // Everything sits directly in the root, so there's no sub-cluster to name.
    #expect(tree.largestClusters().isEmpty)
}

@Test func theLimitCapsTheResult() {
    let children = (0..<40).map { directory("/home/d\($0)", [file("/home/d\($0)/f", Int64(100 - $0))]) }
    let tree = directory("/home", children)

    let clusters = tree.largestClusters(limit: 5)

    #expect(clusters.count == 5)
    // Largest first.
    #expect(clusters.map(\.physicalSize) == [100, 99, 98, 97, 96])
}

@Test func emptyDirectoriesAreNotReported() {
    let tree = directory("/home", [
        directory("/home/empty", []),
        directory("/home/real", [file("/home/real/f", 50)])
    ])

    #expect(tree.largestClusters().map(\.url.lastPathComponent) == ["real"])
}
