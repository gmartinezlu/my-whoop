// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Storage",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Storage", targets: ["Storage"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0")
    ],
    targets: [
        .target(
            name: "Storage",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            path: ".",
            exclude: ["Package.swift", "Tests", "README.md"],
            sources: ["LocalStore.swift", "SyncOutbox.swift"]
        ),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Storage"],
            path: "Tests/StorageTests"
        )
    ]
)
