// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Zone51Control",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Zone51Control", targets: ["Zone51Control"]),
        .executable(name: "zone51-tool", targets: ["Zone51Tool"])
    ],
    targets: [
        .target(name: "Zone51Core", resources: [.process("Resources")]),
        .executableTarget(name: "Zone51Control", dependencies: ["Zone51Core"]),
        .executableTarget(name: "Zone51Tool", dependencies: ["Zone51Core"]),
        .testTarget(name: "Zone51CoreTests", dependencies: ["Zone51Core"], resources: [.copy("Fixtures")])
    ]
)
