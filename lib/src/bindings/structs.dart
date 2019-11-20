import 'dart:ffi';
import "dart:typed_data" show Uint8List;
import "package:ffi/ffi.dart" show allocate, free, Utf8;

import '../common.dart';

// Note: IntPtr seems to be the the correct representation for size_t: "Represents a native pointer-sized integer in C."

/// Represents the following C struct:
///   struct OBX_id_array {
///     obx_id* ids;
///     size_t count;
///   };
class OBX_id_array extends Struct {
  Pointer<Uint64> _itemsPtr;

  @IntPtr() // size_t
  int length;

  /// Get a copy of the list
  List<int> items() => _itemsPtr.asTypedList(length).toList();

  /// Execute the given function, managing the resources consistently
  static R executeWith<R>(List<int> items, R Function(Pointer<OBX_id_array>) fn) {
    // allocate a temporary structure
    final ptr = allocate<OBX_id_array>();

    // fill it with data
    OBX_id_array array = ptr.ref;
    array.length = items.length;
    array._itemsPtr = allocate<Uint64>(count: array.length);
    for (int i = 0; i < items.length; ++i) {
      array._itemsPtr.elementAt(i).value = items[i];
    }

    // call the function with the structure and free afterwards
    try {
      return fn(ptr);
    } finally {
      free(array._itemsPtr);
      free(ptr);
    }
  }
}

/// Represents the following C struct:
///   struct OBX_bytes {
///     const void* data;
///     size_t size;
///   };
class OBX_bytes extends Struct {
  Pointer<Uint8> _dataPtr;

  @IntPtr() // size_t
  int length;

  /// Get access to the data (no-copy)
  Uint8List get data =>
      isEmpty ? throw ObjectBoxException("can't access data of empty OBX_bytes") : _dataPtr.asTypedList(length);

  bool get isEmpty => length == 0 || _dataPtr.address == 0;

  Pointer<Uint8> get ptr => _dataPtr;

  /// Returns a pointer to OBX_bytes with copy of the passed data.
  /// Warning: this creates two unmanaged pointers which must be freed manually: OBX_bytes.freeManaged(result).
  static Pointer<OBX_bytes> managedCopyOf(Uint8List data) {
    final ptr = allocate<OBX_bytes>();
    final OBX_bytes bytes = ptr.ref;

    const align = true; // ObjectBox requires data to be aligned to the length of 4
    bytes.length = align ? ((data.length + 3.0) ~/ 4.0) * 4 : data.length;

    // NOTE: currently there's no way to get access to the underlying memory of Uint8List to avoid a copy.
    // See https://github.com/dart-lang/ffi/issues/27
    // if (data.length == bytes.length) {
    //   bytes._dataPtr = data.some-way-to-get-the-underlying-memory-pointer
    //   return ptr;
    // }

    // create a copy of the data
    bytes._dataPtr = allocate<Uint8>(count: bytes.length);
    for (int i = 0; i < data.length; ++i) {
      bytes._dataPtr.elementAt(i).value = data[i];
    }

    return ptr;
  }

  /// Free a dart-created OBX_bytes pointer.
  static void freeManaged(Pointer<OBX_bytes> ptr) {
    final OBX_bytes bytes = ptr.ref;
    free(bytes._dataPtr);
    free(ptr);
  }
}

/// Represents the following C struct:
///   struct OBX_bytes_array {
///     OBX_bytes* bytes;
///     size_t count;
///   };
class OBX_bytes_array extends Struct {
  Pointer<OBX_bytes> _items;

  @IntPtr() // size_t
  int length;

  /// Get a list of the underlying OBX_bytes (a shallow copy).
  List<OBX_bytes> items() {
    final result = List<OBX_bytes>();
    for (int i = 0; i < length; i++) {
      result.add(_items.elementAt(i).ref);
    }
    return result;
  }
}

class OBX_int8_array extends Struct {
  Pointer<Uint8> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<int> items() => _itemsPtr.asTypedList(count).toList();
}

class OBX_int16_array extends Struct {
  Pointer<Uint16> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<int> items() => _itemsPtr.asTypedList(count).toList();
}

class OBX_int32_array extends Struct {
  Pointer<Uint32> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<int> items() => _itemsPtr.asTypedList(count).toList();
}

class OBX_int64_array extends Struct {
  Pointer<Uint64> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<int> items() => _itemsPtr.asTypedList(count).toList();
}

class OBX_string_array extends Struct {

  Pointer<Pointer<Uint8>> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<String> items() {
    final list = <String>[];
    for (int i=0; i<count; i++) {
      list.add(Utf8.fromUtf8(_itemsPtr.elementAt(i).value.cast<Utf8>()));
    }
    return list;
  }
}

class OBX_float_array extends Struct {

  Pointer<Float> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<double> items() => _itemsPtr.asTypedList(count).toList();
}


class OBX_double_array extends Struct {

  Pointer<Double> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<double> items() => _itemsPtr.asTypedList(count).toList();
}