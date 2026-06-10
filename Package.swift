// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HeedKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "HeedKit", targets: ["HeedKit"]),
    ],
    targets: [
        .target(name: "HeedKit", path: "Sources/HeedKit"),
        .testTarget(
            name: "HeedKitTests",
            dependencies: ["HeedKit"],
            path: "Tests/HeedKitTests"
        ),
    ]
)
