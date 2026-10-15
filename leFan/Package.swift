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
    dependencies: [],
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
            dependencies: ["SMCBridge"],
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
