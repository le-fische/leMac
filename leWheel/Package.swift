// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "OpenLaunchy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "OpenLaunchy",
            targets: ["OpenLaunchy"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "OpenLaunchy",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/OpenLaunchy",
            resources: []
        )
    ]
)
