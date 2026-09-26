import Darwin
import Foundation

public enum FullDiskAccess {
    /// A file that only a process holding Full Disk Access can open. It's a real file on
    /// every supported macOS — unlike the `~/Library/Application Support/com.apple.TCC/TCC.db`
    /// path often suggested for this, which doesn't exist at all on current versions and so
    /// can't tell a missing grant from a missing file.
    private static let probePath = "/Library/Application Support/com.apple.TCC/TCC.db"

    /// Whether this process appears to hold Full Disk Access.
    ///
    /// macOS exposes no API for this, so it's inferred by opening a file the grant gates.
    /// The probe is silent: unlike Documents or Desktop, Full Disk Access never prompts, it
    /// just refuses. A refusal arrives as `EPERM`; anything else isn't evidence of a missing
    /// grant, so this reports `true` rather than nagging on a cause it doesn't understand.
    public static func isGranted() -> Bool {
        let descriptor = open(probePath, O_RDONLY)
        guard descriptor < 0 else {
            close(descriptor)
            return true
        }
        return errno != EPERM
    }
}
