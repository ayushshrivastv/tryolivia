// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "olivia",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "olivia",
            targets: ["olivia"]
        ),
    ],
    dependencies:[
        .package(path: "localPackages/Tor"),
        .package(path: "localPackages/OliviaLogger"),
        .package(url: "https://github.com/p2p-org/solana+Nostr+Noise-swift", from: "5.0.0")
        // Note: Magic Block SDK will be added when officially available
    ],
    targets: [
        .executableTarget(
            name: "olivia",
            dependencies: [
                .product(name: "OliviaLogger", package: "OliviaLogger"),
                .product(name: "Tor", package: "Tor"),
                .product(name: "SolanaSwift", package: "solana+Nostr+Noise-swift")
                // Note: Bolt SDK will be added when available
            ],
            path: "olivia",
            exclude: [
                "Info.plist",
                "Assets.xcassets",
                "olivia.entitlements",
                "olivia-macOS.entitlements",
                "LaunchScreen.storyboard"
            ],
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "oliviaTests",
            dependencies: ["olivia"],
            path: "oliviaTests",
            exclude: [
                "Info.plist",
                "README.md"
            ],
            resources: [
                .process("Localization")
            ]
        )
    ]
)
