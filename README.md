# ObjectBox for Dart/Flutter

- general file structure inspired by Dart's [FFI SQLite demo](https://github.com/dart-lang/sdk/tree/master/samples/ffi/sqlite)
- make sure that `libobjectbox.so` is installed system-wide
- the code in this repository was only tested on Ubuntu 16.04 x86_64
- run `pub get` and `dart test/test.dart` to run the test code

## Debugging
- sometimes internal ObjectBox errors are not reported correctly, as the exception is lost in the C++ code. To solve this, have the debug build of `libobjectbox.so` installed, run `gdb -q dart` and type the following:
    - `break /home/yourname/objectbox/objectbox/src/main/cpp/util/Exception.h:18` (adjust to point to your `objectbox` directory)
    - `run test/test.dart`
