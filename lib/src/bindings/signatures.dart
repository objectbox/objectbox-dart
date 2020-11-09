import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'structs.dart';

// ignore_for_file: non_constant_identifier_names

// typedefs for common signatures for different "classes", like store, box, ...
// obx_err fn(objectPtr)
typedef obx_fn_nullary_native = Int32 Function(Pointer<Void> obj);
typedef obx_fn_nullary_dart = int Function(Pointer<Void> obj);
// obx_err fn(void* objectPtr, Arg1 arg)
typedef obx_fn_unary_native<Arg1> = Int32 Function(Pointer<Void> obj, Arg1 arg);
typedef obx_fn_unary_dart<Arg1> = int Function(Pointer<Void> obj, Arg1 arg);
// obx_err fn(void* objectPtr, Arg1 arg1, Arg2 arg2)
typedef obx_fn_binary_native<Arg1, Arg2> = Int32 Function(
    Pointer<Void> obj, Arg1 arg1, Arg2 arg2);
typedef obx_fn_binary_dart<Arg1, Arg2> = int Function(
    Pointer<Void> obj, Arg1 arg1, Arg2 arg2);

// common functions
typedef obx_version_native_t = Void Function(
    Pointer<Int32> major, Pointer<Int32> minor, Pointer<Int32> patch);
typedef obx_version_string_native_t = Pointer<Utf8> Function();
typedef obx_supports_bytes_array_native_t = Uint8 Function();

typedef obx_free_dart_t<T extends NativeType> = void Function(Pointer<T> ptr);
typedef obx_free_native_t<T extends NativeType> = Void Function(
    T ptr); // no Pointer<T>, code analysis fails on usage

typedef obx_data_visitor_native_t = Uint8 Function(
    Pointer<Void> user_data, Pointer<Uint8> data, IntPtr size);

// error info
typedef obx_last_error_code_native_t = Int32 Function();
typedef obx_last_error_message_native_t = Pointer<Utf8> Function();
typedef obx_last_error_secondary_native_t = Int32 Function();
typedef obx_last_error_clear_native_t = Void Function();

// schema model creation
typedef obx_model_native_t = Pointer<Void> Function();
typedef obx_model_free_native_t = Int32 Function(Pointer<Void>);
typedef obx_model_error_code_native_t = Int32 Function(Pointer<Void>);
typedef obx_model_error_message_native_t = Pointer<Utf8> Function(
    Pointer<Void>);
typedef obx_model_entity_native_t = Int32 Function(Pointer<Void> model,
    Pointer<Utf8> name, Uint32 entity_id, Uint64 entity_uid);
typedef obx_model_property_native_t = Int32 Function(Pointer<Void> model,
    Pointer<Utf8> name, Uint32 type, Uint32 property_id, Uint64 property_uid);
typedef obx_model_flags_native_t = Int32 Function(
    Pointer<Void> model, Uint32 flags);
typedef obx_model_entity_last_property_id_native_t = Int32 Function(
    Pointer<Void> model, Uint32 property_id, Uint64 property_uid);
typedef obx_model_last_entity_id_native_t = Int32 Function(
    Pointer<Void> model, Uint32 entity_id, Uint64 entity_uid);

// object store management
typedef obx_opt_native_t = Pointer<Void> Function();
typedef obx_opt_directory_native_t = Int32 Function(
    Pointer<Void> opt, Pointer<Utf8> dir);
typedef obx_opt_max_db_size_in_kb_native_t = Void Function(
    Pointer<Void> opt, Int32 size_in_kb);
typedef obx_opt_file_mode_native_t = Void Function(
    Pointer<Void> opt, Uint32 file_mode);
typedef obx_opt_max_readers_native_t = Void Function(
    Pointer<Void> opt, Uint32 max_readers);
typedef obx_opt_model_native_t = Int32 Function(
    Pointer<Void> opt, Pointer<Void> model);
