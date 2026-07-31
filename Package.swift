// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HeadlessGuard",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "HeadlessGuardKit", targets: ["HeadlessGuardKit"]),
        .executable(name: "headless-guard", targets: ["HeadlessGuardCLI"]),
        .executable(name: "HeadlessGuardApp", targets: ["HeadlessGuardApp"])
    ],
    targets: [
        .target(name: "HeadlessGuardKit"),
        .executableTarget(
            name: "HeadlessGuardCLI",
            dependencies: ["HeadlessGuardKit"]
        ),
        .executableTarget(
            name: "HeadlessGuardApp",
            dependencies: ["HeadlessGuardKit"]
        ),
        .testTarget(
            name: "HeadlessGuardKitTests",
            dependencies: ["HeadlessGuardKit"]
        )
    ],
    swiftLanguageModes: [.v5]
)
