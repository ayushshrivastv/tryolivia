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
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", exact: "0.21.1")
    ],
    targets: [
        .executableTarget(
            name: "olivia",
            dependencies: [
                .product(name: "P256K", package: "swift-secp256k1"),
                .product(name: "OliviaLogger", package: "OliviaLogger"),
                .product(name: "Tor", package: "Tor")
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
