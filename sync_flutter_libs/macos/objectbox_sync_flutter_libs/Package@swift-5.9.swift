// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
// Used by Swift tools 5.9 to 6.0 (Xcode 15 to 16.2) instead of Package.swift, which needs tools 6.1 (package traits)
// for the Mesh Sync add-on. So this build lacks the add-on; keep everything else in sync with Package.swift.

import PackageDescription

let package = Package(
    name: "objectbox_sync_flutter_libs",
    platforms: [
        // ObjectBox Swift Package requires macOS 12
        .macOS(.v12)
    ],
    products: [
        .library(name: "objectbox-sync-flutter-libs", targets: ["objectbox_sync_flutter_libs"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // Use exact instead of from as new versions might contain breaking C API changes
        .package(url: "https://github.com/objectbox/objectbox-swift-spm.git", exact: "6.0.0-beta.2")
    ],
    targets: [
        .target(
            name: "objectbox_sync_flutter_libs",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "ObjectBox-Sync.xcframework", package: "objectbox-swift-spm")
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
            ]
        )
    ]
)
