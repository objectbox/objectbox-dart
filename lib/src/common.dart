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
    return Version(majorPtr.value, minorPtr.value, patchPtr.value);
  } finally {
    free(majorPtr);
    free(minorPtr);
    free(patchPtr);
  }
}

class ObjectBoxException implements Exception {
  final String dartMsg;
  final int nativeCode;
  final String nativeMsg;

  ObjectBoxException({String dartMsg, int nativeCode, String nativeMsg})
      : dartMsg = dartMsg,
        nativeCode = nativeCode,
        nativeMsg = nativeMsg;

  @override
  String toString() {
    var result = 'ObjectBoxException: ';
    if (dartMsg != null) result += dartMsg + ': ';
    if (nativeCode != 0) result += '$nativeCode ';
    return result + nativeMsg;
  }
}
