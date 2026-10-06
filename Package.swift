// swift-tools-version: 6.3

import PackageDescription

let strictSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(nil),
    .strictMemorySafety(),
]

let package = Package(
    name: "ScrollableTabBar",
    platforms: [
        .iOS("18.4"),
    ],
    products: [
        .library(
            name: "ScrollableTabBar",
            targets: ["ScrollableTabBar"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lynnswap/ABIBridge.git", .upToNextMinor(from: "0.8.1")),
    ],
    targets: [
        .target(
            name: "ScrollableTabBar",
            dependencies: ["ABIBridge"],
            swiftSettings: strictSwiftSettings
        ),
        .testTarget(
            name: "ScrollableTabBarTests",
            dependencies: ["ScrollableTabBar"],
            swiftSettings: strictSwiftSettings
        ),
    ]
)
