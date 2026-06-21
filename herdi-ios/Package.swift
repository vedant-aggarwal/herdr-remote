// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "herdi",
    platforms: [.iOS(.v17)],
    targets: [
        .executableTarget(
            name: "herdi",
            path: "Sources"
        )
    ]
)
