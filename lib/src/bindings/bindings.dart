import "dart:ffi";
import "dart:io" show Platform;

import "signatures.dart";

// bundles all C functions to be exposed to Dart
class _ObjectBoxBindings {
  DynamicLibrary objectbox;

  // common functions
  void Function(Pointer<Int32> major, Pointer<Int32> minor, Pointer<Int32> patch) obx_version;
  Pointer<Uint8> Function() obx_version_string;
  void Function(Pointer<Uint64> array) obx_bytes_array_free;

  // error info
  int Function() obx_last_error_code;
  Pointer<Uint8> Function() obx_last_error_message;
  int Function() obx_last_error_secondary;
  void Function() obx_last_error_clear;

  // schema model creation
  Pointer<Void> Function() obx_model;
  int Function(Pointer<Void> model) obx_model_free;
  int Function(Pointer<Void> model, Pointer<Uint8> name, int entity_id, int entity_uid) obx_model_entity;
  int Function(Pointer<Void> model, Pointer<Uint8> name, int type, int property_id, int property_uid)
      obx_model_property;
  int Function(Pointer<Void> model, int flags) obx_model_property_flags;
  int Function(Pointer<Void> model, int property_id, int property_uid) obx_model_entity_last_property_id;
  int Function(Pointer<Void> model, int entity_id, int entity_uid) obx_model_last_entity_id;

  // object store management
  Pointer<Void> Function() obx_opt;
  int Function(Pointer<Void> opt, Pointer<Uint8> dir) obx_opt_directory;
  void Function(Pointer<Void> opt, int size_in_kb) obx_opt_max_db_size_in_kb;
  void Function(Pointer<Void> opt, int file_mode) obx_opt_file_mode;
  void Function(Pointer<Void> opt, int max_readers) obx_opt_max_readers;
  int Function(Pointer<Void> opt, Pointer<Void> model) obx_opt_model;
  void Function(Pointer<Void> opt) obx_opt_free;
  Pointer<Void> Function(Pointer<Void> opt) obx_store_open;
  int Function(Pointer<Void> store) obx_store_close;

  // transactions
  Pointer<Void> Function(Pointer<Void> store) obx_txn_write;
  Pointer<Void> Function(Pointer<Void> store) obx_txn_read;
  int Function(Pointer<Void> txn) obx_txn_close;
  int Function(Pointer<Void> txn) obx_txn_abort;
  int Function(Pointer<Void> txn) obx_txn_success;

  // box management
  Pointer<Void> Function(Pointer<Void> store, int entity_id) obx_box;
  int Function(Pointer<Void> box, int id, Pointer<Int8> out_contains) obx_box_contains;
  int Function(Pointer<Void> box, Pointer<Uint64> ids, Pointer<Int8> out_contains) obx_box_contains_many;
  int Function(Pointer<Void> box, int id, Pointer<Pointer<Void>> data, Pointer<Int32> size) obx_box_get;
  Pointer<Uint64> Function(Pointer<Void> box, Pointer<Uint64> ids) obx_box_get_many;
  Pointer<Uint64> Function(Pointer<Void> box) obx_box_get_all;
  int Function(Pointer<Void> box, int id_or_zero) obx_box_id_for_put;
  int Function(Pointer<Void> box, int count, Pointer<Uint64> out_first_id) obx_box_ids_for_put;
  int Function(Pointer<Void> box, int id, Pointer<Void> data, int size, int mode) obx_box_put;
  int Function(Pointer<Void> box, Pointer<Uint64> objects, Pointer<Uint64> ids, int mode) obx_box_put_many;
  int Function(Pointer<Void> box, int id) obx_box_remove;

  // TODO return .asFunction() -> requires properly determined static return type
  Pointer<NativeFunction<T>> _fn<T extends Function>(String name) {
    return objectbox.lookup<NativeFunction<T>>(name);
  }

