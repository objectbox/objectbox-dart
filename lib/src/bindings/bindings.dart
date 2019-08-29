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
    int Function(Pointer<Void> model) obx_model_free;
    int Function(Pointer<Void> model, Pointer<Uint8> name, int entity_id, int entity_uid) obx_model_entity;
    int Function(Pointer<Void> model, Pointer<Uint8> name, int type, int property_id, int property_uid) obx_model_property;
    int Function(Pointer<Void> model, int flags) obx_model_property_flags;
    int Function(Pointer<Void> model, int property_id, int property_uid) obx_model_entity_last_property_id;
    int Function(Pointer<Void> model, int entity_id, int entity_uid) obx_model_last_entity_id;

    _ObjectBoxBindings() {
        objectbox = dlopenPlatformSpecific("objectbox");
        
        // common functions
        obx_version = objectbox.lookup<NativeFunction<obx_version_native_t>>("obx_version").asFunction();
        
        // schema model creation
        obx_model_create = objectbox.lookup<NativeFunction<obx_model_create_native_t>>("obx_model_create").asFunction();
        obx_model_free = objectbox.lookup<NativeFunction<obx_model_free_native_t>>("obx_model_free").asFunction();
        obx_model_entity = objectbox.lookup<NativeFunction<obx_model_entity_native_t>>("obx_model_entity").asFunction();
        obx_model_property = objectbox.lookup<NativeFunction<obx_model_property_native_t>>("obx_model_property").asFunction();
        obx_model_property_flags = objectbox.lookup<NativeFunction<obx_model_property_flags_native_t>>("obx_model_property_flags").asFunction();
        obx_model_entity_last_property_id = objectbox.lookup<NativeFunction<obx_model_entity_last_property_id_native_t>>("obx_model_entity_last_property_id").asFunction();
        obx_model_last_entity_id = objectbox.lookup<NativeFunction<obx_model_last_entity_id_native_t>>("obx_model_last_entity_id").asFunction();
    }
}

_ObjectBoxBindings _cachedBindings;
_ObjectBoxBindings get bindings => _cachedBindings ??= _ObjectBoxBindings();
