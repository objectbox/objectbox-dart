// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
        // Pinned to the commit of tag 6.0.0-rc (new versions might contain breaking C API changes, so it is
        // pinned at all). Pinned by revision rather than exact version as the objectbox_mesh_sync plugin
        // must pin it by revision (it enables the MeshSync trait, see its Package.swift) and both plugins must use
        // the same requirement. Keep both in sync.
        // Does not enable the MeshSync trait, so the Mesh Sync add-on and its dependencies (Google's nearby
        // package) are not part of the build unless an app adds objectbox_mesh_sync.
        .package(
            url: "https://github.com/objectbox/objectbox-swift-spm.git",
            revision: "d2ef3d68c85dfb62e407c5a06f18395e93ac109f")  // 6.0.0-rc
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
