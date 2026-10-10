// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AutoClick",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "AutoClick", path: "Sources/AutoClick")
    ]
)
