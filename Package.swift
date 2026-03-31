// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoupleTodoCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CoupleTodoCore",
            targets: ["CoupleTodoCore"]
        ),
        .library(
            name: "CoupleTodoFirebase",
            targets: ["CoupleTodoFirebase"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.10.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "9.0.0")
    ],
    targets: [
        .target(
            name: "CoupleTodoCore"
        ),
        .target(
            name: "CoupleTodoFirebase",
            dependencies: [
                "CoupleTodoCore",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
            ]
        ),
        .testTarget(
            name: "CoupleTodoCoreTests",
            dependencies: ["CoupleTodoCore"]
        ),
        .testTarget(
            name: "CoupleTodoFirebaseTests",
            dependencies: ["CoupleTodoFirebase"]
        )
    ]
)
