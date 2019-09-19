import "dart:ffi";
import "package:ffi/ffi.dart";

import "bindings.dart";
import "constants.dart";
import "../common.dart";

checkObx(errorCode) {
  if (errorCode != OBXError.OBX_SUCCESS) throw ObjectBoxException(lastObxErrorString(errorCode));
}

checkObxPtr(Pointer ptr, String msg, [bool hasLastError = false]) {
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

// partly from bin/objectbox_model_generator/lib/src/model.dart
class IdUid {
  int id, uid;

  IdUid(String str) {
    var spl = str.split(":");
    if (spl.length != 2) throw Exception("IdUid has invalid format, too many columns: $str");
    id = int.parse(spl[0]); // TODO: check integer bounds
    uid = int.parse(spl[1]);
    validate();
  }

  void validate() {
    if (id <= 0) throw Exception("id may not be <= 0");
    if (uid <= 0) throw Exception("uid may not be <= 0");
  }
}
