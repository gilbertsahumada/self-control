// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BlockSites",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "BlockSitesCore",
            path: "Sources/BlockSitesCore"
        ),
        .executableTarget(
            name: "BlockSites",
            dependencies: [
                "BlockSitesCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/BlockSites",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .executableTarget(
            name: "BlockSitesEnforcer",
            dependencies: [
                "BlockSitesCore"
            ],
            path: "Sources/BlockSitesEnforcer"
        ),
        .testTarget(
            name: "BlockSitesCoreTests",
            dependencies: ["BlockSitesCore"],
            path: "Tests/BlockSitesCoreTests"
        )
    ]
)
