import Foundation

/// A path matched component by component, where `*` stands for exactly one component.
///
/// A pattern matches the path it names and everything beneath it, so `/private` covers
/// `/private/var/folders`. Matching components rather than string prefixes keeps `/Users/raz`
/// from matching `/Users/razz`.
public struct PathPattern: Sendable, Equatable, Hashable {
    public static let wildcard = "*"

    private let components: [String]

    public init(_ pattern: String) {
        self.components = URL(fileURLWithPath: pattern).pathComponents
    }

    public func matches(_ url: URL) -> Bool {
        let target = url.pathComponents
        guard target.count >= components.count else { return false }
        return zip(components, target).allSatisfy { $0 == Self.wildcard || $0 == $1 }
    }
}

public enum RoutineSkips {
    /// Directories whose unreadability is routine: system-managed state and other users'
    /// private data. Nothing the user can do opens these, so listing them among the folders
    /// they *can* act on just buries the actionable ones.
    ///
    /// This only filters what gets reported. These paths are still walked, still recorded in
    /// the tree, and still contribute whatever they contain — `/private` alone holds several
    /// gigabytes of perfectly readable data, and excluding it from the scan would quietly
    /// understate every boot-volume total.
    public static let defaultPatterns: [PathPattern] = [
        PathPattern("/private"),
        PathPattern("/Users/Guest"),
        PathPattern("/Users/\(PathPattern.wildcard)/.Trash")
    ]

    public static func isRoutine(_ url: URL, patterns: [PathPattern] = defaultPatterns) -> Bool {
        patterns.contains { $0.matches(url) }
    }
}
