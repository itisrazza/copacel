import Foundation
import Testing
@testable import CopacelCore

struct PatternCase: Sendable, CustomStringConvertible {
    let pattern: String
    let path: String
    let matches: Bool

    var description: String { "\(pattern) vs \(path) == \(matches)" }
}

@Test(arguments: [
    // A pattern covers the path it names and everything beneath it.
    PatternCase(pattern: "/private", path: "/private", matches: true),
    PatternCase(pattern: "/private", path: "/private/var/folders", matches: true),
    PatternCase(pattern: "/private", path: "/privateer", matches: false),
    PatternCase(pattern: "/private", path: "/", matches: false),
    // Exact directory.
    PatternCase(pattern: "/Users/Guest", path: "/Users/Guest", matches: true),
    PatternCase(pattern: "/Users/Guest", path: "/Users/Guest/Documents", matches: true),
    PatternCase(pattern: "/Users/Guest", path: "/Users/Guesty", matches: false),
    PatternCase(pattern: "/Users/Guest", path: "/Users", matches: false),
    // A wildcard stands for exactly one component, never several.
    PatternCase(pattern: "/Users/*/.Trash", path: "/Users/razz/.Trash", matches: true),
    PatternCase(pattern: "/Users/*/.Trash", path: "/Users/anca/.Trash", matches: true),
    PatternCase(pattern: "/Users/*/.Trash", path: "/Users/razz/.Trash/old.txt", matches: true),
    PatternCase(pattern: "/Users/*/.Trash", path: "/Users/razz/Documents", matches: false),
    PatternCase(pattern: "/Users/*/.Trash", path: "/Users/a/b/.Trash", matches: false),
    PatternCase(pattern: "/Users/*/.Trash", path: "/Users/.Trash", matches: false)
])
func pathPatternsMatchByComponent(testCase: PatternCase) {
    let pattern = PathPattern(testCase.pattern)

    #expect(pattern.matches(URL(fileURLWithPath: testCase.path)) == testCase.matches)
}

@Test func theDefaultPatternsCoverTheKnownNoiseButNotRealData() {
    func isRoutine(_ path: String) -> Bool {
        RoutineSkips.isRoutine(URL(fileURLWithPath: path))
    }

    #expect(isRoutine("/private/var/folders"))
    #expect(isRoutine("/private/var/db/sudo"))
    #expect(isRoutine("/Users/Guest"))
    #expect(isRoutine("/Users/razz/.Trash"))

    // The denials worth acting on must stay visible — these are the bulk of them.
    #expect(isRoutine("/Users/razz/Library/Containers") == false)
    #expect(isRoutine("/Users/razz/Library/Safari") == false)
    #expect(isRoutine("/System/Library/Caches") == false)
    #expect(isRoutine("/Library/Trial") == false)
}

@Test func routineSkipsAreCountedSeparatelyFromReportedOnes() {
    var skipped = SkippedDirectories()
    skipped.record(url: URL(fileURLWithPath: "/private/var/folders"), failure: .permissionDenied)
    skipped.record(url: URL(fileURLWithPath: "/Users/razz/.Trash"), failure: .protectedByPrivacy)
    skipped.record(url: URL(fileURLWithPath: "/Users/razz/Library/Safari"), failure: .protectedByPrivacy)

    #expect(skipped.routine == 2)
    #expect(skipped.total == 1)
    #expect(skipped.resolvableByFullDiskAccess == 1)
    #expect(skipped.sample.map(\.url.lastPathComponent) == ["Safari"])
}

@Test func aScanSkippingOnlyRoutineDirectoriesRaisesNothing() {
    var skipped = SkippedDirectories()
    skipped.record(url: URL(fileURLWithPath: "/private/var/db"), failure: .permissionDenied)
    skipped.record(url: URL(fileURLWithPath: "/Users/Guest"), failure: .permissionDenied)

    // Nothing the user can act on, so the banner stays away entirely.
    #expect(skipped.isEmpty)
    #expect(skipped.routine == 2)
}
