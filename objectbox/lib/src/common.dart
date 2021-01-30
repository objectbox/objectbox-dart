import 'dart:ffi';

import 'package:ffi/ffi.dart' show allocate, free;

import 'bindings/bindings.dart';

// TODO use pub_semver?
/// Wrapper for a semantic version information.
class Version {
  final int major;
  final int minor;
  final int patch;

  const Version(this.major, this.minor, this.patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// Returns the underlying ObjectBox-C library version.
Version nativeLibraryVersion() {
  var majorPtr = allocate<Int32>(),
      minorPtr = allocate<Int32>(),
      patchPtr = allocate<Int32>();

  try {
    C.version(majorPtr, minorPtr, patchPtr);
    return Version(majorPtr.value, minorPtr.value, patchPtr.value);
  } finally {
    free(majorPtr);
    free(minorPtr);
    free(patchPtr);
  }
}

/// ObjectBox native exception wrapper.
class ObjectBoxException implements Exception {
  final String /*?*/ dartMsg;
  final int nativeCode;
  final String /*?*/ nativeMsg;

  ObjectBoxException({this.dartMsg, this.nativeCode = 0, this.nativeMsg});

  @override
  String toString() {
    var result = 'ObjectBoxException: ';
    if (dartMsg != null) {
      result += dartMsg /*!*/;
      if (nativeCode != 0 || nativeMsg != null) result += ': ';
    }
    if (nativeCode != 0) result += '$nativeCode ';
    if (nativeMsg != null) result += nativeMsg;
    return result.trimRight();
  }
}
