// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "claude-notch",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "claude-notch",
            path: "Sources/claude-notch",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
