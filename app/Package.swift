// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "claude-notch",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "claude-notch",
            path: "Sources/claude-notch"
        )
    ]
)
