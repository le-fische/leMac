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
    targets: [
        .executableTarget(
            name: "OpenLaunchy",
            path: "Sources/OpenLaunchy",
            resources: []
        )
    ]
)
