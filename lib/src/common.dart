import "dart:ffi";
import "package:ffi/ffi.dart" show allocate, free;

import "bindings/bindings.dart";

class Version {
  final int major;
  final int minor;
  final int patch;

  const Version(this.major, this.minor, this.patch);

  toString() => "$major.$minor.$patch";
}

/// Returns the underlying ObjectBox-C library version
Version versionLib() {
  var majorPtr = allocate<Int32>(), minorPtr = allocate<Int32>(), patchPtr = allocate<Int32>();

  try {
    bindings.obx_version(majorPtr, minorPtr, patchPtr);
    return Version(majorPtr.load<int>(), minorPtr.load<int>(), patchPtr.load<int>());
  } finally {
    free(majorPtr);
    free(minorPtr);
    free(patchPtr);
  }
}

class ObjectBoxException implements Exception {
  final String message;
  final String raw_msg;

  ObjectBoxException(msg)
      : message = "ObjectBoxException: " + msg,
        raw_msg = msg;

  String toString() => message;
}
