import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'bindings.dart';
import '../annotations.dart';
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

Pointer<T> checkObxPtr<T extends NativeType>(
    Pointer<T> /*?*/ ptr, String dartMsg) {
  if (ptr == null || ptr.address == 0) {
    throw latestNativeError(dartMsg: dartMsg);
  }
  return ptr;
}

ObjectBoxException latestNativeError(
    {String /*?*/ dartMsg, int codeIfMissing = OBX_ERROR_UNKNOWN}) {
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

String obxPropertyTypeToString(int type) {
  switch (type) {
    case OBXPropertyType.Bool:
      return 'bool';
    case OBXPropertyType.Byte:
      return 'byte';
    case OBXPropertyType.Short:
      return 'short';
    case OBXPropertyType.Char:
      return 'char';
    case OBXPropertyType.Int:
      return 'int';
    case OBXPropertyType.Long:
      return 'long';
    case OBXPropertyType.Float:
      return 'float';
    case OBXPropertyType.Double:
      return 'double';
    case OBXPropertyType.String:
      return 'string';
    case OBXPropertyType.Date:
      return 'date';
    case OBXPropertyType.Relation:
      return 'relation';
    case OBXPropertyType.DateNano:
      return 'dateNano';
    case OBXPropertyType.ByteVector:
      return 'byteVector';
    case OBXPropertyType.StringVector:
      return 'stringVector';
  }

  throw Exception('Invalid OBXPropertyType: ${type}');
}

int propertyTypeToOBXPropertyType(PropertyType type) {
  switch (type) {
    case PropertyType.byte:
      return OBXPropertyType.Byte;
    case PropertyType.short:
      return OBXPropertyType.Short;
    case PropertyType.char:
      return OBXPropertyType.Char;
    case PropertyType.int:
      return OBXPropertyType.Int;
    case PropertyType.float:
      return OBXPropertyType.Float;
    case PropertyType.date:
      return OBXPropertyType.Date;
    case PropertyType.dateNano:
      return OBXPropertyType.DateNano;
  }
  throw Exception('Invalid PropertyType: ${type}');
}
