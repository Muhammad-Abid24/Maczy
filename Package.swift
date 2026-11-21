// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Maczy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Maczy", targets: ["Maczy"]),
        .library(name: "MaczyKit", targets: ["MaczyKit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MaczyKit",
            dependencies: [],
            path: "apps/macos/MaczyKit"
        ),
        .executableTarget(
            name: "Maczy",
            dependencies: ["MaczyKit"],
            path: "apps/macos/MaczyApp"
        ),
        .testTarget(
            name: "MaczyTests",
            dependencies: ["MaczyKit"],
            path: "Tests/MaczyTests"
        )
    ]
)
