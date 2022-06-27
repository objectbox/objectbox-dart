# Updating the C library

It's important that the generated dart bindings and the c-api library version match. 
Dart won't error on C function signature mismatch, leading to obscure memory bugs.

- Update [install.sh](../install.sh).
  
## Flutter libs
Update `flutter_libs` and `sync_flutter_libs` with **compatible library versions**:  

- Linux and Windows
  - Shortcut: search and replace e.g. `set(OBJECTBOX_VERSION 0.17.0)` in `CMakeLists.txt`.
  - [flutter_libs Linux](../flutter_libs/linux/CMakeLists.txt)
  - [flutter_libs Windows](../flutter_libs/windows/CMakeLists.txt)
  - [sync_flutter_libs Linux](../sync_flutter_libs/linux/CMakeLists.txt)
  - [sync_flutter_libs Windows](../sync_flutter_libs/windows/CMakeLists.txt)
- Android ([view releases](https://github.com/objectbox/objectbox-java/releases))
  - Shortcut: search and replace `-android:3.1.3` in `build.gradle` files.
  - In [flutter_libs](../flutter_libs/android/build.gradle)
  - In [sync_flutter_libs](../sync_flutter_libs/android/build.gradle)
- Android in examples.
  - Shortcut: search and replace `-android-objectbrowser:3.1.3` in `build.gradle` files. 
  - In [objectbox_demo_relations](../objectbox/example/flutter/objectbox_demo_relations/android/app/build.gradle)
- Swift (iOS/macOS) ([view releases](https://github.com/objectbox/objectbox-swift/releases))
  - Shortcut: search and replace e.g. `s.dependency 'ObjectBox', '1.7.0` in `.podspec` files.
  - In [flutter_libs for iOS](../flutter_libs/ios/objectbox_flutter_libs.podspec)
  - In [flutter_libs for macOS](../flutter_libs/macos/objectbox_flutter_libs.podspec)
  - In [sync_flutter_libs for iOS](../sync_flutter_libs/ios/objectbox_sync_flutter_libs.podspec)
  - In [sync_flutter_libs for macOS](../sync_flutter_libs/macos/objectbox_sync_flutter_libs.podspec)

## Dart bindings
Download source code of an [objectbox-c release version](https://github.com/objectbox/objectbox-c/releases).
- Update [objectbox.h](../objectbox/lib/src/native/bindings/objectbox.h)
- Update [objectbox-dart.h](../objectbox/lib/src/native/bindings/objectbox-dart.h)
- Update [objectbox-sync.h](../objectbox/lib/src/native/bindings/objectbox-sync.h)
- Replace `const void*` by `const uint8_t*` in all objectbox*.h files 
  (see ffigen note in [pubspec.yaml](../objectbox/pubspec.yaml)).
- Execute `dart run ffigen` in the `objectbox` directory. This requires LLVM libraries 
  (see [ffigen docs](https://pub.dev/packages/ffigen#installing-llvm) 
  and the ffigen section in [pubspec.yaml](../objectbox/pubspec.yaml)).
- Copy/update enums from [objectbox_c.dart](../objectbox/lib/src/native/bindings/objectbox_c.dart) 
  in [enums.dart](../objectbox/lib/src/modelinfo/enums.dart).
- Have a look at the changed files to see if some call sites need to be updated.
