// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CopacelCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CopacelCore", targets: ["CopacelCore"])
    ],
    targets: [
        .target(name: "CopacelCore"),
        .testTarget(name: "CopacelCoreTests", dependencies: ["CopacelCore"])
    ]
)
