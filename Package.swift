// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AmplifyUILiveness",
    defaultLocalization: "en",
    // SONDER PATCH: upstream declares .v14, but amplify-swift raised its own
    // floor to iOS 15 in 2.60.2. Since the dependency below is `from:`, SPM
    // resolves that release and Xcode then rejects the graph — a v14 target
    // cannot link products that require 15.0. Sonder ships a 16.4 deployment
    // target, so matching Amplify's floor costs us no device coverage.
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "FaceLiveness",
            targets: ["FaceLiveness"]),
    ],
    dependencies: [
        // SONDER PATCH: upstream uses `from:`, which silently resolves to the
        // newest 2.x on every clean checkout — that is how 2.60.2's iOS 15
        // floor broke the build with no change on our side. Pin to a range we
        // control so Amplify upgrades are deliberate, like the fork's own tag
        // pin in packages/face-liveness/ios/FaceLivenessDetector.podspec.
        .package(
            url: "https://github.com/aws-amplify/amplify-swift",
            "2.60.2"..<"2.61.0"
        )
    ],
    targets: [
        .target(
            name: "FaceLiveness",
            dependencies: [
                .product(name: "AWSPluginsCore", package: "amplify-swift"),
                .product(name: "AWSCognitoAuthPlugin", package: "amplify-swift"),
                .product(name: "AWSPredictionsPlugin", package: "amplify-swift")
            ],
            resources: [
                .process("Resources/Base.lproj"),
                .copy("Resources/face_detection_short_range.mlmodelc")
            ]
        ),
        .testTarget(
            name: "FaceLivenessTests",
            dependencies: ["FaceLiveness"]),
    ]
)
