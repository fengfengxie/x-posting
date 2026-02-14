// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XPosting",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "XPostingCore", targets: ["XPostingCore"]),
        .executable(name: "x-posting", targets: ["XPostingApp"])
    ],
    targets: [
        .target(
            name: "XPostingCore",
            path: "src/XPostingCore"
        ),
        .executableTarget(
            name: "XPostingApp",
            dependencies: ["XPostingCore"],
            path: "src/XPostingApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "XPostingCoreTests",
            dependencies: ["XPostingCore"],
            path: "src/XPostingCoreTests"
        )
    ]
)
