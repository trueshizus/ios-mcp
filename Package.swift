// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HealthKitMCP",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "HealthKitMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ]
        )
    ]
)
