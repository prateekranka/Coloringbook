// swift-tools-version: 5.9
// This Package.swift is for reference and local Swift build testing.
// The authoritative build target is the Xcode project (ColorFlow.xcodeproj).
// No external dependencies — SVG parsing uses native Foundation XMLParser.

import PackageDescription

let package = Package(
    name: "ColorFlow",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "ColorFlow", targets: ["ColorFlow"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ColorFlow",
            dependencies: [],
            path: ".",
            exclude: ["Package.swift"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
