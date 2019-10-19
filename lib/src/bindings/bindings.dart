import "dart:ffi";
import "dart:io" show Platform;

import "signatures.dart";
import "structs.dart";

// bundles all C functions to be exposed to Dart
class _ObjectBoxBindings {
  DynamicLibrary objectbox;

  // common functions
  void Function(Pointer<Int32> major, Pointer<Int32> minor, Pointer<Int32> patch) obx_version;
  Pointer<Uint8> Function() obx_version_string;
  void Function(Pointer<Uint64> structPtr)
    obx_bytes_array_free, obx_string_array_free,
    obx_int64_array_free, obx_int32_array_free,
    obx_int16_array_free, obx_int8_array_free,
    obx_double_array_free, obx_float_array_free;
  obx_free_t<OBX_id_array> obx_id_array_free;

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
  Pointer<Uint64> Function(Pointer<Void> box, Pointer<OBX_id_array> ids) obx_box_get_many;
  Pointer<Uint64> Function(Pointer<Void> box) obx_box_get_all;
  int Function(Pointer<Void> box, int id_or_zero) obx_box_id_for_put;
  int Function(Pointer<Void> box, int count, Pointer<Uint64> out_first_id) obx_box_ids_for_put;
  int Function(Pointer<Void> box, int id, Pointer<Void> data, int size, int mode) obx_box_put;
  int Function(Pointer<Void> box, Pointer<Uint64> objects, Pointer<Uint64> ids, int mode) obx_box_put_many;
  int Function(Pointer<Void> box, int id) obx_box_remove;

  // query builder
  obx_query_builder_dart_t obx_qb_create;
  obx_qb_close_dart_t obx_qb_close;
  obx_qb_close_dart_t obx_qb_error_code;
  obx_qb_error_message_t obx_qb_error_message;

  obx_qb_cond_operator_0_dart_t obx_qb_null, obx_qb_not_null;

  obx_qb_cond_operator_1_dart_t<int>
    obx_qb_int_equal, obx_qb_int_not_equal,
    obx_qb_int_greater, obx_qb_int_less;

  obx_qb_cond_operator_2_dart_t<int> obx_qb_int_between;

  obx_qb_cond_operator_in_dart_t<Int64> obx_qb_int64_in, obx_qb_int64_not_in;
  obx_qb_cond_operator_in_dart_t<Int32> obx_qb_int32_in, obx_qb_int32_not_in;

  obx_qb_cond_string_op_1_dart_t
    obx_qb_string_equal,
    obx_qb_string_not_equal,
    obx_qb_string_contains,
    obx_qb_string_starts_with,
    obx_qb_string_ends_with;

  obx_qb_cond_operator_1_dart_t<double> obx_qb_double_greater, obx_qb_double_less;
  obx_qb_cond_operator_2_dart_t<double> obx_qb_double_between;

  obx_qb_string_lt_gt_op_dart_t obx_qb_string_greater, obx_qb_string_less;
  obx_qb_string_in_dart_t obx_qb_string_in;

  obx_qb_bytes_eq_dart_t obx_qb_bytes_equal;
  obx_qb_bytes_lt_gt_dart_t obx_qb_bytes_greater, obx_qb_bytes_less;

  obx_qb_join_op_dart_t obx_qb_all, obx_qb_any;

  obx_qb_param_alias_dart_t obx_qb_param_alias;

  obx_qb_order_dart_t obx_qb_order;

  // query
  obx_query_t obx_query_create;
  obx_query_close_dart_t obx_query_close;
  obx_query_find_t<int> obx_query_find;
  obx_query_find_ids_t<int> obx_query_find_ids;

  obx_query_count_dart_t obx_query_count, obx_query_remove;

  obx_query_describe_t obx_query_describe, obx_query_describe_params;

  obx_query_visit_dart_t obx_query_visit;

  // TODO return .asFunction() -> requires properly determined static return type
  Pointer<NativeFunction<T>> _fn<T extends Function>(String name) {
    return objectbox.lookup<NativeFunction<T>>(name);
  }

