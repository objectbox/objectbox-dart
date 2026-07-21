// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "objectbox_sync_flutter_libs",
    platforms: [
        // ObjectBox Swift Package requires macOS 11
        .macOS(.v11)
    ],
    products: [
        .library(name: "objectbox-sync-flutter-libs", targets: ["objectbox_sync_flutter_libs"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // Use exact instead of from as new versions might contain breaking C API changes
        .package(url: "https://github.com/objectbox/objectbox-swift-spm.git", exact: "5.3.0")
    ],
    targets: [
        .target(
            name: "objectbox_sync_flutter_libs",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "ObjectBox-Sync.xcframework", package: "objectbox-swift-spm")
            ],
            resources: [
                // If your plugin requires a privacy manifest, for example if it collects user
                // data, update the PrivacyInfo.xcprivacy file to describe your plugin's
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
