// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenTaskbar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "OpenTaskbar",
            path: "Sources/OpenTaskbar"
        ),
        .testTarget(
            name: "OpenTaskbarTests",
            dependencies: ["OpenTaskbar"],
            path: "Tests/OpenTaskbarTests"
        )
    ]
)