  _ObjectBoxBindings() {
    var libName = "objectbox";
    if (Platform.isWindows) {
      libName += ".dll";
    } else if (Platform.isMacOS) {
      libName = "lib" + libName + ".dylib";
    } else if (Platform.isLinux || Platform.isAndroid) {
      libName = "lib" + libName + ".so";
    } else {
      throw Exception("unsupported platform detected");
    }
    objectbox = DynamicLibrary.open(libName);

    // common functions
    obx_version = _fn<obx_version_native_t>("obx_version").asFunction();
    obx_version_string = _fn<obx_version_string_native_t>("obx_version_string").asFunction();
    obx_bytes_array_free = _fn<obx_free_struct_native_t>("obx_bytes_array_free").asFunction();
    obx_id_array_free = _fn<obx_free_t<OBX_id_array>>("obx_id_array_free").asFunction();
    obx_string_array_free = _fn<obx_free_struct_native_t>("obx_string_array_free").asFunction();
    obx_int64_array_free = _fn<obx_free_struct_native_t>("obx_int64_array_free").asFunction();
    obx_int32_array_free = _fn<obx_free_struct_native_t>("obx_int32_array_free").asFunction();
    obx_int16_array_free = _fn<obx_free_struct_native_t>("obx_int16_array_free").asFunction();
    obx_int8_array_free = _fn<obx_free_struct_native_t>("obx_int8_array_free").asFunction();
    obx_double_array_free = _fn<obx_free_struct_native_t>("obx_double_array_free").asFunction();
    obx_float_array_free = _fn<obx_free_struct_native_t>("obx_float_array_free").asFunction();

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

    // query builder
    obx_qb_create = _fn<obx_query_builder_native_t>("obx_query_builder").asFunction();
    obx_qb_close = _fn<obx_qb_close_native_t>("obx_qb_close").asFunction();
    obx_qb_error_code = _fn<obx_qb_close_native_t>("obx_qb_error_code").asFunction();
    obx_qb_error_message = _fn<obx_qb_error_message_t>("obx_qb_error_message").asFunction();

    obx_qb_null = _fn<obx_qb_cond_operator_0_native_t>("obx_qb_null").asFunction();
    obx_qb_not_null = _fn<obx_qb_cond_operator_0_native_t>("obx_qb_not_null").asFunction();

    obx_qb_int_equal = _fn<obx_qb_cond_operator_1_native_t<Int64>>("obx_qb_int_equal").asFunction();
    obx_qb_int_not_equal = _fn<obx_qb_cond_operator_1_native_t<Int64>>("obx_qb_int_not_equal").asFunction();
    obx_qb_int_greater = _fn<obx_qb_cond_operator_1_native_t<Int64>>("obx_qb_int_greater").asFunction();
    obx_qb_int_less = _fn<obx_qb_cond_operator_1_native_t<Int64>>("obx_qb_int_less").asFunction();

    obx_qb_int_between = _fn<obx_qb_cond_operator_2_native_t<Int64>>("obx_qb_int_between").asFunction();

    obx_qb_int64_in = _fn<obx_qb_cond_operator_in_native_t<Int64>>("obx_qb_int64_in").asFunction();
    obx_qb_int64_not_in = _fn<obx_qb_cond_operator_in_native_t<Int64>>("obx_qb_int64_not_in").asFunction();

    obx_qb_int32_in = _fn<obx_qb_cond_operator_in_native_t<Int32>>("obx_qb_int32_in").asFunction();
    obx_qb_int32_not_in = _fn<obx_qb_cond_operator_in_native_t<Int32>>("obx_qb_int32_not_in").asFunction();

    obx_qb_string_equal = _fn<obx_qb_cond_string_op_1_native_t>("obx_qb_string_equal").asFunction();
    obx_qb_string_not_equal = _fn<obx_qb_cond_string_op_1_native_t>("obx_qb_string_not_equal").asFunction();
    obx_qb_string_contains = _fn<obx_qb_cond_string_op_1_native_t>("obx_qb_string_contains").asFunction();

    obx_qb_string_starts_with = _fn<obx_qb_cond_string_op_1_native_t>("obx_qb_string_starts_with").asFunction();
    obx_qb_string_ends_with = _fn<obx_qb_cond_string_op_1_native_t>("obx_qb_string_ends_with").asFunction();

    obx_qb_string_greater = _fn<obx_qb_string_lt_gt_op_native_t>("obx_qb_string_greater").asFunction();
    obx_qb_string_less    = _fn<obx_qb_string_lt_gt_op_native_t>("obx_qb_string_less").asFunction();

    obx_qb_string_in = _fn<obx_qb_string_in_native_t>("obx_qb_string_in").asFunction();

    obx_qb_double_greater = _fn<obx_qb_cond_operator_1_native_t<Double>>("obx_qb_double_greater").asFunction();
    obx_qb_double_less = _fn<obx_qb_cond_operator_1_native_t<Double>>("obx_qb_double_less").asFunction();

    obx_qb_double_between = _fn<obx_qb_cond_operator_2_native_t<Double>>("obx_qb_double_between").asFunction();

    obx_qb_bytes_equal = _fn<obx_qb_bytes_eq_native_t>("obx_qb_bytes_equal").asFunction();
    obx_qb_bytes_greater = _fn<obx_qb_bytes_lt_gt_native_t>("obx_qb_bytes_greater").asFunction();
    obx_qb_bytes_less = _fn<obx_qb_bytes_lt_gt_native_t>("obx_qb_bytes_less").asFunction();

    obx_qb_all = _fn<obx_qb_join_op_native_t>("obx_qb_all").asFunction();
    obx_qb_any = _fn<obx_qb_join_op_native_t>("obx_qb_any").asFunction();

    obx_qb_param_alias = _fn<obx_qb_param_alias_native_t>("obx_qb_param_alias").asFunction();

    obx_qb_order = _fn<obx_qb_order_native_t>("obx_qb_order").asFunction();

    // query
    obx_query_create = _fn<obx_query_t>("obx_query").asFunction();
    obx_query_close = _fn<obx_query_close_native_t>("obx_query_close").asFunction();

    obx_query_find_ids = _fn<obx_query_find_ids_t<Uint64>>("obx_query_find_ids").asFunction();
    obx_query_find     = _fn<obx_query_find_t<Uint64>>("obx_query_find").asFunction();

    obx_query_count = _fn<obx_query_count_native_t>("obx_query_count").asFunction();
    obx_query_remove = _fn<obx_query_count_native_t>("obx_query_remove").asFunction();
    obx_query_describe = _fn<obx_query_describe_t>("obx_query_describe").asFunction();
    obx_query_describe_params = _fn<obx_query_describe_t>("obx_query_describe_params").asFunction();

    obx_query_visit = _fn<obx_query_visit_native_t>("obx_query_visit").asFunction();
  }
}

_ObjectBoxBindings _cachedBindings;

_ObjectBoxBindings get bindings => _cachedBindings ??= _ObjectBoxBindings();
