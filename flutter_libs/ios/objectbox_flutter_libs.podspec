# Provides the compiled framework as released in objectbox-swift. No dart-related sources.
# Run `pod lib lint objectbox.podspec' to validate before publishing.
# This package is not distributed as a CocoaPod, rather it's automatically used by Flutter when creating
#  ios/{app}.podspec in client applications using objectbox-dart as a dependency.
# Some of the lines from the original podspec are commented out but left for future reference, in case it stops working.
Pod::Spec.new do |s|
  s.name             = 'objectbox_flutter_libs'
  s.version          = '0.0.1' # not used anywhere - official flutter plugins use the same
  s.summary          = 'ObjectBox is a super-fast NoSQL ACID compliant object database.'
  s.homepage         = 'https://objectbox.io'
  s.license          = 'Apache 2.0, ObjectBox Binary License'
  s.author           = 'ObjectBox'
  s.platform         = :ios, '8.0'

  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'

  s.dependency 'Flutter'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'

  # Get the ObjectBoxC.framework from the objectbox-swift release (see README.md)
  s.ios.vendored_frameworks = 'Carthage/Build/iOS/ObjectBox.framework'

  # Fail early during build instead of not finding the library during runtime
  s.xcconfig = { 'OTHER_LDFLAGS' => '-framework ObjectBox' }
end
