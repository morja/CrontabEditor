// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CrontabEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "CrontabEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CrontabEditorTests",
            dependencies: ["CrontabEditor"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
