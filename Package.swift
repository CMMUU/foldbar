// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FoldBar",
    platforms: [.macOS(.v14)],
    products: [.library(name: "FoldBarCore", targets: ["FoldBarCore"])],
    targets: [
        .target(name: "FoldBarCore", path: "Sources/Core"),
        .testTarget(name: "FoldBarCoreTests", dependencies: ["FoldBarCore"], path: "Tests")
    ]
)
