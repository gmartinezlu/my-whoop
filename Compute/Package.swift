// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Compute",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Compute", targets: ["Compute"])
    ],
    targets: [
        .target(
            name: "Compute",
            path: ".",
            exclude: ["Package.swift", "Tests", "README.md"],
            sources: [
                "HRVAnalyzer.swift",
                "RecoveryScorer.swift",
                "StrainScorer.swift",
                "SleepStager.swift",
                "StressAnalyzer.swift",
                "WorkoutDetector.swift"
            ]
        ),
        .testTarget(
            name: "ComputeTests",
            dependencies: ["Compute"],
            path: "Tests/ComputeTests"
        )
    ]
)
