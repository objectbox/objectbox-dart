import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../common.dart';
import '../../modelinfo/entity_definition.dart';
import '../store.dart';
import 'bindings.dart';

// ignore_for_file: public_member_api_docs

@pragma('vm:prefer-inline')
void checkObx(int code) {
  if (code != OBX_SUCCESS) {
    throwLatestNativeError(codeIfMissing: code);
  }
}

@pragma('vm:prefer-inline')
bool checkObxSuccess(int code) {
  if (code == OBX_NO_SUCCESS) return false;
  checkObx(code);
  return true;
}

@pragma('vm:prefer-inline')
Pointer<T> checkObxPtr<T extends NativeType>(Pointer<T>? ptr,
    [String? context]) {
  if (ptr == null || ptr.address == 0) {
    throwLatestNativeError(context: context);
  }
  return ptr;
}

Never throwLatestNativeError({String? context, int codeIfMissing = 0}) {
  var code = C.last_error_code();
  var message = dartStringFromC(C.last_error_message());

  // Clear the error as the C API does not update error code on some failures.
  // If not cleared, this could then cause an incorrect error message to be
  // returned if the next failure does not update the error code.
  C.last_error_clear();

  if (code == 0 && message.isEmpty) {
    if (codeIfMissing == 0) {
      throw ObjectBoxException(context ?? 'unknown error');
    } else {
      code = codeIfMissing;
      message = '$code: Unknown native error';
    }
  }

  ObjectBoxNativeError(code, message, context).throwMapped();
}

class ObjectBoxNativeError {
  final String? context;
  final int code;
  final String message;

  ObjectBoxNativeError(this.code, this.message, this.context);

  String get messageWithContext =>
      context == null ? message : '$context: $message';

  String get messageWithErrorCode => code == 0
      ? messageWithContext
      : '$messageWithContext (OBX_ERROR code $code)';

  Never throwMapped() {
    switch (code) {
      case OBX_ERROR_ILLEGAL_STATE:
        throw StateError(messageWithErrorCode);
      case OBX_ERROR_ILLEGAL_ARGUMENT:
        throw ArgumentError(messageWithErrorCode);
      case OBX_ERROR_NUMERIC_OVERFLOW:
        throw NumericOverflowException(messageWithContext);
      case OBX_ERROR_DB_FULL:
        throw DbFullException(messageWithContext, code);
      case OBX_ERROR_MAX_DATA_SIZE_EXCEEDED:
        throw DbMaxDataSizeExceededException(messageWithContext, code);
      case OBX_ERROR_MAX_READERS_EXCEEDED:
        throw DbMaxReadersExceededException(messageWithContext, code);
      case OBX_ERROR_STORE_MUST_SHUTDOWN:
        throw DbShutdownException(messageWithContext, code);
      case OBX_ERROR_UNIQUE_VIOLATED:
        throw UniqueViolationException(messageWithContext);
      case OBX_ERROR_SCHEMA:
        throw SchemaException(messageWithContext);
      case OBX_ERROR_FILE_CORRUPT:
        throw DbFileCorruptException(messageWithContext, code);
      case OBX_ERROR_FILE_PAGES_CORRUPT:
        throw DbPagesCorruptException(messageWithContext, code);
      default:
        if (code == 0) {
          throw ObjectBoxException(messageWithContext);
        } else {
          throw StorageException(messageWithContext, code);
        }
    }
  }
}

@pragma('vm:prefer-inline')
String dartStringFromC(Pointer<Char> charPtr) =>
    charPtr.address == 0 ? '' : charPtr.cast<Utf8>().toDartString();

class CursorHelper<T> {
  final EntityDefinition<T> _entity;
  final Store _store;
  final Pointer<OBX_cursor> ptr;

  bool _closed = false;

  CursorHelper(this._store, Pointer<OBX_txn> txn, this._entity)
      : ptr = checkObxPtr(
            C.cursor(txn, _entity.model.id.id), 'failed to create cursor');

  EntityDefinition<T> get entity => _entity;

  void close() {
    if (_closed) return;
    _closed = true;
    checkObx(C.cursor_close(ptr));
  }

  T _deserializeObject(ReadPointers pointers) => _entity.objectFromData(
      _store, pointers.dataPtrPtr.value, pointers.sizePtr.value);

  @pragma('vm:prefer-inline')
  T? get(int id) {
    final pointers = _store.readPointers();
    final code = C.cursor_get(ptr, id, pointers.dataPtrPtr, pointers.sizePtr);
    if (code == OBX_NOT_FOUND) return null;
    checkObx(code);
    return _deserializeObject(pointers);
  }

  List<T> getAll() {
    final result = <T>[];
    final pointers = _store.readPointers();
    var code = C.cursor_first(ptr, pointers.dataPtrPtr, pointers.sizePtr);
    while (code != OBX_NOT_FOUND) {
      checkObx(code);
      result.add(_deserializeObject(pointers));
      code = C.cursor_next(ptr, pointers.dataPtrPtr, pointers.sizePtr);
    }
    return result;
  }
}

T withNativeBytes<T>(
    Uint8List data, T Function(Pointer<Uint8> ptr, int size) fn) {
  final size = data.length;
  assert(size == data.lengthInBytes);
  final ptr = malloc<Uint8>(size);
  try {
    ptr.asTypedList(size).setAll(0, data); // copies `data` to `ptr`
    return fn(ptr, size);
  } finally {
    malloc.free(ptr);
  }
}

T withNativeString<T>(String str, T Function(Pointer<Char> cStr) fn) {
  final cStr = str.toNativeUtf8();
  try {
    return fn(cStr.cast());
  } finally {
    malloc.free(cStr);
  }
}

T withNativeStrings<T>(
    List<String> items, T Function(Pointer<Pointer<Char>> ptr, int size) fn) {
  final size = items.length;
  final ptr = malloc<Pointer<Char>>(size);
  try {
    for (var i = 0; i < size; i++) {
      ptr[i] = items[i].toNativeUtf8().cast();
    }
    return fn(ptr, size);
  } finally {
    for (var i = 0; i < size; i++) {
      malloc.free((ptr + i).value);
    }
    malloc.free(ptr);
  }
}

T withNativeFloats<T>(
    List<double> items, T Function(Pointer<Float> ptr, int size) fn) {
  final size = items.length;
  final ptr = malloc<Float>(size);
  try {
    ptr.asTypedList(size).setAll(0, items);
    return fn(ptr, size);
  } finally {
    malloc.free(ptr);
  }
}

/// Execute the given function, managing the resources consistently
R executeWithIdArray<R>(List<int> items, R Function(Pointer<OBX_id_array>) fn) {
  // allocate a temporary structure
  final ptr = malloc<OBX_id_array>();

  // fill it with data
  final array = ptr.ref;
  array.count = items.length;
  array.ids = malloc<Uint64>(items.length);
  for (var i = 0; i < items.length; ++i) {
    array.ids[i] = items[i];
  }

  // call the function with the structure and free afterwards
  try {
    return fn(ptr);
  } finally {
    malloc.free(array.ids);
    malloc.free(ptr);
  }
}

extension NativeStringArrayAccess on Pointer<OBX_string_array> {
  List<String> toDartStrings() {
    final cArray = ref;
    final items = cArray.items.cast<Pointer<Utf8>>();
    return List<String>.generate(cArray.count, (i) => items[i].toDartString());
  }
}
