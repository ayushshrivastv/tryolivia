// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OliviaLogger",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "OliviaLogger",
            targets: ["OliviaLogger"]
        )
    ],
    targets: [
        .target(
            name: "OliviaLogger",
            path: "Sources"
        )
    ]
)
