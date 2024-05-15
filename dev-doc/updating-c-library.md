# Updating the C API bindings and libraries

It's important that the generated Dart C bindings have APIs matching the included C libraries. 
Dart won't error on C function signature mismatch, leading to obscure memory bugs.

## C libraries

For Dart Native and unit tests ([install.sh](../install.sh)),
for the binding update script (see below) and
for Flutter (`flutter_libs` and `sync_flutter_libs` plugins) on Linux and Windows:  
```
./tool/set-c-version.sh 4.0.0
```

For the Flutter plugins on Android ([view releases](https://github.com/objectbox/objectbox-java/releases)):
```
./tool/set-android-version.sh 4.0.0
```

For the Flutter plugins on iOS/macOS ([view releases](https://github.com/objectbox/objectbox-swift/releases))
```
./tool/set-swift-version.sh 2.0.0
```

For each, add an entry (see previous releases) to the [CHANGELOG](../objectbox/CHANGELOG.md).

## Dart C API bindings
To download the C library header files and generate bindings with ffigen (requires LLVM libraries,
see [ffigen docs](https://pub.dev/packages/ffigen#installing-llvm)
and the ffigen section in [pubspec.yaml](../objectbox/pubspec.yaml)):
```
./tool/update-c-binding.sh
```

Then manually:
- Copy/update enums that need to be exposed to users
  from [objectbox_c.dart](../objectbox/lib/src/native/bindings/objectbox_c.dart) 
  to [enums.dart](../objectbox/lib/src/modelinfo/enums.dart).
- Check the changed files, make any required changes in the Dart library (like method signature changes).
- ⚠️ Update minimum C API and core version and notes as needed in [bindings.dart](../objectbox/lib/src/native/bindings/bindings.dart).
  
  Note: the embedded C API and core version can be looked up
  for Android from the relevant core repository release tag and
  for Swift from its repos release tag and the core commit it points to.
