// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FeatureKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "FeatureKit", targets: ["FeatureKit"]),
    ],
    targets: [
        .target(name: "FeatureKit", path: "Sources/FeatureKit"),
        .testTarget(
            name: "FeatureKitTests",
            dependencies: ["FeatureKit"],
            path: "Tests/FeatureKitTests"
        ),
    ]
)
