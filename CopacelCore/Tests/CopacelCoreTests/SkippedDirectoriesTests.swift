import Foundation
import Testing
@testable import CopacelCore

@Test func recordingCountsEveryDirectoryAndSeparatesTheFixableOnes() {
    var skipped = SkippedDirectories()
    skipped.record(url: URL(fileURLWithPath: "/Library/Trial"), failure: .protectedByPrivacy)
    skipped.record(url: URL(fileURLWithPath: "/Users/Guest"), failure: .permissionDenied)
    skipped.record(url: URL(fileURLWithPath: "/private/var/OOPJit"), failure: .protectedByPrivacy)

    #expect(skipped.total == 3)
    #expect(skipped.resolvableByFullDiskAccess == 2)
    #expect(skipped.isEmpty == false)
    #expect(skipped.exceedsSample == false)
}

@Test func aFreshTallyIsEmpty() {
    let skipped = SkippedDirectories()

    #expect(skipped.isEmpty)
    #expect(skipped.total == 0)
    #expect(skipped.sample.isEmpty)
    #expect(skipped.exceedsSample == false)
}

@Test func theSampleIsCappedButTheCountsAreNot() {
    var skipped = SkippedDirectories()
    let recorded = SkippedDirectories.sampleLimit + 500
    for index in 0..<recorded {
        skipped.record(url: URL(fileURLWithPath: "/denied/\(index)"), failure: .protectedByPrivacy)
    }

    #expect(skipped.total == recorded)
    #expect(skipped.resolvableByFullDiskAccess == recorded)
    #expect(skipped.sample.count == SkippedDirectories.sampleLimit)
    #expect(skipped.exceedsSample)
    // The sample keeps the first ones seen rather than a random slice.
    #expect(skipped.sample.first?.url.lastPathComponent == "0")
}
