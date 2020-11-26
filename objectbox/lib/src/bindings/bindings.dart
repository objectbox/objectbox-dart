import 'dart:ffi';
import 'dart:io' show Platform;

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

/// Init DartAPI in C for async callbacks - only needs to be called once.
/// See the following issue:
/// https://github.com/objectbox/objectbox-dart/issues/143
void initializeDartAPI() {
  if (!_dartAPIinitialized) {
    _dartAPIinitialized = true;
    C.dart_init_api(NativeApi.initializeApiDLData);
  }
}

bool _dartAPIinitialized = false;
