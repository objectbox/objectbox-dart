# Updating the C API bindings and libraries

It's important that the generated Dart C bindings have APIs matching the included C libraries. 
Dart won't error on C function signature mismatch, leading to obscure memory bugs.

## C libraries

For Dart Native and unit tests and for Flutter (`flutter_libs` and `sync_flutter_libs` plugins) 
on Linux and Windows:  
```
./tool/set-c-version.sh 0.20.0
```

For the Flutter plugins on Android ([view releases](https://github.com/objectbox/objectbox-java/releases)):
```
./tool/set-android-version.sh 3.7.1
```

For the Flutter plugins on iOS/macOS ([view releases](https://github.com/objectbox/objectbox-swift/releases))
```
./tool/set-swift-version.sh 1.9.1
```

For each, add an entry (see previous releases) to the [CHANGELOG](../objectbox/CHANGELOG.md).

## Dart C API bindings
Download source code of an [objectbox-c release version](https://github.com/objectbox/objectbox-c/releases).
- Update [objectbox.h](../objectbox/lib/src/native/bindings/objectbox.h)
- Update [objectbox-dart.h](../objectbox/lib/src/native/bindings/objectbox-dart.h)
- Update [objectbox-sync.h](../objectbox/lib/src/native/bindings/objectbox-sync.h)
- Replace `const void*` by `const uint8_t*` in all objectbox*.h files 
  (see ffigen note in [pubspec.yaml](../objectbox/pubspec.yaml)).
- Execute `dart run ffigen` in the `objectbox` directory. This requires LLVM libraries 
  (see [ffigen docs](https://pub.dev/packages/ffigen#installing-llvm) 
  and the ffigen section in [pubspec.yaml](../objectbox/pubspec.yaml)).
- Copy/update enums that need to be exposed to users from [objectbox_c.dart](../objectbox/lib/src/native/bindings/objectbox_c.dart) 
  to [enums.dart](../objectbox/lib/src/modelinfo/enums.dart).
- Have a look at the changed files to see if some call sites need to be updated.
- ⚠️ Update minimum C library and core version and notes as needed in [bindings.dart](../objectbox/lib/src/native/bindings/bindings.dart).
  
  Note: the embedded C library and core version can be looked up
  for Android from the relevant core repository release tag and
  for Swift from its repos release tag and the core commit it points to.
