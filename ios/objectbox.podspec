# Provides the compiled framework as released in objectbox-swift. No dart-related sources.
# Run `pod lib lint objectbox.podspec' to validate before publishing.
# This package is not distributed as a CocoaPod, rather it's automatically used by Flutter when creating
#  ios/{app}.podspec in client applications using objectbox-dart as a dependency.
# Some of the lines from the original podspec are commented out but left for future reference, in case it stops working.
Pod::Spec.new do |s|
  s.name             = 'objectbox'
  s.version          = '0.0.1' # not used anywhere - official flutter plugins use the same
  s.summary          = 'ObjectBox is a super-fast NoSQL ACID compliant object database.'
  s.homepage         = 'https://objectbox.io'
  s.license          = 'Apache 2.0, ObjectBox Binary License'
  s.author           = 'ObjectBox'
  s.platform         = :ios, '8.0'

  # Get the ObjectBox.framework from the objectbox-swift release (see README.md)
  s.source = { :path => '.' }

  s.ios.vendored_frameworks = 'Carthage/Build/iOS/ObjectBox.framework'
  # s.osx.vendored_frameworks = 'Carthage/Build/Mac/ObjectBox.framework'

  # Fail early during build instead of not finding the library during runtime
  s.xcconfig = { 'OTHER_LDFLAGS' => '-framework ObjectBox' }
end
