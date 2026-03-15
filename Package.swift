// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MyWhisper",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1"),
    ],
    targets: [
        .target(name: "MyWhisper", dependencies: [
            .product(name: "HotKey", package: "HotKey"),
        ]),
        .testTarget(name: "MyWhisperTests", dependencies: ["MyWhisper"]),
    ]
)
