import 'dart:ffi';
import 'dart:typed_data' show Uint8List;
import 'package:ffi/ffi.dart' show allocate, free, Utf8;
import '../common.dart';
import 'bindings.dart';

// Disable some linter rules for this file
// ignore_for_file: camel_case_types

/// Execute the given function, managing the resources consistently
R executeWithIdArray<R>(List<int> items, R Function(Pointer<OBX_id_array>) fn) {
  // allocate a temporary structure
  final ptr = allocate<OBX_id_array>();

  // fill it with data
  final array = ptr.ref;
  array.count = items.length;
  array.ids = allocate<Uint64>(count: items.length);
  for (var i = 0; i < items.length; ++i) {
    array.ids[i] = items[i];
  }

  // call the function with the structure and free afterwards
  try {
    return fn(ptr);
  } finally {
    free(array.ids);
    free(ptr);
  }
}

class OBX_bytes_wrapper {
  final Pointer<OBX_bytes> _cBytes;

  int get size => _cBytes == nullptr ? 0 : _cBytes.ref.size;

  Uint8List get data => safeDataAccess(_cBytes);

  /// Get access to the data (no-copy)
  static Uint8List safeDataAccess(Pointer<OBX_bytes> /*?*/ cBytes) =>
      cBytes == null || cBytes.address == 0 || cBytes.ref.size == 0
          ? throw ObjectBoxException(
              dartMsg: "can't access data of empty OBX_bytes")
          : cBytes.ref.data.cast<Uint8>().asTypedList(cBytes.ref.size);

  bool get isEmpty => size == 0;

  Pointer<Void> get ptr => _cBytes.ref.data;

  /// Returns a pointer to OBX_bytes with copy of the passed data.
  /// Warning: this creates two unmanaged pointers which must be freed manually: OBX_bytes.freeManaged(result).
  /// ObjectBox requires object data to be aligned to the length of 4.
  OBX_bytes_wrapper.managedCopyOf(Uint8List data, {/*required*/ bool align})
      : _cBytes = allocate<OBX_bytes>() {
    final bytes = _cBytes.ref;

    bytes.size = align ? ((data.length + 3.0) ~/ 4.0) * 4 : data.length;

    // NOTE: currently there's no way to get access to the underlying memory of Uint8List to avoid a copy.
    // See https://github.com/dart-lang/ffi/issues/27
    // if (data.length == bytes.length) {
    //   bytes._dataPtr = data.some-way-to-get-the-underlying-memory-pointer
    //   return ptr;
    // }

    // create a copy of the data
    bytes.data = allocate<Uint8>(count: bytes.size).cast<Void>();
    for (var i = 0; i < data.length; ++i) {
      bytes.data.cast<Uint8>()[i] = data[i];
    }
  }

  /// Free a dart-created OBX_bytes pointer.
  void freeManaged() {
    free(_cBytes.ref.data);
    free(_cBytes);
  }
}

class OBX_string_array_wrapper {
  final Pointer<OBX_string_array> _cPtr;

  OBX_string_array_wrapper(this._cPtr);

  List<String> items() {
    final list = <String>[];
    for (var i = 0; i < _cPtr.ref.count; i++) {
      list.add(Utf8.fromUtf8(_cPtr.ref.items.elementAt(i).value.cast<Utf8>()));
    }
    return list;
  }
}
