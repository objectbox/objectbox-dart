// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.
// Older tools (5.9 to 6.0, so Xcode 15 to 16.2) use Package@swift-5.9.swift instead, which lacks the Mesh Sync
// add-on (it needs package traits). Keep both manifests in sync; tool/set-swift-version.sh updates the version in both.

import PackageDescription

let package = Package(
    name: "objectbox_sync_flutter_libs",
    platforms: [
        // ObjectBox Swift Package requires iOS 15
        .iOS(.v15)
    ],
    products: [
        .library(name: "objectbox-sync-flutter-libs", targets: ["objectbox_sync_flutter_libs"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // Pinned to the commit of tag 6.0.0-beta.2 (new versions might contain breaking C API changes, so it is
        // pinned at all). Pinned by revision rather than exact version: the Swift 6.2.x package resolver (Xcode 26.0
        // to 26.3) fails to resolve a version-based dependency that enables a trait (SwiftPM issue #9286; fixed in
        // Swift 6.3), while a revision-based one resolves fine.
        // The MeshSync trait enables the ObjectBoxMeshSync product (the Mesh Sync add-on based on Google Nearby
        // Connections), which is compiled from source and pulls in Google's nearby package.
        .package(
            url: "https://github.com/objectbox/objectbox-swift-spm.git",
            revision: "910840f73816ce78cbefef12d7869402675ae1bf",  // 6.0.0-beta.2
            traits: ["MeshSync"])
    ],
    targets: [
        .target(
            name: "objectbox_sync_flutter_libs",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "ObjectBox-Sync.xcframework", package: "objectbox-swift-spm"),
                .product(name: "ObjectBoxMeshSync", package: "objectbox-swift-spm")
            ],
            resources: [
                // If your plugin requires a privacy manifest, for example if it uses any required
                // reason APIs, update the PrivacyInfo.xcprivacy file to describe your plugin's
                // privacy impact, and then uncomment these lines. For more information, see
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),

                // If you have other resources that need to be bundled with your plugin, refer to
                // the following instructions to add them:
                // https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package
            ],
            // Tools 6.1 default to the Swift 6 language mode; stay on Swift 5 like the Package@swift-5.9.swift build
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
