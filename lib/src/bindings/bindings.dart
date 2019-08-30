import "dart:ffi";

import "../ffi/dylib_utils.dart";
import "signatures.dart";

// bundles all C functions to be exposed to Dart
class _ObjectBoxBindings {
    DynamicLibrary objectbox;

    // common functions
    void Function(Pointer<Int32> major, Pointer<Int32> minor, Pointer<Int32> patch) obx_version;
    Pointer<Uint8> Function() obx_version_string;

    // error info
    int Function() obx_last_error_code;
    Pointer<Uint8> Function() obx_last_error_message;
    int Function() obx_last_error_secondary;
    void Function() obx_last_error_clear;

    // schema model creation
    Pointer<Void> Function() obx_model_create;
    int Function(Pointer<Void> model) obx_model_free;
    int Function(Pointer<Void> model, Pointer<Uint8> name, int entity_id, int entity_uid) obx_model_entity;
    int Function(Pointer<Void> model, Pointer<Uint8> name, int type, int property_id, int property_uid) obx_model_property;
    int Function(Pointer<Void> model, int flags) obx_model_property_flags;
    int Function(Pointer<Void> model, int property_id, int property_uid) obx_model_entity_last_property_id;
    int Function(Pointer<Void> model, int entity_id, int entity_uid) obx_model_last_entity_id;

    // object store management
    Pointer<Void> Function() obx_opt;
    int Function(Pointer<Void> opt, Pointer<Void> model) obx_opt_model;
    Pointer<Void> Function(Pointer<Void> opt) obx_store_open;
    int Function(Pointer<Void> store) obx_store_close;

    // box management
    Pointer<Void> Function(Pointer<Void> store, int entity_id) obx_box;
    int Function(Pointer<Void> box, Pointer<Pointer<Void>> data, Pointer<Int32> size) obx_box_get;
    int Function(Pointer<Void> box, int id_or_zero) obx_box_id_for_put;
    int Function(Pointer<Void> box, int id, Pointer<Void> data, int mode) obx_box_put;
    int Function(Pointer<Void> box, int id) obx_box_remove;

    _ObjectBoxBindings() {
        objectbox = dlopenPlatformSpecific("objectbox");
        
        // common functions
        obx_version = objectbox.lookup<NativeFunction<obx_version_native_t>>("obx_version").asFunction();
        obx_version_string = objectbox.lookup<NativeFunction<obx_version_string_native_t>>("obx_version_string").asFunction();

        // error info
        obx_last_error_code = objectbox.lookup<NativeFunction<obx_last_error_code_native_t>>("obx_last_error_code").asFunction();
        obx_last_error_message = objectbox.lookup<NativeFunction<obx_last_error_message_native_t>>("obx_last_error_message").asFunction();
        obx_last_error_secondary = objectbox.lookup<NativeFunction<obx_last_error_secondary_native_t>>("obx_last_error_secondary").asFunction();
        obx_last_error_clear = objectbox.lookup<NativeFunction<obx_last_error_clear_native_t>>("obx_last_error_clear").asFunction();

        // schema model creation
        obx_model_create = objectbox.lookup<NativeFunction<obx_model_create_native_t>>("obx_model_create").asFunction();
        obx_model_free = objectbox.lookup<NativeFunction<obx_model_free_native_t>>("obx_model_free").asFunction();
        obx_model_entity = objectbox.lookup<NativeFunction<obx_model_entity_native_t>>("obx_model_entity").asFunction();
        obx_model_property = objectbox.lookup<NativeFunction<obx_model_property_native_t>>("obx_model_property").asFunction();
        obx_model_property_flags = objectbox.lookup<NativeFunction<obx_model_property_flags_native_t>>("obx_model_property_flags").asFunction();
        obx_model_entity_last_property_id = objectbox.lookup<NativeFunction<obx_model_entity_last_property_id_native_t>>("obx_model_entity_last_property_id").asFunction();
        obx_model_last_entity_id = objectbox.lookup<NativeFunction<obx_model_last_entity_id_native_t>>("obx_model_last_entity_id").asFunction();

        // object store management
        obx_opt = objectbox.lookup<NativeFunction<obx_opt_native_t>>("obx_opt").asFunction();
        obx_opt_model = objectbox.lookup<NativeFunction<obx_opt_model_native_t>>("obx_opt_model").asFunction();
        obx_store_open = objectbox.lookup<NativeFunction<obx_store_open_native_t>>("obx_store_open").asFunction();
        obx_store_close = objectbox.lookup<NativeFunction<obx_store_close_native_t>>("obx_store_close").asFunction();

        // box management
        obx_box = objectbox.lookup<NativeFunction<obx_box_native_t>>("obx_box").asFunction();
        obx_box_get = objectbox.lookup<NativeFunction<obx_box_get_native_t>>("obx_box_get").asFunction();
        obx_box_id_for_put = objectbox.lookup<NativeFunction<obx_box_id_for_put_native_t>>("obx_box_id_for_put").asFunction();
        obx_box_put = objectbox.lookup<NativeFunction<obx_box_put_native_t>>("obx_box_put").asFunction();
        obx_box_remove = objectbox.lookup<NativeFunction<obx_box_remove_native_t>>("obx_box_remove").asFunction();
    }
}

_ObjectBoxBindings _cachedBindings;
_ObjectBoxBindings get bindings => _cachedBindings ??= _ObjectBoxBindings();
