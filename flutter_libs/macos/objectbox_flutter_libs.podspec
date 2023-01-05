# Provides the compiled framework as released in objectbox-swift. No dart-related sources.
# Run `pod lib lint objectbox_flutter_libs.podspec' to validate before publishing.
# This package is not distributed as a CocoaPod, rather it's automatically used by Flutter when creating
#  ios/{app}.podspec in client applications using objectbox-dart as a dependency.
Pod::Spec.new do |s|
  s.name             = 'objectbox_flutter_libs'
  s.version          = '0.0.1' # not used anywhere - official flutter plugins use the same
  s.summary          = 'ObjectBox is a super-fast NoSQL ACID compliant object database.'
  s.homepage         = 'https://objectbox.io'
  s.license          = 'Apache 2.0, ObjectBox Binary License'
  s.author           = 'ObjectBox'
  s.platform         = :osx, '10.11'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'

  s.dependency 'FlutterMacOS'
  s.dependency 'ObjectBox', '1.8.1-rc'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.3'

  # Fail early during build instead of not finding the library during runtime
  s.xcconfig = { 'OTHER_LDFLAGS' => '-framework ObjectBox' }
end
