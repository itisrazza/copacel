import SwiftUI

/// Assigns each file extension a stable colour, so the same extension always looks the
/// same across the legend and the treemap — and across app launches, since Swift's
/// built-in `Hashable` is deliberately randomized per process and can't be used here.
enum ColorAssignment {
    static func color(forExtension ext: String) -> Color {
        guard !ext.isEmpty else { return .gray }
        let hue = Double(fnv1aHash(ext) % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.85)
    }

    private static func fnv1aHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
