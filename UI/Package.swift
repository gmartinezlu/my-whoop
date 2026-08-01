// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WhoopUI", targets: ["WhoopUI"])
    ],
    dependencies: [
        .package(path: "../BLE"),
        .package(path: "../Sync")
    ],
    targets: [
        .target(
            name: "WhoopUI",
            dependencies: ["BLE", "Sync"],
            path: ".",
            exclude: ["Package.swift", "Tests", "README.md"],
            sources: ["TodayView.swift", "SettingsView.swift"]
        ),
        .testTarget(
            name: "WhoopUITests",
            dependencies: ["WhoopUI"],
            path: "Tests/WhoopUITests"
        )
    ]
)
