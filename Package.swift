// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "ArgumentParser",
    products: [
        .library(
            name: "ArgumentParser",
            targets: ["ArgumentParser"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ArgumentParser",
            dependencies: []),
        .testTarget(
            name: "ArgumentParserTests",
            dependencies: ["ArgumentParser"]),
    ]
)
