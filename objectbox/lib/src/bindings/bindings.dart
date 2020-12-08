import 'dart:ffi';
import 'dart:io' show Platform;

import '../common.dart';
import 'helpers.dart';
import 'objectbox-c.dart';

// let files importing bindings.dart also get all the OBX_* types
export 'objectbox-c.dart';

// ignore_for_file: public_member_api_docs

ObjectBoxC loadObjectBoxLib() {
  DynamicLibrary /*?*/ lib;
  var libName = 'objectbox';
  if (Platform.isWindows) {
    libName += '.dll';
    try {
      lib = DynamicLibrary.open(libName);
    } on ArgumentError {
      lib = DynamicLibrary.open('lib/' + libName);
    }
  } else if (Platform.isMacOS) {
    libName = 'lib' + libName + '.dylib';
    try {
      lib = DynamicLibrary.open(libName);
    } on ArgumentError {
      lib = DynamicLibrary.open('/usr/local/lib/' + libName);
    }
  } else if (Platform.isIOS) {
    // this works in combination with 'OTHER_LDFLAGS' => '-framework ObjectBox'
    // in objectbox_flutter_libs.podspec
    lib = DynamicLibrary.process();
    // alternatively, if `DynamicLibrary.process()` wasn't faster (it should be)
    // libName = 'ObjectBox.framework/ObjectBox';
  } else if (Platform.isAndroid) {
    libName = 'lib' + libName + '-jni.so';
  } else if (Platform.isLinux) {
    libName = 'lib' + libName + '.so';
  } else {
    throw Exception(
        'unsupported platform detected: ${Platform.operatingSystem}');
  }
  lib ??= DynamicLibrary.open(libName);
  return ObjectBoxC(lib);
}

ObjectBoxC /*?*/ _cachedBindings;

ObjectBoxC get C => _cachedBindings ??= loadObjectBoxLib();

/// Init DartAPI in C for async callbacks.
///
/// Call each time you're assign a native listener - will throw if the Dart
/// native API isn't available.
/// See https://github.com/objectbox/objectbox-dart/issues/143
void initializeDartAPI() {
  if (_dartAPIinitialized == null) {
    final errCode = C.dart_init_api(NativeApi.initializeApiDLData);
    _dartAPIinitialized = (OBX_SUCCESS == errCode);
    if (!_dartAPIinitialized) {
      _dartAPIinitException = latestNativeError(codeIfMissing: errCode);
    }
  }

  if (_dartAPIinitException != null) {
    throw _dartAPIinitException;
  }
}

// null  => not initialized
// true  => initialized successfully
// false => failed to initialize - incompatible Dart version
bool /*?*/ _dartAPIinitialized;
ObjectBoxException /*?*/ _dartAPIinitException;
