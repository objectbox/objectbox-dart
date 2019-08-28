import "dart:ffi";

// common functions
typedef obx_version_native_t = Void Function(Pointer<Int32> major, Pointer<Int32> minor, Pointer<Int32> patch);

// schema model creation
typedef obx_model_create_native_t = Pointer<Void> Function();
typedef obx_model_free_native_t = Int32 Function(Pointer<Void>);
