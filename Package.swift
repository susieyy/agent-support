// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "agent-support",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "agent-support", targets: ["agent-support"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "agent-support",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/agent-support"
        ),
        .testTarget(
            name: "agent-supportTests",
            dependencies: ["agent-support"],
            path: "Tests/agent-supportTests"
        )
    ]
)
