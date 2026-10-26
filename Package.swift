// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Topside",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Topside",
            path: "Sources/Topside"
        )
    ]
)
