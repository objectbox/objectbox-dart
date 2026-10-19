#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint objectbox_mesh_sync.podspec` to validate before publishing.
#
# Only used with the CocoaPods integration of Flutter: then the Mesh Sync add-on of the ObjectBox Swift
# Package is not available, so the plugin just reports its platform method as not implemented (see the
# Swift Package Manager manifest in objectbox_mesh_sync/Package.swift for the actual integration).
# The ObjectBox pod is provided by the objectbox_sync_flutter_libs plugin.
# This package is not distributed as a CocoaPod, rather it's automatically used by Flutter when
# creating ios/{app}.podspec in client applications using objectbox-dart as a dependency.
#
Pod::Spec.new do |s|
  s.name             = 'objectbox_mesh_sync'
  s.version          = '0.0.1' # not used anywhere - official flutter plugins use the same
  s.summary          = 'ObjectBox is a super-fast NoSQL ACID compliant object database.'
  s.homepage         = 'https://objectbox.io'
  s.license          = 'Apache 2.0, ObjectBox Binary License'
  s.author           = 'ObjectBox'
  s.platform         = :ios, '15.0' # ObjectBox CocoaPod requires iOS 15
  s.source           = { :path => '.' }
  s.source_files     = 'objectbox_mesh_sync/Sources/objectbox_mesh_sync/**/*'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'objectbox_mesh_sync_privacy' => ['objectbox_mesh_sync/Sources/objectbox_mesh_sync/PrivacyInfo.xcprivacy']}

  s.dependency 'Flutter'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.3'
end
