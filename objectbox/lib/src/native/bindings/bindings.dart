import 'dart:ffi';
import 'dart:io' show Platform;

import 'helpers.dart';
import 'objectbox_c.dart';

// let files importing bindings.dart also get all the OBX_* types
export 'objectbox_c.dart';

// ignore_for_file: public_member_api_docs
// ignore_for_file: non_constant_identifier_names

/// Tries to use an already loaded objectbox dynamic library. This is the only
/// option for macOS and iOS and is ~5 times faster than loading from file so
/// it's good to try for other platforms as well.
ObjectBoxC? _tryObjectBoxLibProcess() {
  // [DynamicLibrary.process()] is not supported on windows, see its docs.
  if (Platform.isWindows) return null;

  ObjectBoxC? obxc;
  try {
    _lib = DynamicLibrary.process();
    obxc = ObjectBoxC(_lib!);
    _isSupportedVersion(obxc); // may throw in case symbols are not found
    return obxc;
  } catch (_) {
    // ignore errors (i.e. symbol not found)
    return null;
  }
}

ObjectBoxC? _tryObjectBoxLibFile() {
  _lib = null;
  var libName = 'objectbox';
  if (Platform.isWindows) {
    libName += '.dll';
    try {
      _lib = DynamicLibrary.open(libName);
    } on ArgumentError {
      libName = 'lib/' + libName;
    }
  } else if (Platform.isMacOS) {
    libName = 'lib' + libName + '.dylib';
    try {
      _lib = DynamicLibrary.open(libName);
    } on ArgumentError {
      libName = '/usr/local/lib/' + libName;
    }
  } else if (Platform.isAndroid) {
    libName = 'lib' + libName + '-jni.so';
  } else if (Platform.isLinux) {
    libName = 'lib' + libName + '.so';
  } else {
    return null;
  }
  _lib ??= DynamicLibrary.open(libName);
  return ObjectBoxC(_lib!);
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

DynamicLibrary? _lib;
late final ObjectBoxC C = loadObjectBoxLib();

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

/// A couple of native functions we need as callbacks to pass back to native.
/// Unfortunately, ffigen keeps those private.
typedef _NativeClose = Int32 Function(Pointer<Void> ptr);

late final native_store_close =
    _lib!.lookup<NativeFunction<_NativeClose>>('obx_store_close');
late final native_query_close =
    _lib!.lookup<NativeFunction<_NativeClose>>('obx_query_close');
late final native_query_prop_close =
    _lib!.lookup<NativeFunction<_NativeClose>>('obx_query_prop_close');
late final native_admin_close =
    _lib!.lookup<NativeFunction<_NativeClose>>('obx_admin_close');

/// Keeps `this` alive until this call, preventing finalizers to run.
/// Necessary for objects with a finalizer attached because the optimizer may
/// mark the object as unused (-> GCed -> finalized) even before it's method
/// finished executing.
/// See https://github.com/dart-lang/sdk/issues/35770#issuecomment-840398463
@pragma('vm:never-inline')
Object reachabilityFence(Object obj) => obj;
