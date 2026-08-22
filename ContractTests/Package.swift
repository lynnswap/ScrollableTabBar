// swift-tools-version: 6.3

import PackageDescription

let strictSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(nil),
    .strictMemorySafety(),
]

let package = Package(
    name: "ScrollableTabBarProductContract",
    platforms: [
        .iOS(.v18),
    ],
    dependencies: [
        .package(path: ".."),
    ],
    targets: [
        .testTarget(
            name: "ScrollableTabBarProductContractTests",
            dependencies: [
                .product(
                    name: "ScrollableTabBar",
                    package: "ScrollableTabBar"
                ),
            ],
            swiftSettings: strictSwiftSettings
        ),
    ]
)