typedef obx_store_open_native_t = Pointer<Void> Function(Pointer<Void> opt);
typedef obx_store_close_native_t = Int32 Function(Pointer<Void> store);

// transactions
typedef obx_txn_write_native_t = Pointer<Void> Function(Pointer<Void> store);
typedef obx_txn_read_native_t = Pointer<Void> Function(Pointer<Void> store);
typedef obx_txn_close_native_t = Int32 Function(Pointer<Void> txn);
typedef obx_txn_abort_native_t = Int32 Function(Pointer<Void> txn);
typedef obx_txn_success_native_t = Int32 Function(Pointer<Void> txn);
typedef obx_txn_mark_success_native_t = Int32 Function(
    Pointer<Void> txn, Uint8 wasSuccessful);

// box management
typedef obx_box_native_t = Pointer<Void> Function(
    Pointer<Void> store, Uint32 entity_id);
typedef obx_box_contains_native_t = Int32 Function(
    Pointer<Void> box, Uint64 id, Pointer<Uint8> out_contains);
typedef obx_box_contains_many_native_t = Int32 Function(
    Pointer<Void> box, Pointer<OBX_id_array> ids, Pointer<Uint8> out_contains);
typedef obx_box_get_native_t = Int32 Function(Pointer<Void> box, Uint64 id,
    Pointer<Pointer<Uint8>> data, Pointer<IntPtr> size);
typedef obx_box_get_many_native_t = Pointer<OBX_bytes_array> Function(
    Pointer<Void> box, Pointer<OBX_id_array> ids);
typedef obx_box_get_all_native_t = Pointer<OBX_bytes_array> Function(
    Pointer<Void> box);
typedef obx_box_visit_many_native_t = Int32 Function(
    Pointer<Void> box,
    Pointer<OBX_id_array> ids,
    Pointer<NativeFunction<obx_data_visitor_native_t>> visitor,
    Pointer<Void> user_data);
typedef obx_box_visit_all_native_t = Int32 Function(
    Pointer<Void> box,
    Pointer<NativeFunction<obx_data_visitor_native_t>> visitor,
    Pointer<Void> user_data);
typedef obx_box_id_for_put_native_t = Uint64 Function(
    Pointer<Void> box, Uint64 id_or_zero);
typedef obx_box_ids_for_put_native_t = Int32 Function(
    Pointer<Void> box, Uint64 count, Pointer<Uint64> out_first_id);
typedef obx_box_put_native_t = Int32 Function(
    Pointer<Void> box, Uint64 id, Pointer<Uint8> data, IntPtr size, Int32 mode);
typedef obx_box_put_many_native_t = Int32 Function(Pointer<Void> box,
    Pointer<OBX_bytes_array> objects, Pointer<Uint64> ids, Int32 mode);
typedef obx_box_remove_native_t = Int32 Function(Pointer<Void> box, Uint64 id);
typedef obx_box_remove_all_native_t = Int32 Function(
    Pointer<Void> box, Pointer<Uint64> removed);
typedef obx_box_remove_many_native_t = Int32 Function(
    Pointer<Void> box, Pointer<OBX_id_array> ids, Pointer<Uint64> removed);
typedef obx_box_count_native_t = Int32 Function(
    Pointer<Void> box, Uint64 limit, Pointer<Uint64> _count);
typedef obx_box_is_empty_native_t = Int32 Function(
    Pointer<Void> box, Pointer<Uint8> is_empty);

// no typedef for non-functions yet, see https://github.com/dart-lang/language/issues/65
// typedef obx_err = Int32
// typedef Pointer<Int8> -> char[]
// typedef Pointer<Int32> -> int (e.g. obx_qb_cond);

// query builder
typedef obx_query_builder_native_t = Pointer<Void> Function(
    Pointer<Void> store, Uint32 entity_id);
typedef obx_query_builder_dart_t = Pointer<Void> Function(
    Pointer<Void> store, int entity_id);

typedef obx_qb_close_native_t = Int32 Function(Pointer<Void> builder);
typedef obx_qb_close_dart_t = int Function(Pointer<Void> builder);

