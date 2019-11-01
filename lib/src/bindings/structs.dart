import 'dart:ffi';
import "dart:typed_data" show Uint8List, Uint64List, Float64List, Float32List, DoubleList, FloatList;
import "package:ffi/ffi.dart";

import '../common.dart';

// Note: IntPtr seems to be the the correct representation for size_t: "Represents a native pointer-sized integer in C."

/// Represents the following C struct:
///   struct OBX_id_array {
///     obx_id* ids;
///     size_t count;
///   };
class OBX_id_array extends Struct<OBX_id_array> {
  Pointer<Uint64> _itemsPtr;

  @IntPtr() // size_t
  int length;

  /// Get a copy of the list
  List<int> items() => Uint64List.view(_itemsPtr.asExternalTypedData(count: length).buffer).toList();

  /// Execute the given function, managing the resources consistently
  static R executeWith<R>(List<int> items, R Function(Pointer<OBX_id_array>) fn) {
    // allocate a temporary structure
    final ptr = Pointer<OBX_id_array>.allocate();

    // fill it with data
    OBX_id_array array = ptr.load();
    array.length = items.length;
    array._itemsPtr = Pointer<Uint64>.allocate(count: array.length);
    for (int i = 0; i < items.length; ++i) {
      array._itemsPtr.elementAt(i).store(items[i]);
    }

    // call the function with the structure and free afterwards
    try {
      return fn(ptr);
    } finally {
      array._itemsPtr.free();
      ptr.free();
    }
  }
}

/// Represents the following C struct:
///   struct OBX_bytes {
///     const void* data;
///     size_t size;
///   };
class OBX_bytes extends Struct<OBX_bytes> {
  Pointer<Uint8> _dataPtr;

  @IntPtr() // size_t
  int length;

  /// Get access to the data (no-copy)
  Uint8List get data => isEmpty
      ? throw ObjectBoxException("can't access data of empty OBX_bytes")
      : Uint8List.view(_dataPtr.asExternalTypedData(count: length).buffer);

  bool get isEmpty => length == 0 || _dataPtr.address == 0;

  Pointer<Uint8> get ptr => _dataPtr;

  /// Returns a pointer to OBX_bytes with copy of the passed data.
  /// Warning: this creates an two unmanaged pointers which must be freed manually: OBX_bytes.freeManaged(result).
  static Pointer<OBX_bytes> managedCopyOf(Uint8List data) {
    final ptr = Pointer<OBX_bytes>.allocate();
    final OBX_bytes bytes = ptr.load();

    const align = true; // ObjectBox requires data to be aligned to the length of 4
    bytes.length = align ? ((data.length + 3.0) ~/ 4.0) * 4 : data.length;

    // TODO (perf) find a way to get access to the underlying memory of Uint8List to avoid a copy
    //  In that case, don't forget to change the caller (FlatbuffersManager) which expect to get a copy
    // if (data.length == bytes.length) {
    //   bytes._dataPtr = data.some-way-to-get-the-underlying-memory-pointer
    //   return ptr;
    // }

    // create a copy of the data
    bytes._dataPtr = Pointer<Uint8>.allocate(count: bytes.length);
    for (int i = 0; i < data.length; ++i) {
      bytes._dataPtr.elementAt(i).store(data[i]);
    }

    return ptr;
  }

  /// Free a dart-created OBX_bytes pointer.
  static void freeManaged(Pointer<OBX_bytes> ptr) {
    final OBX_bytes bytes = ptr.load();
    bytes._dataPtr.free();
    ptr.free();
  }
}

/// Represents the following C struct:
///   struct OBX_bytes_array {
///     OBX_bytes* bytes;
///     size_t count;
///   };
class OBX_bytes_array extends Struct<OBX_bytes_array> {
  Pointer<OBX_bytes> _items;

  @IntPtr() // size_t
  int length;

  /// Get a list of the underlying OBX_bytes (a shallow copy).
  List<OBX_bytes> items() {
    final result = List<OBX_bytes>();
    for (int i = 0; i < length; i++) {
      result.add(_items.elementAt(i).load());
    }
    return result;
  }

  /// TODO: try this with new Dart 2.6 FFI... with the previous versions it was causing memory corruption issues.
  /// It's supposed to be used by PutMany()
//  /// Create a dart-managed OBX_bytes_array.
//  static Pointer<OBX_bytes_array> createManaged(int count) {
//    final ptr = Pointer<OBX_bytes_array>.allocate();
//    final OBX_bytes_array array = ptr.load();
//    array.length = count;
//    array._items = Pointer<OBX_bytes>.allocate(count: count);
//    return ptr;
//  }
//
//  /// Replace the data at the given index with the passed pointer.
//  void setAndFree(int i, Pointer<OBX_bytes> src) {
//    assert(i >= 0 && i < length);
//
//    final OBX_bytes srcBytes = src.load();
//    final OBX_bytes tarBytes = _items.elementAt(i).load();
//
//    assert(!srcBytes.isEmpty);
//    assert(tarBytes.isEmpty);
//
//    tarBytes._dataPtr = srcBytes._dataPtr;
//    tarBytes.length = srcBytes.length;
//
//    srcBytes._dataPtr.store(nullptr.address);
//    srcBytes.length = 0;
//    src.free();
//  }
//
//  /// Free a dart-created OBX_bytes pointer.
//  static void freeManaged(Pointer<OBX_bytes_array> ptr, bool freeIncludedBytes) {
//    final OBX_bytes_array array = ptr.load();
//    if (freeIncludedBytes) {
//      for (int i = 0; i < array.length; i++) {
//        // Calling OBX_bytes.freeManaged() would cause double free
//        final OBX_bytes bytes = array._items.elementAt(i).load();
//        bytes._dataPtr.free();
//      }
//    }
//    array._items.free();
//    ptr.free();
//  }
}

class OBX_int8_array extends Struct<OBX_int8_array> {
  Pointer<Uint8> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<int> items() => Uint64List.view(_itemsPtr.asExternalTypedData(count: count).buffer).toList();
}

class OBX_int16_array extends Struct<OBX_int16_array> {
  Pointer<Uint16> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<int> items() => Uint64List.view(_itemsPtr.asExternalTypedData(count: count).buffer).toList();
}

class OBX_int32_array extends Struct<OBX_int32_array> {
  Pointer<Uint32> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<int> items() => Uint64List.view(_itemsPtr.asExternalTypedData(count: count).buffer).toList();
}

class OBX_int64_array extends Struct<OBX_int64_array> {
  Pointer<Uint64> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<int> items() => Uint64List.view(_itemsPtr.asExternalTypedData(count: count).buffer).toList();
}

class OBX_string_array extends Struct<OBX_string_array> {

  Pointer<Pointer<Uint8>> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<String> items() {
    final list = <String>[];
    for (int i=0; i<count; i++) {
      list.add(Utf8.fromUtf8(_itemsPtr.elementAt(i).load().cast<Utf8>()));
    }
    return list;
  }
}

class OBX_float_array extends Struct<OBX_float_array> {

  Pointer<Float> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<double> items() => Float64List.view(_itemsPtr.asExternalTypedData(count: count).buffer).toList();
}


class OBX_double_array extends Struct<OBX_double_array> {

  Pointer<Double> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<double> items() => Float64List.view(_itemsPtr.asExternalTypedData(count: count).buffer).toList();
}