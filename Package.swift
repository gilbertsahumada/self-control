// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BlockSites",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "BlockSitesCore",
            path: "Sources/BlockSitesCore"
        ),
        .executableTarget(
            name: "BlockSitesApp",
            dependencies: [
                "BlockSitesCore"
            ],
            path: "Sources/BlockSitesApp"
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
        ),
        .testTarget(
            name: "BlockSitesE2ETests",
            dependencies: ["BlockSitesCore"],
            path: "Tests/BlockSitesE2ETests"
        )
    ]
)
