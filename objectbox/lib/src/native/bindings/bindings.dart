import 'dart:ffi';
import 'dart:io' show Directory, Platform;

import 'package:path/path.dart';

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

  final DynamicLibrary lib;
  try {
    lib = DynamicLibrary.process();
  } catch (_) {
    // Ignore errors, caller will try using open.
    return null;
  }

  // Check if the library is actually loaded by searching for a common function.
  // Note: not using 'lookup' as its exception if not found is caught if
  // All Exceptions is enabled in VS Code.
  if (lib.providesSymbol('obx_version')) {
    _lib = lib;
    return ObjectBoxC(lib);
  } else {
    return null;
  }
}

ObjectBoxC? _tryObjectBoxLibFile() {
  _lib = null;
  final String libName;
  if (Platform.isWindows) {
    libName = 'objectbox.dll';
  } else if (Platform.isMacOS) {
    libName = 'libobjectbox.dylib';
  } else if (Platform.isAndroid) {
    libName = 'libobjectbox-jni.so';
  } else if (Platform.isLinux) {
    libName = 'libobjectbox.so';
  } else {
    // Other platforms not supported (for iOS see _tryObjectBoxLibProcess).
    return null;
  }
  // For desktop OS prefer version in 'lib' subfolder as this is where
  // install.sh (which calls objectbox-c download.sh) puts the library.
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    // Must use absolute directory as relative directory fails on macOS
    // due to security restrictions ("file system relative paths not allowed in
    // hardened programs").
    String libPath = join(Directory.current.path, "lib", libName);
    try {
      _lib = DynamicLibrary.open(libPath);
    } on ArgumentError {
      // On macOS also try /usr/local/lib, this is where the objectbox-c
      // download script installs to as well.
      if (Platform.isMacOS) {
        try {
          _lib ??= DynamicLibrary.open('/usr/local/lib/$libName');
        } on ArgumentError {
          // Ignore.
        }
      }
      // Try default path, see below.
    }
  }
  try {
    // This will look in some standard places for shared libraries:
    // - on Android in the JNI lib folder for the architecture
    // - on Linux in /lib and /usr/lib
    // - on macOS?
    // - on Windows in the working directory and System32
    _lib ??= DynamicLibrary.open(libName);
  } catch (e) {
    print("Failed to load ObjectBox library. For Flutter apps, check if "
        "objectbox_flutter_libs is added to dependencies. "
        "For unit tests and Dart apps, check if the ObjectBox library was "
        "downloaded (https://docs.objectbox.io/getting-started).");
    rethrow;
  }
  return ObjectBoxC(_lib!);
}

// Require the minimum C API version of all supported platform-specific
// libraries.
// Library         | C API version | Core version
// objectbox-c             | 4.0.2 | 4.0.2-2024-10-15
// ObjectBox Swift 4.0.1   | 4.0.2 | 4.0.2-2024-10-15
// objectbox-android 4.0.3 | 4.0.1 | 4.0.2-2024-10-15
var _obxCminMajor = 4;
var _obxCminMinor = 0;
var _obxCminPatch = 1;
// Require minimum core version guaranteeing actual C API availability.
var _obxCoreMinVersion = "4.0.2-2024-10-15";

bool _isSupportedVersion(ObjectBoxC obxc) {
  if (!obxc.version_is_at_least(_obxCminMajor, _obxCminMinor, _obxCminPatch)) {
    return false;
  }
  // Require a minimum core version.
  // As the core version string uses the
  // "major.minor.build-YYYY-MM-DD (<flags>)"
  // format it should have a stable order.
  // Note: if the version+date is the same the compare value will be negative as
  // the flags make the string longer than the expected min version+date string.
  final coreVersion = dartStringFromC(obxc.version_core_string());
  return _obxCoreMinVersion.compareTo(coreVersion) <= 0;
}

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
    final coreVersion = dartStringFromC(obxc.version_core_string());
    throw UnsupportedError(
        'ObjectBox platform-specific library not compatible: is $version ($coreVersion),'
        ' expected $_obxCminMajor.$_obxCminMinor.$_obxCminPatch ($_obxCoreMinVersion) or newer.'
        ' For Flutter, check if the ObjectBox Pod or objectbox-android-objectbrowser need to be updated.'
        ' For Dart, re-run the install.sh script to download the latest version.');
  }

  return obxc;
}

DynamicLibrary? _lib;
final ObjectBoxC C = loadObjectBoxLib();

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
