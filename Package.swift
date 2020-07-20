// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BlueDress",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(
            name: "BlueDress",
            targets: ["BlueDress"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "BlueDress",
            resources: [
                .process("default.metal")
            ]
        ),
        .testTarget(
            name: "BlueDressTests",
            dependencies: ["BlueDress"]
        )
    ]
)
