// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DeskModeKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DeskModeCore", targets: ["DeskModeCore"]),
        .library(name: "DeskModePlatform", targets: ["DeskModePlatform"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/sindresorhus/KeyboardShortcuts.git",
            exact: "3.0.1"
        )
    ],
    targets: [
        .target(name: "DeskModeCore"),
        .target(
            name: "DeskModePlatform",
            dependencies: [
                "DeskModeCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ]
        ),
        .testTarget(
            name: "DeskModeCoreTests",
            dependencies: ["DeskModeCore"]
        ),
        .testTarget(
            name: "DeskModePlatformTests",
            dependencies: ["DeskModePlatform"]
        )
    ],
    swiftLanguageModes: [.v6]
)
