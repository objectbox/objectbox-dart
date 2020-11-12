import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'bindings.dart';
import '../common.dart';

void checkObx(int code) {
  if (code != OBX_SUCCESS) {
    throw latestNativeError(codeIfMissing: code);
  }
}

bool checkObxSuccess(int code) {
  if (code == OBX_NO_SUCCESS) return false;
  checkObx(code);
  return true;
}

Pointer<T> checkObxPtr<T extends NativeType>(Pointer<T> ptr, String dartMsg) {
  if (ptr == null || ptr.address == 0) {
    throw latestNativeError(dartMsg: dartMsg);
  }
  return ptr;
}

ObjectBoxException latestNativeError({String dartMsg, int codeIfMissing}) {
  final code = bindings.obx_last_error_code();
  final text = cString(bindings.obx_last_error_message());

  if (code == 0 && text.isEmpty) {
    return ObjectBoxException(
        dartMsg: dartMsg,
        nativeCode: codeIfMissing,
        nativeMsg: 'unknown native error');
  }

  return ObjectBoxException(
      dartMsg: dartMsg, nativeCode: code, nativeMsg: text);
}

String cString(Pointer<Int8> charPtr) {
  // Utf8.fromUtf8 segfaults when called on nullptr
  if (charPtr.address == 0) {
    return '';
  }

  return Utf8.fromUtf8(charPtr.cast<Utf8>());
}

// ffigen currently uses Pointer<Int32> for bool* so we need to clear the whole
// allocated memory before C call, to make sure the result looks is as expected.
Pointer<Int32> cBool() => allocate<Int32>()..value = 0;
