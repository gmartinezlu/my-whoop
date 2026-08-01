// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Protocol",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WhoopProtocol", targets: ["WhoopProtocol"])
    ],
    targets: [
        .target(
            name: "WhoopProtocol",
            path: ".",
            exclude: ["Package.swift", "Tests", "README.md"],
            sources: ["BLEProtocolDecoder.swift", "ProtocolConstants.swift"]
        ),
        .testTarget(
            name: "WhoopProtocolTests",
            dependencies: ["WhoopProtocol"],
            path: "Tests/WhoopProtocolTests"
        )
    ]
)