  _ObjectBoxBindings() {
    var libName = "objectbox";
    if (Platform.isWindows)
      libName += ".dll";
    else if (Platform.isMacOS)
      libName = "lib" + libName + ".dylib";
    else if (Platform.isLinux || Platform.isAndroid)
      libName = "lib" + libName + ".so";
    else
      throw Exception("unsupported platform detected");
    objectbox = DynamicLibrary.open(libName);

    // common functions
    obx_version = _fn<obx_version_native_t>("obx_version").asFunction();
    obx_version_string = _fn<obx_version_string_native_t>("obx_version_string").asFunction();
    obx_bytes_array_free = _fn<obx_bytes_array_free_native_t>("obx_bytes_array_free").asFunction();

    // error info
    obx_last_error_code = _fn<obx_last_error_code_native_t>("obx_last_error_code").asFunction();
    obx_last_error_message = _fn<obx_last_error_message_native_t>("obx_last_error_message").asFunction();
    obx_last_error_secondary = _fn<obx_last_error_secondary_native_t>("obx_last_error_secondary").asFunction();
    obx_last_error_clear = _fn<obx_last_error_clear_native_t>("obx_last_error_clear").asFunction();

    // schema model creation
    obx_model = _fn<obx_model_native_t>("obx_model").asFunction();
    obx_model_free = _fn<obx_model_free_native_t>("obx_model_free").asFunction();
    obx_model_entity = _fn<obx_model_entity_native_t>("obx_model_entity").asFunction();
    obx_model_property = _fn<obx_model_property_native_t>("obx_model_property").asFunction();
    obx_model_property_flags = _fn<obx_model_property_flags_native_t>("obx_model_property_flags").asFunction();
    obx_model_entity_last_property_id =
        _fn<obx_model_entity_last_property_id_native_t>("obx_model_entity_last_property_id").asFunction();
    obx_model_last_entity_id = _fn<obx_model_last_entity_id_native_t>("obx_model_last_entity_id").asFunction();

    // object store management
    obx_opt = _fn<obx_opt_native_t>("obx_opt").asFunction();
    obx_opt_directory = _fn<obx_opt_directory_native_t>("obx_opt_directory").asFunction();
    obx_opt_max_db_size_in_kb = _fn<obx_opt_max_db_size_in_kb_native_t>("obx_opt_max_db_size_in_kb").asFunction();
    obx_opt_file_mode = _fn<obx_opt_file_mode_native_t>("obx_opt_file_mode").asFunction();
    obx_opt_max_readers = _fn<obx_opt_max_readers_native_t>("obx_opt_max_readers").asFunction();
    obx_opt_model = _fn<obx_opt_model_native_t>("obx_opt_model").asFunction();
    obx_store_open = _fn<obx_store_open_native_t>("obx_store_open").asFunction();
    obx_store_close = _fn<obx_store_close_native_t>("obx_store_close").asFunction();

    // transactions
    obx_txn_write = _fn<obx_txn_write_native_t>("obx_txn_write").asFunction();
    obx_txn_read = _fn<obx_txn_read_native_t>("obx_txn_read").asFunction();
    obx_txn_close = _fn<obx_txn_close_native_t>("obx_txn_close").asFunction();
    obx_txn_abort = _fn<obx_txn_abort_native_t>("obx_txn_abort").asFunction();
    obx_txn_success = _fn<obx_txn_success_native_t>("obx_txn_success").asFunction();

    // box management
    obx_box = _fn<obx_box_native_t>("obx_box").asFunction();
    obx_box_contains = _fn<obx_box_contains_native_t>("obx_box_contains").asFunction();
    obx_box_contains_many = _fn<obx_box_contains_many_native_t>("obx_box_contains_many").asFunction();
    obx_box_get = _fn<obx_box_get_native_t>("obx_box_get").asFunction();
    obx_box_get_many = _fn<obx_box_get_many_native_t>("obx_box_get_many").asFunction();
    obx_box_get_all = _fn<obx_box_get_all_native_t>("obx_box_get_all").asFunction();
    obx_box_id_for_put = _fn<obx_box_id_for_put_native_t>("obx_box_id_for_put").asFunction();
    obx_box_ids_for_put = _fn<obx_box_ids_for_put_native_t>("obx_box_ids_for_put").asFunction();
    obx_box_put = _fn<obx_box_put_native_t>("obx_box_put").asFunction();
    obx_box_put_many = _fn<obx_box_put_many_native_t>("obx_box_put_many").asFunction();
    obx_box_remove = _fn<obx_box_remove_native_t>("obx_box_remove").asFunction();
  }
}

_ObjectBoxBindings _cachedBindings;

_ObjectBoxBindings get bindings => _cachedBindings ??= _ObjectBoxBindings();
