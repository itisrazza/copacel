import Foundation
import Testing
@testable import CopacelCore

@Test func sortedOrdersBootVolumeFirstThenInternalBeforeRemovableThenAlphabetically() {
    func volume(_ name: String, boot: Bool = false, removable: Bool = false) -> VolumeInfo {
        VolumeInfo(
            url: URL(fileURLWithPath: "/Volumes/\(name)"), name: name,
            capacity: nil, available: nil, isBootVolume: boot, isRemovable: removable
        )
    }

    let input = [
        volume("USB Drive", removable: true),
        volume("Data"),
        volume("Backup", removable: true),
        volume("Macintosh HD", boot: true)
    ]

    let sorted = VolumeInfo.sorted(input)
    #expect(sorted.map(\.name) == ["Macintosh HD", "Data", "Backup", "USB Drive"])
}

@Test func usedSpaceAndPercentageComputeFromCapacityAndAvailable() {
    let volume = VolumeInfo(
        url: URL(fileURLWithPath: "/"), name: "Macintosh HD",
        capacity: 1000, available: 300, isBootVolume: true, isRemovable: false
    )
    #expect(volume.usedSpace == 700)
    #expect(volume.usedPercentage == 70.0)
}

@Test func usedSpaceAndPercentageAreNilWhenCapacityOrAvailableIsUnknown() {
    let missingBoth = VolumeInfo(
        url: URL(fileURLWithPath: "/"), name: "X", capacity: nil, available: nil,
        isBootVolume: false, isRemovable: false
    )
    #expect(missingBoth.usedSpace == nil)
    #expect(missingBoth.usedPercentage == nil)

    let missingAvailable = VolumeInfo(
        url: URL(fileURLWithPath: "/"), name: "X", capacity: 1000, available: nil,
        isBootVolume: false, isRemovable: false
    )
    #expect(missingAvailable.usedSpace == nil)
    #expect(missingAvailable.usedPercentage == nil)
}

@Test func usedPercentageIsNilWhenCapacityIsZero() {
    let volume = VolumeInfo(
        url: URL(fileURLWithPath: "/"), name: "X", capacity: 0, available: 0,
        isBootVolume: false, isRemovable: false
    )
    #expect(volume.usedPercentage == nil)
}

@Test func formattedUsedSpaceFallsBackToUnknownWhenDataIsMissing() {
    let volume = VolumeInfo(
        url: URL(fileURLWithPath: "/"), name: "X", capacity: nil, available: nil,
        isBootVolume: false, isRemovable: false
    )
    #expect(volume.formattedUsedSpace == "Unknown")
}

@Test func formattedUsedSpaceMatchesByteCountFormatterWhenDataIsKnown() {
    let volume = VolumeInfo(
        url: URL(fileURLWithPath: "/"), name: "X", capacity: 1000, available: 300,
        isBootVolume: false, isRemovable: false
    )
    let expected = ByteCountFormatter.string(fromByteCount: 700, countStyle: .file) + " used"
    #expect(volume.formattedUsedSpace == expected)
}
