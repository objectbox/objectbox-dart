import "dart:ffi";

// common functions
typedef obx_version_native_t = Void Function(Pointer<Int32> major, Pointer<Int32> minor, Pointer<Int32> patch);
typedef obx_version_string_native_t = Pointer<Uint8> Function();

// error info
typedef obx_last_error_code_native_t = Int32 Function();
typedef obx_last_error_message_native_t = Pointer<Uint8> Function();
typedef obx_last_error_secondary_native_t = Int32 Function();
typedef obx_last_error_clear_native_t = Void Function();

// schema model creation
typedef obx_model_create_native_t = Pointer<Void> Function();
typedef obx_model_free_native_t = Int32 Function(Pointer<Void>);
typedef obx_model_entity_native_t = Int32 Function(Pointer<Void> model, Pointer<Uint8> name, Uint32 entity_id, Uint64 entity_uid);
typedef obx_model_property_native_t = Int32 Function(Pointer<Void> model, Pointer<Uint8> name, Uint32 type, Uint64 property_id, Uint64 property_uid);
typedef obx_model_property_flags_native_t = Int32 Function(Pointer<Void> model, Uint32 flags);
typedef obx_model_entity_last_property_id_native_t = Int32 Function(Pointer<Void> model, Uint32 property_id, Uint64 property_uid);
typedef obx_model_last_entity_id_native_t = Int32 Function(Pointer<Void> model, Uint32 entity_id, Uint64 entity_uid);

// object store management
typedef obx_opt_native_t = Pointer<Void> Function();
typedef obx_opt_model_native_t = Int32 Function(Pointer<Void> opt, Pointer<Void> model);
typedef obx_store_open_native_t = Pointer<Void> Function(Pointer<Void> opt);
typedef obx_store_close_native_t = Int32 Function(Pointer<Void> store);

// transactions
typedef obx_txn_write_native_t = Pointer<Void> Function(Pointer<Void> store);
typedef obx_txn_read_native_t = Pointer<Void> Function(Pointer<Void> store);
typedef obx_txn_close_native_t = Int32 Function(Pointer<Void> txn);
typedef obx_txn_abort_native_t = Int32 Function(Pointer<Void> txn);
typedef obx_txn_success_native_t = Int32 Function(Pointer<Void> txn);

// box management
typedef obx_box_native_t = Pointer<Void> Function(Pointer<Void> store, Uint32 entity_id);
typedef obx_box_get_native_t = Int32 Function(Pointer<Void> box, Uint64 id, Pointer<Pointer<Void>> data, Pointer<Int32> size);
typedef obx_box_id_for_put_native_t = Uint64 Function(Pointer<Void> box, Uint64 id_or_zero);
typedef obx_box_put_native_t = Int32 Function(Pointer<Void> box, Uint64 id, Pointer<Void> data, Int32 size, Int32 mode);
typedef obx_box_remove_native_t = Int32 Function(Pointer<Void> box, Uint64 id);
