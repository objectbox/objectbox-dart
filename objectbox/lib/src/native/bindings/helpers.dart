import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../annotations.dart';
import '../../common.dart';
import '../../modelinfo/entity_definition.dart';
import '../store.dart';
import 'bindings.dart';

// ignore_for_file: public_member_api_docs

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

Pointer<T> checkObxPtr<T extends NativeType>(Pointer<T> /*?*/ ptr,
    [String dartMsg]) {
  if (ptr == null || ptr.address == 0) {
    throw latestNativeError(dartMsg: dartMsg);
  }
  return ptr;
}

ObjectBoxException latestNativeError(
    {String /*?*/ dartMsg, int codeIfMissing = OBX_ERROR_UNKNOWN}) {
  final code = C.last_error_code();
  final text = cString(C.last_error_message());

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

  throw Exception('Invalid OBXPropertyType: $type');
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
    case PropertyType.byteVector:
      return OBXPropertyType.ByteVector;
  }
  throw Exception('Invalid PropertyType: $type');
}

class CursorHelper<T> {
  final EntityDefinition<T> _entity;
  final Store _store;
  final Pointer<OBX_cursor> ptr;

  /*late final*/
  Pointer<Pointer<Void>> dataPtrPtr;

  /*late final*/
  Pointer<IntPtr> sizePtr;

  bool _closed = false;

  CursorHelper(this._store, Pointer<OBX_txn> txn, this._entity,
      {/*required*/ bool isWrite})
      : ptr = checkObxPtr(
            C.cursor(txn, _entity.model.id.id), 'failed to create cursor') {
    if (!isWrite) {
      dataPtrPtr = allocate();
      sizePtr = allocate();
    }
  }

  Uint8List get readData =>
      dataPtrPtr.value.cast<Uint8>().asTypedList(sizePtr.value);

  EntityDefinition<T> get entity => _entity;

  void close() {
    if (_closed) return;
    _closed = true;
    if (dataPtrPtr != null) free(dataPtrPtr);
    if (sizePtr != null) free(sizePtr);
    checkObx(C.cursor_close(ptr));
  }

  T /*?*/ get(int id) {
    final code = C.cursor_get(ptr, id, dataPtrPtr, sizePtr);
    if (code == OBX_NOT_FOUND) return null;
    checkObx(code);
    return _entity.objectFromFB(_store, readData);
  }
}
