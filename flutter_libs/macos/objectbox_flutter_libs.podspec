#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint objectbox_flutter_libs.podspec` to validate before publishing.
#
# Provides the compiled framework as released with objectbox-swift. No Dart-related sources.
# This package is not distributed as a CocoaPod, rather it's automatically used by Flutter when
# creating ios/{app}.podspec in client applications using objectbox-dart as a dependency.
#
Pod::Spec.new do |s|
  s.name             = 'objectbox_flutter_libs'
  s.version          = '0.0.1' # not used anywhere - official flutter plugins use the same
  s.summary          = 'ObjectBox is a super-fast NoSQL ACID compliant object database.'
  s.homepage         = 'https://objectbox.io'
  s.license          = 'Apache 2.0, ObjectBox Binary License'
  s.author           = 'ObjectBox'
  s.platform         = :osx, '11.0' # ObjectBox CocoaPod requires macOS 11
  s.source           = { :path => '.' }
  s.source_files     = 'objectbox_flutter_libs/Sources/objectbox_flutter_libs/**/*'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'objectbox_flutter_libs_privacy' => ['objectbox_flutter_libs/Sources/objectbox_flutter_libs/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'
  s.dependency 'ObjectBox', '5.3.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.3'

  # Fail early during build instead of not finding the library during runtime
  s.xcconfig = { 'OTHER_LDFLAGS' => '-framework ObjectBox' }
end
