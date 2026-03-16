// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MyWhisper",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.15.0"),
    ],
    targets: [
        .target(name: "MyWhisper", dependencies: [
            .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            .product(name: "WhisperKit", package: "WhisperKit"),
        ]),
        .testTarget(name: "MyWhisperTests", dependencies: ["MyWhisper"]),
    ]
)
