import Foundation
import Testing
@testable import CopacelCore

struct CategoryCase: Sendable, CustomStringConvertible {
    let fileExtension: String
    let category: FileCategory

    var description: String { "\(fileExtension.isEmpty ? "(none)" : fileExtension) -> \(category.rawValue)" }
}

@Test(arguments: [
    // The five that together account for ~170 GB on the machine this was built for.
    CategoryCase(fileExtension: "vmdk", category: .diskImages),
    CategoryCase(fileExtension: "iso", category: .diskImages),
    CategoryCase(fileExtension: "img", category: .diskImages),
    CategoryCase(fileExtension: "wbfs", category: .diskImages),
    CategoryCase(fileExtension: "qcow2", category: .diskImages),
    CategoryCase(fileExtension: "o", category: .buildOutput),
    CategoryCase(fileExtension: "dylib", category: .buildOutput),
    CategoryCase(fileExtension: "jar", category: .archives),
    CategoryCase(fileExtension: "zip", category: .archives),
    CategoryCase(fileExtension: "wav", category: .audio),
    CategoryCase(fileExtension: "mp4", category: .video),
    CategoryCase(fileExtension: "heic", category: .images),
    CategoryCase(fileExtension: "pdf", category: .documents),
    CategoryCase(fileExtension: "swift", category: .code),
    // Unrecognised, and the empty string standing for "no extension at all".
    CategoryCase(fileExtension: "wibble", category: .other),
    CategoryCase(fileExtension: "", category: .other)
])
func extensionsMapToTheirCategory(testCase: CategoryCase) {
    #expect(FileCategory.forExtension(testCase.fileExtension) == testCase.category)
}

@Test func lookupIsCaseInsensitive() {
    #expect(FileCategory.forExtension("ISO") == .diskImages)
    #expect(FileCategory.forExtension("Vmdk") == .diskImages)
}

@Test func noExtensionIsClaimedByTwoCategories() {
    // A duplicate would make the reverse index order-dependent, so which category an
    // extension lands in would vary with dictionary iteration order.
    var owner: [String: FileCategory] = [:]
    for (category, extensions) in FileCategory.extensionsByCategory {
        for fileExtension in extensions {
            #expect(
                owner[fileExtension] == nil,
                "\(fileExtension) is claimed by both \(owner[fileExtension]?.rawValue ?? "?") and \(category.rawValue)"
            )
            owner[fileExtension] = category
        }
    }
}

@Test func aggregationRollsExtensionsUpAndRanksBySize() throws {
    let stats = [
        ExtensionStat(fileExtension: "vmdk", fileCount: 42, totalLogicalSize: 60, totalPhysicalSize: 57),
        ExtensionStat(fileExtension: "iso", fileCount: 26, totalLogicalSize: 45, totalPhysicalSize: 42),
        ExtensionStat(fileExtension: "o", fileCount: 174_269, totalLogicalSize: 22, totalPhysicalSize: 21),
        ExtensionStat(fileExtension: "swift", fileCount: 900, totalLogicalSize: 1, totalPhysicalSize: 1)
    ]

    let categories = CategoryStats.aggregate(from: stats)

    #expect(categories.map(\.category) == [.diskImages, .buildOutput, .code])
    let diskImages = try #require(categories.first)
    #expect(diskImages.totalPhysicalSize == 99)
    #expect(diskImages.fileCount == 68)
    // Largest extension first, so the legend can say what dominates the category.
    #expect(diskImages.extensions == ["vmdk", "iso"])
}

@Test func unrecognisedAndExtensionlessFilesShareTheOtherCategory() {
    let stats = [
        ExtensionStat(fileExtension: "", fileCount: 341_900, totalLogicalSize: 95, totalPhysicalSize: 90),
        ExtensionStat(fileExtension: "wibble", fileCount: 3, totalLogicalSize: 2, totalPhysicalSize: 2)
    ]

    let categories = CategoryStats.aggregate(from: stats)

    #expect(categories.map(\.category) == [.other])
    #expect(categories[0].fileCount == 341_903)
    #expect(categories[0].totalPhysicalSize == 92)
}
