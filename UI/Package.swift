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
        .package(path: "../Compute"),
        .package(path: "../Sync")
    ],
    targets: [
        .target(
            name: "WhoopUI",
            dependencies: ["BLE", "Compute", "Sync"],
            path: ".",
            exclude: ["Package.swift", "Tests", "README.md"],
            sources: ["TodayView.swift", "SettingsView.swift", "DeviceStepCounter.swift", "ConnectionAlertManager.swift", "EmotionalJournal.swift", "HealthMetricsStore.swift"]
        ),
        .testTarget(
            name: "WhoopUITests",
            dependencies: ["WhoopUI"],
            path: "Tests/WhoopUITests"
        )
    ]
)
