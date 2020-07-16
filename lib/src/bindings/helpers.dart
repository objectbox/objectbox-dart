import "dart:ffi";
import "package:ffi/ffi.dart";

import "bindings.dart";
import "constants.dart";
import "../common.dart";

checkObx(int code) {
  if (code != OBXError.OBX_SUCCESS) throw latestNativeError(codeIfMissing: code);
}

Pointer<T> checkObxPtr<T extends NativeType>(Pointer<T> ptr, String dartMsg) {
  if (ptr == null || ptr.address == 0) {
    throw latestNativeError(dartMsg: dartMsg);
  }
  return ptr;
}

ObjectBoxException latestNativeError({String dartMsg, int codeIfMissing}) {
  int code = bindings.obx_last_error_code();
  String text = cString(bindings.obx_last_error_message());

  if (code == 0 && text.isEmpty) {
    return ObjectBoxException(dartMsg: dartMsg, nativeCode: codeIfMissing, nativeMsg: 'unknown native error');
  }

  return ObjectBoxException(dartMsg: dartMsg, nativeCode: code, nativeMsg: text);
}

String cString(Pointer<Utf8> charPtr) {
  // Utf8.fromUtf8 segfaults when called on nullptr
  if (charPtr.address == 0) {
    return "";
  }

  return Utf8.fromUtf8(charPtr);
}
