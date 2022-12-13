# Updating the C library

It's important that the generated dart bindings and the c-api library version match. 
Dart won't error on C function signature mismatch, leading to obscure memory bugs.

- Update [install.sh](../install.sh).
  
## Flutter libs
Update `flutter_libs` and `sync_flutter_libs` with **compatible library versions**:  

- Linux and Windows
  - Shortcut: search and replace e.g. `set(OBJECTBOX_VERSION 0.18.0)` in `CMakeLists.txt`.
  - [flutter_libs Linux](../flutter_libs/linux/CMakeLists.txt)
  - [flutter_libs Windows](../flutter_libs/windows/CMakeLists.txt)
  - [sync_flutter_libs Linux](../sync_flutter_libs/linux/CMakeLists.txt)
  - [sync_flutter_libs Windows](../sync_flutter_libs/windows/CMakeLists.txt)
- Android ([view releases](https://github.com/objectbox/objectbox-java/releases))
  ```
  ./tool/set-android-version.sh 3.5.0
  ```
- Swift (iOS/macOS) ([view releases](https://github.com/objectbox/objectbox-swift/releases))
  ```
  ./tool/set-swift-version.sh 1.8.0
  ```

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
  in [enums.dart](../objectbox/lib/src/modelinfo/enums.dart) that need to be exposed to users.
- Have a look at the changed files to see if some call sites need to be updated.
