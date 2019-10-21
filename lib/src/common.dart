import "dart:ffi";

import "bindings/bindings.dart";
import "package:ffi/ffi.dart";

class Version {
  final int major;
  final int minor;
  final int patch;

  const Version(this.major, this.minor, this.patch);

  toString() => "$major.$minor.$patch";
}

/// Returns the underlying ObjectBox-C library version
Version versionLib() {
  var majorPtr = Pointer<Int32>.allocate(), minorPtr = Pointer<Int32>.allocate(), patchPtr = Pointer<Int32>.allocate();

  try {
    bindings.obx_version(majorPtr, minorPtr, patchPtr);
    return Version(majorPtr.load<int>(), minorPtr.load<int>(), patchPtr.load<int>());
  } finally {
    majorPtr.free();
    minorPtr.free();
    patchPtr.free();
  }
}

class ObjectBoxException implements Exception {
  final String message;
  final String raw_msg;

  ObjectBoxException(msg) : message = "ObjectBoxException: " + msg, raw_msg = msg;

  String toString() => message;
}
