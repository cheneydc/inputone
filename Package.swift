// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "InputOne",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "InputOneLib"
        ),
        .executableTarget(
            name: "InputOne",
            dependencies: ["InputOneLib"],
            resources: [.copy("lock.png")]
        ),
        .testTarget(
            name: "InputOneTests",
            dependencies: ["InputOneLib"]
        ),
    ]
)
