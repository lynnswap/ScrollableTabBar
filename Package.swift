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
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "ScrollableTabBar",
            targets: ["ScrollableTabBar"]
        ),
    ],
    targets: [
        .target(
            name: "ScrollableTabBar",
            swiftSettings: strictSwiftSettings
        ),
        .testTarget(
            name: "ScrollableTabBarTests",
            dependencies: ["ScrollableTabBar"],
            swiftSettings: strictSwiftSettings
        ),
    ]
)
