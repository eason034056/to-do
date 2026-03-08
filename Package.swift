// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "CoupleTodo",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "CoupleTodoCore", targets: ["CoupleTodoCore"])
    ],
    targets: [
        .target(
            name: "CoupleTodoCore",
            path: "Sources/CoupleTodoCore"
        ),
        .testTarget(
            name: "CoupleTodoCoreTests",
            dependencies: ["CoupleTodoCore"],
            path: "Tests/CoupleTodoCoreTests"
        )
    ]
)
