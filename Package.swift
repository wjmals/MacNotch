// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacNotch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacNotch",
            path: "Sources/MacNotch",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
