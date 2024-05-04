// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CustomizableLayout",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "CustomizableLayout",
            targets: ["CustomizableLayout"]),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidGroup/Texture.git", from: "3.0.2")
    ],
    targets: [
        .target(
            name: "CustomizableLayout",
            dependencies: [
                .product(name: "AsyncDisplayKit", package: "Texture")
            ]
        ),
        .testTarget(
            name: "CustomizableLayoutTests",
            dependencies: ["CustomizableLayout"]),
    ]
)
