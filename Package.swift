// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SelfControl",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "SelfControlCore",
            path: "Sources/BlockSitesCore"
        ),
        .executableTarget(
            name: "SelfControl",
            dependencies: [
                "SelfControlCore"
            ],
            path: "Sources/BlockSitesApp"
        ),
        .executableTarget(
            name: "SelfControlEnforcer",
            dependencies: [
                "SelfControlCore"
            ],
            path: "Sources/BlockSitesEnforcer"
        ),
        .testTarget(
            name: "SelfControlCoreTests",
            dependencies: ["SelfControlCore"],
            path: "Tests/BlockSitesCoreTests"
        ),
        .testTarget(
            name: "SelfControlE2ETests",
            dependencies: ["SelfControlCore"],
            path: "Tests/BlockSitesE2ETests"
        )
    ]
)
