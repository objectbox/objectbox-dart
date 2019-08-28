import "dart:ffi";

import "../ffi/dylib_utils.dart";
import "signatures.dart";

class _ObjectBoxBindings {
  DynamicLibrary objectbox;

  void Function(Pointer<Int32> major, Pointer<Int32> minor, Pointer<Int32> patch) obx_version;

  _ObjectBoxBindings() {
    objectbox = dlopenPlatformSpecific("objectbox");
    obx_version = objectbox.lookup<NativeFunction<obx_version_native_t>>("obx_version").asFunction();
  }
}

_ObjectBoxBindings _cachedBindings;
_ObjectBoxBindings get bindings => _cachedBindings ??= _ObjectBoxBindings();
