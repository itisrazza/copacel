import CoreGraphics
import Testing
@testable import CopacelCore

@Test func squarifyConservesAreaAndPlacesEveryItem() {
    let sizes: [Double] = [100, 80, 30, 20, 15, 8, 3, 1]
    let rect = CGRect(x: 0, y: 0, width: 400, height: 200)

    let tiles = TreemapLayout.squarify(items: sizes, size: { $0 }, in: rect)

    #expect(tiles.count == sizes.count)

    let totalTileArea = tiles.reduce(0.0) { $0 + Double($1.rect.width) * Double($1.rect.height) }
    let expectedArea = Double(rect.width) * Double(rect.height)
    #expect(abs(totalTileArea - expectedArea) < 0.001)

    for tile in tiles {
        #expect(tile.rect.width >= 0)
        #expect(tile.rect.height >= 0)
        #expect(rect.contains(tile.rect.insetBy(dx: 0.001, dy: 0.001)))
    }
}

@Test func squarifyDropsZeroAndNegativeSizedItems() {
    let sizes: [Double] = [10, 0, -5, 20]
    let tiles = TreemapLayout.squarify(items: sizes, size: { $0 }, in: CGRect(x: 0, y: 0, width: 100, height: 100))
    #expect(tiles.count == 2)
}

@Test func squarifyHandlesEmptyInput() {
    let tiles = TreemapLayout.squarify(items: [Double](), size: { $0 }, in: CGRect(x: 0, y: 0, width: 100, height: 100))
    #expect(tiles.isEmpty)
}
