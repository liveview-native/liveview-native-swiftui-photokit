// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LiveViewNativePhotoKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LiveViewNativePhotoKit",
            targets: ["LiveViewNativePhotoKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/liveview-native/liveview-client-swiftui", branch: "core-file-upload")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LiveViewNativePhotoKit",
            dependencies: [.product(name: "LiveViewNative", package: "liveview-client-swiftui")]
        ),
        .testTarget(
            name: "LiveViewNativePhotoKitTests",
            dependencies: ["LiveViewNativePhotoKit"]
        ),
    ]
)
