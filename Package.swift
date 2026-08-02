// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iCodex",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "iCodexCore",
            path: "Sources/iCodexCore"
        ),
        .executableTarget(
            name: "iCodex",
            dependencies: ["iCodexCore"],
            path: "Sources/iCodex"
        ),
    ]
)
