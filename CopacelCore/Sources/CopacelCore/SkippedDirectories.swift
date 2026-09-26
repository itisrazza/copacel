import Foundation

/// Running tally of the directories a scan couldn't read.
///
/// Keeps every count but only a bounded sample of the paths themselves: scanning a volume
/// can refuse hundreds or thousands of directories, and no UI shows more than a screenful.
public struct SkippedDirectories: Sendable, Equatable {
    public struct Entry: Identifiable, Sendable, Equatable, Hashable {
        public let url: URL
        public let failure: DirectoryReadFailure

        public init(url: URL, failure: DirectoryReadFailure) {
            self.url = url
            self.failure = failure
        }

        public var id: URL { url }
    }

    public static let sampleLimit = 250

    /// Directories worth telling the user about — everything except ``routine``.
    public private(set) var total = 0
    /// How many of them granting Full Disk Access would actually make readable. The rest are
    /// refused by ordinary filesystem permissions, which that grant doesn't affect.
    public private(set) var resolvableByFullDiskAccess = 0
    public private(set) var sample: [Entry] = []
    /// Directories skipped for reasons the user can do nothing about — see ``RoutineSkips``.
    /// Counted so the total can still be accounted for, but kept out of the headline.
    public private(set) var routine = 0

    public init() {}

    public var isEmpty: Bool { total == 0 }

    /// Whether more directories were skipped than ``sample`` retains.
    public var exceedsSample: Bool { total > sample.count }

    public mutating func record(url: URL, failure: DirectoryReadFailure) {
        guard !RoutineSkips.isRoutine(url) else {
            routine += 1
            return
        }

        total += 1
        if failure.isResolvedByFullDiskAccess {
            resolvableByFullDiskAccess += 1
        }
        guard sample.count < Self.sampleLimit else { return }
        sample.append(Entry(url: url, failure: failure))
    }
}
