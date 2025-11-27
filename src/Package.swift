// swift-tools-version: 5.9
import PackageDescription

#if os(Linux)
let package = Package(
    name: "VibeProxy",
    platforms: [
        .macOS(.v13)  // Keep for compatibility, Linux ignores this
    ],
    products: [
        .executable(
            name: "vibeproxy",
            targets: ["VibeProxyLinux"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "VibeProxyLinux",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "SourcesLinux",
            resources: [
                .copy("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
#else
let package = Package(
    name: "CLIProxyMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CLIProxyMenuBar",
            targets: ["CLIProxyMenuBar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CLIProxyMenuBar",
            path: "Sources",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
#endif
