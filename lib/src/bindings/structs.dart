import 'dart:ffi';
import "dart:typed_data" show Uint8List, Uint64List;

import "package:ffi/ffi.dart" show allocate, free;

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
  List<int> items() => _itemsPtr.asTypedList(length);

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
  Uint8List get data => isEmpty
      ? throw ObjectBoxException("can't access data of empty OBX_bytes")
      : _dataPtr.asTypedList(length);

  bool get isEmpty => length == 0 || _dataPtr.address == 0;

  Pointer<Uint8> get ptr => _dataPtr;

  /// Returns a pointer to OBX_bytes with copy of the passed data.
  /// Warning: this creates an two unmanaged pointers which must be freed manually: OBX_bytes.freeManaged(result).
  static Pointer<OBX_bytes> managedCopyOf(Uint8List data) {
    final ptr = allocate<OBX_bytes>();
    final OBX_bytes bytes = ptr.ref;

    const align = true; // ObjectBox requires data to be aligned to the length of 4
    bytes.length = align ? ((data.length + 3.0) ~/ 4.0) * 4 : data.length;

    // TODO (perf) find a way to get access to the underlying memory of Uint8List to avoid a copy
    //  In that case, don't forget to change the caller (FlatbuffersManager) which expect to get a copy
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

  /// TODO: try this with new Dart 2.6 FFI... with the previous versions it was causing memory corruption issues.
  /// It's supposed to be used by PutMany()
//  /// Create a dart-managed OBX_bytes_array.
//  static Pointer<OBX_bytes_array> createManaged(int count) {
//    final ptr = allocate<OBX_bytes_array>();
//    final OBX_bytes_array array = ptr.ref;
//    array.length = count;
//    array._items = allocate<OBX_bytes>(count: count);
//    return ptr;
//  }
//
//  /// Replace the data at the given index with the passed pointer.
//  void setAndFree(int i, Pointer<OBX_bytes> src) {
//    assert(i >= 0 && i < length);
//
//    final OBX_bytes srcBytes = src.ref;
//    final OBX_bytes tarBytes = _items.elementAt(i).ref;
//
//    assert(!srcBytes.isEmpty);
//    assert(tarBytes.isEmpty);
//
//    tarBytes._dataPtr = srcBytes._dataPtr;
//    tarBytes.length = srcBytes.length;
//
//    srcBytes._dataPtr.value = nullptr.address;
//    srcBytes.length = 0;
//    free(src);
//  }
//
//  /// Free a dart-created OBX_bytes pointer.
//  static void freeManaged(Pointer<OBX_bytes_array> ptr, bool freeIncludedBytes) {
//    final OBX_bytes_array array = ptr.ref;
//    if (freeIncludedBytes) {
//      for (int i = 0; i < array.length; i++) {
//        // Calling OBX_bytes.freeManaged() would cause double free
//        final OBX_bytes bytes = array._items.elementAt(i).ref;
//        free(bytes._dataPtr);
//      }
//    }
//    free(array._items);
//    free(ptr);
//  }
}
