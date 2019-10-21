import "dart:ffi";
import "package:ffi/ffi.dart";

import "bindings.dart";
import "constants.dart";
import "../common.dart";

checkObx(errorCode) {
  if (errorCode != OBXError.OBX_SUCCESS) throw ObjectBoxException(lastObxErrorString(errorCode));
}

Pointer<T> checkObxPtr<T extends NativeType>(Pointer<T> ptr, String msg, [bool hasLastError = false]) {
  if (ptr == null || ptr.address == 0) throw ObjectBoxException("$msg: ${hasLastError ? lastObxErrorString() : ""}");
  return ptr;
}

String lastObxErrorString([err]) {
  if (err != null) return "code $err";

  int last = bindings.obx_last_error_code();
  int last2 = bindings.obx_last_error_secondary();
  String desc = Utf8.fromUtf8(bindings.obx_last_error_message().cast<Utf8>());
  return "code $last, $last2 ($desc)";
}
