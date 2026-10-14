// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipboardArchive",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ClipboardArchive", targets: ["ClipboardArchive"]),
    ],
    targets: [
        .executableTarget(name: "ClipboardArchive"),
        .testTarget(name: "ClipboardArchiveTests", dependencies: ["ClipboardArchive"]),
    ]
)
