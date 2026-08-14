import CopacelCore
import Foundation

/// Manual, not-automated check that ``DirectoryScanner`` treats a mounted volume as a
/// boundary rather than crossing into it. Exercises the real `getmntinfo` mount-table
/// check (see DirectoryScanner.mountPointPaths) end to end, using a real disk image —
/// something a unit test can't easily do without risking a dangling mount if interrupted.
///
/// Run manually with:
///   swift run --package-path CopacelCore VerifyMountBoundary
@main
struct VerifyMountBoundary {
    static func main() async {
        do {
            try await run()
        } catch {
            print("ERROR: \(error)")
            exit(1)
        }
    }

    private static func run() async throws {
        let fileManager = FileManager.default
        let workDir = fileManager.temporaryDirectory.appendingPathComponent("copacel-mount-boundary-\(UUID().uuidString)")
        try fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)

        let mountPoint = workDir.appendingPathComponent("mounted")
        try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        let imageBase = workDir.appendingPathComponent("scanner-test-volume")
        let imagePath = imageBase.path + ".dmg"

        var isMounted = false
        defer {
            if isMounted {
                try? runTool("/usr/bin/hdiutil", ["detach", mountPoint.path, "-quiet", "-force"])
            }
            try? fileManager.removeItem(at: workDir)
        }

        print("Creating a 10 MB APFS disk image at \(imagePath)…")
        try runTool("/usr/bin/hdiutil", [
            "create", "-size", "10m", "-fs", "APFS", "-volname", "ScannerTestVolume", "-quiet", imageBase.path
        ])

        print("Mounting it at \(mountPoint.path)…")
        try runTool("/usr/bin/hdiutil", [
            "attach", imagePath, "-mountpoint", mountPoint.path, "-nobrowse", "-quiet"
        ])
        isMounted = true

        try Data("this file lives on a separate mounted volume".utf8)
            .write(to: mountPoint.appendingPathComponent("secret.txt"))

        print("Scanning \(workDir.path)…")
        let scanned = try await DirectoryScanner().scan(root: workDir)

        guard let mountedNode = scanned.children.first(where: { $0.name == "mounted" }) else {
            print("FAIL: no \"mounted\" entry found in the scan result at all.")
            exit(1)
        }

        if mountedNode.fileCount == 0, mountedNode.logicalSize == 0, mountedNode.children.isEmpty {
            print("PASS: the mounted volume was treated as a boundary (fileCount=0, children=0).")
        } else {
            print("""
            FAIL: the scanner crossed into the mounted volume instead of stopping at it — \
            fileCount=\(mountedNode.fileCount), logicalSize=\(mountedNode.logicalSize), \
            children=\(mountedNode.children.count)
            """)
            exit(1)
        }
    }

    private static func runTool(_ launchPath: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ToolError.nonZeroExit(tool: launchPath, arguments: arguments, status: process.terminationStatus)
        }
    }

    private enum ToolError: Error, CustomStringConvertible {
        case nonZeroExit(tool: String, arguments: [String], status: Int32)

        var description: String {
            switch self {
            case let .nonZeroExit(tool, arguments, status):
                return "\(tool) \(arguments.joined(separator: " ")) exited with status \(status)"
            }
        }
    }
}
