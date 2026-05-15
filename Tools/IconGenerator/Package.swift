// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "IconGenerator",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "IconGenerator", targets: ["IconGenerator"]),
    ],
    targets: [
        .executableTarget(
            name: "IconGenerator",
            swiftSettings: [.enableExperimentalFeature("BareSlashRegexLiterals")]
        ),
    ]
)
