// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sync",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Sync", targets: ["Sync"])
    ],
    targets: [
        .target(
            name: "Sync",
            path: ".",
            exclude: ["Package.swift", "Tests", "README.md"],
            sources: ["Config.swift", "VentoBridge.swift"]
        ),
        .testTarget(
            name: "SyncTests",
            dependencies: ["Sync"],
            path: "Tests/SyncTests"
        )
    ]
)
