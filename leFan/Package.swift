// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "leFan",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "leFan", targets: ["leFan"]),
        .executable(name: "lefan-helper", targets: ["lefan-helper"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "SMCBridge",
            path: "Sources/SMCBridge",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation")
            ]
        ),
        .executableTarget(
            name: "leFan",
            dependencies: [
                "SMCBridge",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/leFan",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation")
            ]
        ),
        .executableTarget(
            name: "lefan-helper",
            path: "Sources/Helper",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation")
            ]
        )
    ]
)