typedef obx_qb_error_message_t = Pointer<Utf8> Function(Pointer<Void> builder);

typedef obx_qb_cond_operator_0_native_t = Int32 Function(
    Pointer<Void> builder, Uint32 property_id);
typedef obx_qb_cond_operator_0_dart_t = int Function(
    Pointer<Void> builder, int property_id);

typedef obx_qb_cond_operator_1_native_t<P> = Int32 Function(
    Pointer<Void> builder, Uint32 property_id, P value);
typedef obx_qb_cond_operator_1_dart_t<P> = int Function(
    Pointer<Void> builder, int property_id, P value);

typedef obx_qb_cond_operator_2_native_t<P> = Int32 Function(
    Pointer<Void> builder, Uint32 property_id, P v1, P v2);
typedef obx_qb_cond_operator_2_dart_t<P> = int Function(
    Pointer<Void> builder, int property_id, P v1, P v2);

typedef obx_qb_cond_operator_in_native_t<P extends NativeType> = Int32 Function(
    Pointer<Void> builder, Uint32 property_id, Pointer<P> values, Uint64 count);
typedef obx_qb_cond_operator_in_dart_t<P extends NativeType> = int Function(
    Pointer<Void> builder, int property_id, Pointer<P> values, int count);

typedef obx_qb_join_op_native_t = Int32 Function(
    Pointer<Void> builder, Pointer<Int32> cond_array, Uint64 count);
typedef obx_qb_join_op_dart_t = int Function(
    Pointer<Void> builder, Pointer<Int32> cond_array, int count);

typedef obx_qb_cond_string_op_1_native_t = Int32 Function(Pointer<Void> builder,
    Uint32 property_id, Pointer<Utf8> value, Int8 case_sensitive);
typedef obx_qb_cond_string_op_1_dart_t = int Function(Pointer<Void> builder,
    int property_id, Pointer<Utf8> value, int case_sensitive);

typedef obx_qb_string_in_native_t = Int32 Function(
    Pointer<Void> builder,
    Uint32 property_id,
    Pointer<Pointer<Utf8>> value,
    Uint64 count,
    Int8 case_sensitive);
typedef obx_qb_string_in_dart_t = int Function(
    Pointer<Void> builder,
    int property_id,
    Pointer<Pointer<Utf8>> value,
    int count,
    int case_sensitive);

typedef obx_qb_cond_bytes_native_t = Int32 Function(Pointer<Void> builder,
    Uint32 property_id, Pointer<Void> value, Uint64 size);
typedef obx_qb_cond_bytes_dart_t = int Function(
    Pointer<Void> builder, int property_id, Pointer<Void> value, int size);

typedef obx_qb_param_alias_native_t = Int32 Function(
    Pointer<Void> builder, Pointer<Utf8> alias);
typedef obx_qb_param_alias_dart_t = int Function(
    Pointer<Void> builder, Pointer<Utf8> alias);

typedef obx_qb_order_native_t = Int32 Function(
    Pointer<Void> builder, Uint32 property_id, Uint32 flags);
typedef obx_qb_order_dart_t = int Function(
    Pointer<Void> builder, int property_id, int flags);

// query

typedef obx_query_t = Pointer<Void> Function(Pointer<Void> builder);

typedef obx_query_close_native_t = Int32 Function(Pointer<Void> query);
typedef obx_query_close_dart_t = int Function(Pointer<Void> query);

typedef obx_query_offset_native_t = Int32 Function(
    Pointer<Void> query, Uint64 offset); // obx_err -> Int32
typedef obx_query_offset_dart_t = int Function(Pointer<Void> query, int offset);
typedef obx_query_limit_native_t = Int32 Function(
    Pointer<Void> query, Uint64 limit); // obx_err -> Int32
typedef obx_query_limit_dart_t = int Function(Pointer<Void> query, int limit);

