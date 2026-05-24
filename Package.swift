// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FeedbackHub",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "FeedbackHub", targets: ["FeedbackHub"]),
    ],
    targets: [
        .target(name: "FeedbackHub", path: "Sources/FeedbackHub"),
        .testTarget(
            name: "FeedbackHubTests",
            dependencies: ["FeedbackHub"],
            path: "Tests/FeedbackHubTests"
        ),
    ]
)
