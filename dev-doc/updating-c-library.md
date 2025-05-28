# Updating the C API bindings and libraries

It's important that the generated Dart C bindings have APIs matching the included C libraries. 
Dart won't error on C function signature mismatch, leading to obscure memory bugs.

## C libraries

For each:

- Update versions below
- Run update script
- Add [CHANGELOG](../objectbox/CHANGELOG.md) entry
- Commit changes

### Desktop, Scripts

For Dart Native and unit tests ([install.sh](../install.sh)),
for the binding update script (see below) and
for Flutter (`flutter_libs` and `sync_flutter_libs` plugins) on Linux and Windows:

```bash
./tool/set-c-version.sh 4.2.0
```

```text
* Update ObjectBox database for Flutter Linux/Windows, Dart Native apps to [4.2.0](https://github.com/objectbox/objectbox-c/releases/tag/v4.2.0).
```

```text
Update C library [4.1.0 -> 4.2.0]

Includes database 4.2.0-2025-03-04
```

### Android

For the Flutter plugins on Android ([view releases](https://github.com/objectbox/objectbox-java/releases)):

```bash
./tool/set-android-version.sh 4.2.0
```

```text
* Update ObjectBox database for Flutter Android apps to 4.2.0.
  If your project is [using Admin](https://docs.objectbox.io/data-browser#admin-for-android), make 
  sure to update to `io.objectbox:objectbox-android-objectbrowser:4.2.0` in `android/app/build.gradle`.
```

```text
Update objectbox-android [4.1.0 -> 4.2.0]

Includes C API 4.2.0 and database 4.2.0-2025-03-04
```

Note: the embedded C API and ObjectBox version can be looked up
from the relevant objectbox repository release tag (like `java-4.1.0`).

### Apple OSs

For the Flutter plugins on iOS/macOS ([view releases](https://github.com/objectbox/objectbox-swift/releases))

```bash
./tool/set-swift-version.sh 4.2.0
```

```text
* Update ObjectBox database for Flutter iOS/macOS apps to 4.2.0.
  For existing projects, run `pod repo update` and `pod update ObjectBox` in the `ios` or `macos` directories.
```

```text
Update ObjectBox Swift [4.1.0 -> 4.2.0]

Includes C API 4.2.0 and database 4.2.0-2025-03-27
```

Note: the embedded C API and ObjectBox version can be looked up 
from the objectbox-swift release tag (like `v4.1.0`) and 
the objectbox commit it points to (see `external/objectbox`).

## Dart C API bindings

To download the C library header files and generate bindings with ffigen (requires LLVM libraries,
see [ffigen docs](https://pub.dev/packages/ffigen#installing-llvm)
and the ffigen section in [pubspec.yaml](../objectbox/pubspec.yaml)):

```bash
./tool/update-c-binding.sh
```

Then manually:

- Copy/update enums that need to be exposed to users
  from [objectbox_c.dart](../objectbox/lib/src/native/bindings/objectbox_c.dart) 
  to [enums.dart](../objectbox/lib/src/modelinfo/enums.dart).
- Check the changed files, make any required changes in the Dart library (like method signature changes).
- ⚠️ Update minimum C API and core version and notes as needed in [bindings.dart](../objectbox/lib/src/native/bindings/bindings.dart).
- Commit as

```text
Update C-API [4.1.0 -> 4.2.0]
```