typedef obx_query_find_t<T> = Pointer<OBX_bytes_array> Function(
    Pointer<Void> query);
typedef obx_query_find_ids_t<T> = Pointer<OBX_id_array> Function(
    Pointer<Void> query);

typedef obx_query_count_native_t = Int32 Function(
    Pointer<Void> query, Pointer<Uint64> count);
typedef obx_query_count_dart_t = int Function(
    Pointer<Void> query, Pointer<Uint64> count);

typedef obx_query_describe_t = Pointer<Utf8> Function(Pointer<Void> query);

typedef obx_query_visit_native_t = Int32 Function(
    Pointer<Void> query,
    Pointer<NativeFunction<obx_data_visitor_native_t>> visitor,
    Pointer<Void> user_data); // obx_err -> Int32
typedef obx_query_visit_dart_t = int Function(
    Pointer<Void> query,
    Pointer<NativeFunction<obx_data_visitor_native_t>> visitor,
    Pointer<Void> user_data);

// observers

typedef obx_observer_t = Void Function(
    Pointer<Void> user_data, Pointer<Uint32> entity_id, Uint32 type_ids_count);
typedef obx_observer_single_type_native_t = Void Function(
    Pointer<Void> user_data);
typedef obx_observer_single_type_dart_t = void Function(
    Pointer<Void> user_data);

typedef obx_observe_t = Pointer<Void> Function(Pointer<Void> store,
    Pointer<NativeFunction<obx_observer_t>> callback, Pointer<Void> user_data);
typedef obx_observe_single_type_t<T> = Pointer<Void> Function(
    Pointer<Void> store,
    T entity_id,
    Pointer<NativeFunction<obx_observer_single_type_native_t>> callback,
    Pointer<Void> user_data);
typedef obx_observer_close_native_t = Void Function(Pointer<Void> observer);
typedef obx_observer_close_dart_t = void Function(Pointer<Void> observer);

// query property

typedef obx_query_prop_t<T> = Pointer<Void> Function(
    Pointer<Void> query, T propertyId); // Uint32 -> int
typedef obx_query_prop_close_t<T> = T Function(
    Pointer<Void> query); // obx_err -> Int32 -> int
// note: can not use return type Pointer<T> as it throws off code analysis.
typedef obx_query_prop_find_native_t<T, V extends NativeType> = T Function(
    Pointer<Void> query, Pointer<V> value_if_null);
typedef obx_query_prop_distinct_t<T, V> = T Function(
    Pointer<Void> query, V distinct); // T = (Int32, int), V = (Int8, int)
typedef obx_query_prop_distinct2_t<T, V> = T Function(
    Pointer<Void> query, V distinct, V caseSensitive);
typedef obx_query_prop_op_t<T, V extends NativeType> = T Function(
    Pointer<Void> query, Pointer<V> outValue, Pointer<Int64> outCount);

// Utilities

typedef obx_bytes_array_t<SizeT> = Pointer<OBX_bytes_array> Function(
    SizeT count);
typedef obx_bytes_array_set_t<Ret, SizeT> = Ret Function(
    Pointer<OBX_bytes_array> array,
    SizeT index,
    Pointer<Uint8> data,
    SizeT size);

/*  // TODO
    obx_qb_bytes_eq_dart_t obx_qb_bytes_equal;
    obx_qb_bytes_lt_gt_dart_t obx_qb_bytes_greater, obx_qb_bytes_less;

    obx_qb_param_alias_dart_t obx_qb_param_alias;
*/

// Sync
typedef obx_sync_available_native_t = Uint8 Function();
typedef obx_sync_native_t = Pointer<Void> Function(
    Pointer<Void> store, Pointer<Utf8> serverUri);
typedef obx_sync_credentials_native_t = Int32 Function(
    Pointer<Void> sync, Int32 type, Pointer<Uint8> data, IntPtr size);
typedef obx_sync_credentials_dart_t = int Function(
    Pointer<Void> sync, int type, Pointer<Uint8> data, int size);
