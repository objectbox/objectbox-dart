# ObjectBox (Dart) benchmarks

This package provides micro-benchmarking & profiling tools for:

* database performance (CRUD)
* different code versions to pick the fastest implementation

These are mostly used to compare effects of changes during development and should be taken with a grain of salt.

Also see the full-application benchmark in https://github.com/objectbox/objectbox-dart-performance 
which provides a better picture of the potential "real world" performance.

## Compile for production
To get the most optimized version, build executables instead of running on Dart VM, for example:

`dart compile exe bin/basics.dart`

See https://dart.dev/tools/dart-compile for more options.
