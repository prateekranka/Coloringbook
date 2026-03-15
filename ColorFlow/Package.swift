// swift-tools-version: 5.9
// This Package.swift is for reference and local Swift build testing.
// The authoritative build target is the Xcode project (ColorFlow.xcodeproj).
// Add SVGKit via Xcode > File > Add Package Dependencies:
//   https://github.com/SVGKit/SVGKit  (pin to a specific commit for stability)

import PackageDescription

let package = Package(
    name: "ColorFlow",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "ColorFlow", targets: ["ColorFlow"])
    ],
    dependencies: [
        // SVGKit for rendering royalty-free SVG templates
        .package(url: "https://github.com/SVGKit/SVGKit.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "ColorFlow",
            dependencies: [
                .product(name: "SVGKit", package: "SVGKit"),
            ],
            path: ".",
            exclude: ["Package.swift"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
