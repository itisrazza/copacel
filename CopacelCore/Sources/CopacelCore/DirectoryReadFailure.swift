import Darwin
import Foundation

/// Why a directory's contents couldn't be listed.
///
/// Worth distinguishing, because the remedy differs: macOS privacy protection is something
/// the user can grant their way out of, while an ordinary permission denial on a root-owned
/// directory isn't.
public enum DirectoryReadFailure: Error, Sendable, Equatable, Hashable {
    /// Refused by macOS privacy protection (TCC), which surfaces as `EPERM`. Granting the
    /// app Full Disk Access makes these readable.
    case protectedByPrivacy
    /// Refused by ordinary filesystem permissions (`EACCES`) — typically root-owned.
    /// Full Disk Access makes no difference.
    case permissionDenied
    /// Anything else, carrying the raw code rather than guessing at a cause.
    case other(code: Int32)

    init(code: Int32) {
        switch code {
        case EPERM: self = .protectedByPrivacy
        case EACCES: self = .permissionDenied
        default: self = .other(code: code)
        }
    }

    /// Whether granting Full Disk Access would make this directory readable.
    public var isResolvedByFullDiskAccess: Bool { self == .protectedByPrivacy }

    public var localizedDescription: String {
        switch self {
        case .protectedByPrivacy: "Protected by macOS privacy settings"
        case .permissionDenied: "You don't have permission to read this folder"
        case .other(let code): String(cString: strerror(code))
        }
    }
}
