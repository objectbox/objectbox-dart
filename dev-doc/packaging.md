Packaging of ObjectBox
======================
Currently published packages on pub.dev:

* Main package: https://pub.dev/packages/objectbox
* Generator package: https://pub.dev/packages/objectbox_generator

Given requirements by Flutter and pub.dev
-----------------------------------------
Flutter 1.20 changed a few things... 

Basics from the Flutter docs:

* [C/C++ interop](https://flutter.dev/docs/development/platform-integration/c-interop)
* [Developing packages & plugins](https://flutter.dev/docs/development/packages-and-plugins/developing-packages)

Our situation:

* To work with Flutter, we currently must define a plugin (since Flutter 1.20) as a workaround
  * Otherwise, the iOS build currently fails with the ObjectBox.framework not being added 
* For now, we have no use for a Flutter plugin, we provide dummy versions because "we have to"
  * From the [docs](https://api.flutter.dev/javadoc/io/flutter/embedding/engine/plugins/FlutterPlugin.html):
    "A Flutter plugin allows Flutter developers to interact with a host platform, e.g., Android and iOS, via Dart code"
  * Currently, our Flutter plugins for Android & iOS implement a MethodChannel, but that's probably some default that was generated for us
* We would like to have a clean "Dart" package without Flutter dependency
  * If we remain forced to have Flutter Plugins, we have to provide an additional package for that 
* There seems to be no way to define any platform-specifics in Dart packaging (e.g. which platforms are supported)  
* "name" from pubspec.yaml defines what users need to import
  * Limits what we can do, e.g. we want users to import "objectbox"
