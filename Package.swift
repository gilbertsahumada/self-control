// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MonkMode",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "MonkModeCore",
            path: "Sources/BlockSitesCore"
        ),
        .executableTarget(
            name: "MonkMode",
            dependencies: [
                "MonkModeCore"
            ],
            path: "Sources/BlockSitesApp"
        ),
        .executableTarget(
            name: "MonkModeEnforcer",
            dependencies: [
                "MonkModeCore"
            ],
            path: "Sources/BlockSitesEnforcer"
        ),
        .testTarget(
            name: "MonkModeCoreTests",
            dependencies: ["MonkModeCore"],
            path: "Tests/BlockSitesCoreTests"
        ),
        .testTarget(
            name: "MonkModeE2ETests",
            dependencies: ["MonkModeCore"],
            path: "Tests/BlockSitesE2ETests"
        )
    ]
)
