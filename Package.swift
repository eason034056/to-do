// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoupleTodoCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CoupleTodoCore",
            targets: ["CoupleTodoCore"]
        )
    ],
    targets: [
        .target(
            name: "CoupleTodoCore"
        ),
        .testTarget(
            name: "CoupleTodoCoreTests",
            dependencies: ["CoupleTodoCore"]
        )
    ]
)
