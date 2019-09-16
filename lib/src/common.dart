import "dart:ffi";

import "bindings/bindings.dart";
import "package:ffi/ffi.dart";

class Common {
  static List<int> version() {
    Pointer<Int32> majorPtr = Pointer<Int32>.allocate(),
        minorPtr = Pointer<Int32>.allocate(),
        patchPtr = Pointer<Int32>.allocate();
    bindings.obx_version(majorPtr, minorPtr, patchPtr);
    var ret = [majorPtr.load<int>(), minorPtr.load<int>(), patchPtr.load<int>()];
    majorPtr.free();
    minorPtr.free();
    patchPtr.free();
    return ret;
  }

  static String versionString() {
    return Utf8.fromUtf8(bindings.obx_version_string().cast<Utf8>());
  }
}

class ObjectBoxException {
  final String message;
  ObjectBoxException(msg) : message = "ObjectBoxException: " + msg;

  String toString() => message;
}
