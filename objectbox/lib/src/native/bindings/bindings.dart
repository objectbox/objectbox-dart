import 'dart:ffi';
import 'dart:io' show Platform;

import 'helpers.dart';
import 'objectbox-c.dart';

// let files importing bindings.dart also get all the OBX_* types
export 'objectbox-c.dart';

// ignore_for_file: public_member_api_docs

// Tries to use an already loaded objectbox dynamic library. This is the only
// option for macOS and iOS and should be faster for other platforms as well.
ObjectBoxC? _tryObjectBoxLibProcess() {
  // [DynamicLibrary.process()] is not supported on windows, see its docs.
  if (Platform.isWindows) return null;

  final lib = DynamicLibrary.process();
  try {
    final obxc = ObjectBoxC(lib);
    if (_isSupportedVersion(obxc)) {
      return obxc;
    }
  } catch (_) {}
  return null;
}

ObjectBoxC? _tryObjectBoxLibFile() {
  DynamicLibrary? lib;
  var libName = 'objectbox';
  if (Platform.isWindows) {
    libName += '.dll';
    try {
      lib = DynamicLibrary.open(libName);
    } on ArgumentError {
      libName = 'lib/' + libName;
    }
  } else if (Platform.isMacOS) {
    libName = 'lib' + libName + '.dylib';
    try {
      lib = DynamicLibrary.open(libName);
    } on ArgumentError {
      libName = '/usr/local/lib/' + libName;
    }
  } else if (Platform.isAndroid) {
    libName = 'lib' + libName + '-jni.so';
  } else if (Platform.isLinux) {
    libName = 'lib' + libName + '.so';
  }
  lib ??= DynamicLibrary.open(libName);
  return ObjectBoxC(lib);
}

bool _isSupportedVersion(ObjectBoxC obxc) => obxc.version_is_at_least(
    OBX_VERSION_MAJOR, OBX_VERSION_MINOR, OBX_VERSION_PATCH);

ObjectBoxC loadObjectBoxLib() {
  ObjectBoxC? obxc;
  obxc ??= _tryObjectBoxLibProcess();
  obxc ??= _tryObjectBoxLibFile();

  if (obxc == null) {
    throw UnsupportedError(
        'Could not load ObjectBox core dynamic library. Platform: ${Platform.operatingSystem}');
  }

  if (!_isSupportedVersion(obxc)) {
    final version = dartStringFromC(obxc.version_string());
    throw UnsupportedError(
        'Loaded ObjectBox core dynamic library has unsupported version $version,'
        ' expected ^$OBX_VERSION_MAJOR.$OBX_VERSION_MINOR.$OBX_VERSION_PATCH');
  }

  return obxc;
}

ObjectBoxC? _cachedBindings;

ObjectBoxC get C => _cachedBindings ??= loadObjectBoxLib();

/// Init DartAPI in C for async callbacks.
///
/// Call each time you're assign a native listener - will throw if the Dart
/// native API isn't available.
/// See https://github.com/objectbox/objectbox-dart/issues/143
void initializeDartAPI() {
  if (_dartAPIInitialized == 0) {
    final errCode = C.dartc_init_api(NativeApi.initializeApiDLData);
    _dartAPIInitialized = (OBX_SUCCESS == errCode) ? 1 : -1;
    if (_dartAPIInitialized == -1) {
      try {
        throwLatestNativeError(
            codeIfMissing: errCode,
            context: "Dart/Flutter SDK you're using is not compatible with "
                'ObjectBox observers, query streams and Sync event streams.');
      } catch (e) {
        _dartAPIInitException = e;
        rethrow;
      }
    }
  } else if (_dartAPIInitialized == -1) {
    throw _dartAPIInitException!;
  }
}

// 0  => not initialized
// 1  => initialized successfully
// -1 => failed to initialize - incompatible Dart version
int _dartAPIInitialized = 0;
Object? _dartAPIInitException;
