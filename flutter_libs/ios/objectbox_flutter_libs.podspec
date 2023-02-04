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
  s.platform         = :ios, '11.0' # ObjectBox Swift requires 64-bit, so iOS 11.
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'

  s.dependency 'Flutter'
  s.dependency 'ObjectBox', '1.8.1'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }

  s.swift_version = '5.3'

  # Fail early during build instead of not finding the library during runtime
  s.xcconfig = { 'OTHER_LDFLAGS' => '-framework ObjectBox' }
end
