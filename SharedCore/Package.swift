// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SharedCore", targets: ["SharedCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.17")
    ],
    targets: [
        .target(
            name: "SharedCore",
            dependencies: ["ZIPFoundation"]
        )
    ]
)
