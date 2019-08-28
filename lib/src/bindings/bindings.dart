import "dart:ffi";

import "../ffi/dylib_utils.dart";
import "signatures.dart";

// bundles all C functions to be exposed to Dart
class _ObjectBoxBindings {
    DynamicLibrary objectbox;

    // common functions
    void Function(Pointer<Int32> major, Pointer<Int32> minor, Pointer<Int32> patch) obx_version;

    // schema model creation
    Pointer<Void> Function() obx_model_create;
    int Function(Pointer<Void>) obx_model_free;

    _ObjectBoxBindings() {
        objectbox = dlopenPlatformSpecific("objectbox");
        
        // common functions
        obx_version = objectbox.lookup<NativeFunction<obx_version_native_t>>("obx_version").asFunction();
        
        // schema model creation
        obx_model_create = objectbox.lookup<NativeFunction<obx_model_create_native_t>>("obx_model_create").asFunction();
        obx_model_free = objectbox.lookup<NativeFunction<obx_model_free_native_t>>("obx_model_free").asFunction();
    }
}

_ObjectBoxBindings _cachedBindings;
_ObjectBoxBindings get bindings => _cachedBindings ??= _ObjectBoxBindings();
