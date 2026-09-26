import CoreGraphics
import Foundation
import Testing
@testable import CopacelCore

@Test func recursiveTilesCoversEveryLeafFileWithinBounds() {
    func file(_ name: String, size: Int64) -> FileNode {
        FileNode(
            url: URL(fileURLWithPath: "/root/\(name)"), name: name, isDirectory: false, isSymbolicLink: false,
            logicalSize: size, physicalSize: size, children: [], fileCount: 1
        )
    }

    let sub = FileNode(
        url: URL(fileURLWithPath: "/root/sub"), name: "sub", isDirectory: true, isSymbolicLink: false,
        logicalSize: 30, physicalSize: 30,
        children: [file("c.txt", size: 20), file("d.txt", size: 10)], fileCount: 2
    )
    let root = FileNode(
        url: URL(fileURLWithPath: "/root"), name: "root", isDirectory: true, isSymbolicLink: false,
        logicalSize: 100, physicalSize: 100,
        children: [file("a.txt", size: 50), file("b.txt", size: 20), sub], fileCount: 4
    )

    let rect = CGRect(x: 0, y: 0, width: 400, height: 300)
    let tiles = TreemapLayout.recursiveTiles(for: root, in: rect, minTileArea: 0)

    #expect(tiles.count == 4)
    #expect(Set(tiles.map(\.node.name)) == ["a.txt", "b.txt", "c.txt", "d.txt"])

    for tile in tiles {
        #expect(rect.contains(tile.rect.insetBy(dx: 0.001, dy: 0.001)))
    }

    let subTiles = tiles.filter { $0.node.name == "c.txt" || $0.node.name == "d.txt" }
    #expect(subTiles.allSatisfy { $0.depth == 2 })
}

@Test func recursiveTilesDropsSubtreesSmallerThanMinimumArea() {
    func file(_ name: String, size: Int64) -> FileNode {
        FileNode(
            url: URL(fileURLWithPath: "/root/\(name)"), name: name, isDirectory: false, isSymbolicLink: false,
            logicalSize: size, physicalSize: size, children: [], fileCount: 1
        )
    }

    let root = FileNode(
        url: URL(fileURLWithPath: "/root"), name: "root", isDirectory: true, isSymbolicLink: false,
        logicalSize: 1_000_000, physicalSize: 1_000_000,
        children: [file("huge.bin", size: 999_999), file("tiny.txt", size: 1)], fileCount: 2
    )

    let tiles = TreemapLayout.recursiveTiles(for: root, in: CGRect(x: 0, y: 0, width: 400, height: 300), minTileArea: 100)
    #expect(tiles.count == 1)
    #expect(tiles[0].node.name == "huge.bin")
}

@Test func recursiveTilesYieldsNothingWhenTheSurroundingTaskIsCancelled() async {
    func file(_ name: String, size: Int64) -> FileNode {
        FileNode(
            url: URL(fileURLWithPath: "/root/\(name)"), name: name, isDirectory: false, isSymbolicLink: false,
            logicalSize: size, physicalSize: size, children: [], fileCount: 1
        )
    }

    let root = FileNode(
        url: URL(fileURLWithPath: "/root"), name: "root", isDirectory: true, isSymbolicLink: false,
        logicalSize: 100, physicalSize: 100,
        children: [file("a.txt", size: 50), file("b.txt", size: 50)], fileCount: 2
    )

    // Yield until cancellation actually lands, so the call below deterministically runs
    // inside a cancelled task rather than racing `cancel()`.
    let task = Task {
        while !Task.isCancelled {
            await Task.yield()
        }
        return TreemapLayout.recursiveTiles(for: root, in: CGRect(x: 0, y: 0, width: 400, height: 300))
    }
    task.cancel()

    #expect(await task.value.isEmpty)
}
