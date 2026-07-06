/// This package contains platform-specific native libraries for flutter.
/// See the actual library implementation in package "objectbox".
///
/// On the web platform there are no native libraries; the web variant provides
/// compatible no-op implementations so that generated code compiles.
library;

export 'src/objectbox_flutter_libs_native.dart'
    if (dart.library.js_interop) 'src/objectbox_flutter_libs_web.dart';
