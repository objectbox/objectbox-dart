Packaging of ObjectBox
======================
Currently published packages on pub.dev:

* Main package: https://pub.dev/packages/objectbox
* Generator package: https://pub.dev/packages/objectbox_generator
* Flutter packages (to pull in platform-specific dependencies):
  * https://pub.dev/packages/objectbox_flutter_libs
  * https://pub.dev/packages/objectbox_sync_flutter_libs

Given requirements by Flutter and pub.dev
-----------------------------------------
Basics from the Flutter docs:

* [Dart C/C++ interop (FFI)](https://dart.dev/guides/libraries/c-interop) 
  * [Android](https://docs.flutter.dev/development/platform-integration/android/c-interop)
  * [iOS](https://docs.flutter.dev/development/platform-integration/ios/c-interop)
  * [macOS](https://docs.flutter.dev/development/platform-integration/macos/c-interop)
* [Developing packages & plugins](https://docs.flutter.dev/development/packages-and-plugins/developing-packages)

A separate Flutter package is provided to have a Dart Native compatible package without Flutter
dependencies.

As Flutter does otherwise not allow to add platform-specific dependencies, instead of a regular 
Flutter package a plugin package is provided (another one for sync). The plugin code was generated 
with a command similar to

    // See /tool/plugin-update.sh
    flutter create \
      --template=plugin \
      --org=io.objectbox \
      --platforms=ios,android,linux,macos,windows \
      --project-name=objectbox_flutter_libs \
      .

See the [plugin-update script](../tool/plugin-update.sh). It can also be used to adapt the plugin 
code files to the latest templates (note that it won't delete e.g. obsolete files).

For now, the Flutter plugin is only used on Android (method channels) for a backwards-compatibility
workaround. No-op versions are provided for other platforms because it is required.

Some additional notes:
* `name` from pubspec.yaml defines:
  * What users need to import - Limits naming, e.g. we want users to import "objectbox".
  * How the ios/*.podspec is called (same as the Dart/Flutter package name from pubspec, 
    i.e. objectbox_flutter_libs.podspec).
