import "dart:ffi";
import "constants.dart";
import "../common.dart";

checkObx(errorCode) {
  if (errorCode != OBXError.OBX_SUCCESS) throw ObjectBoxException(Common.lastErrorString(errorCode));
}

checkObxPtr(Pointer ptr, String msg, [bool hasLastError = false]) {
  if (ptr == null || ptr.address == 0)
    throw ObjectBoxException("$msg: ${hasLastError ? Common.lastErrorString() : ""}");
  return ptr;
}
