// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BLE",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BLE", targets: ["BLE"])
    ],
    dependencies: [
        .package(path: "../Protocol")
    ],
    targets: [
        .target(
            name: "BLE",
            dependencies: [.product(name: "WhoopProtocol", package: "Protocol")],
            path: ".",
            exclude: ["Package.swift", "Tests", "README.md"],
            sources: ["BLEConnectionState.swift", "BLEManager.swift"]
        ),
        .testTarget(
            name: "BLETests",
            dependencies: ["BLE"],
            path: "Tests/BLETests"
        )
    ]
)
