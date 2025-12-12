// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "grain",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "grain",
            targets: ["grain"]),
    ],
    dependencies: [
        // Firebase SDK
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
    ],
    targets: [
        .target(
            name: "grain",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
            ],
            path: "grain/Sources"
        ),
        .testTarget(
            name: "grainTests",
            dependencies: ["grain"],
            path: "grain/Tests"
        ),
    ]
)
