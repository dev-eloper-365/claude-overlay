// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OverlayMacOS",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "overlay-macos", targets: ["OverlayMacOS"])
    ],
    targets: [
        .executableTarget(
            name: "OverlayMacOS",
            path: "Sources/OverlayMacOS"
        )
    ]
)
