import 'dart:ffi';
import "dart:typed_data" show Uint8List, Uint64List, Float64List, Float32List, DoubleList, FloatList;
import "package:ffi/ffi.dart";

import "package:ffi/ffi.dart" as ffi show allocate, free;

// Note: IntPtr seems to be the the correct representation for size_t: "Represents a native pointer-sized integer in C."

class OBX_id_array extends Struct {
  /*
    typedef struct OBX_id_array {
      obx_id* ids;
      size_t count;
    };
   */

  Pointer<Uint64> _itemsPtr;

  @IntPtr() // size_t
  int length;

  /// Get a copy of the list
  List<int> items() => _itemsPtr.asTypedList(length);

  /// Execute the given function, managing the resources consistently
  static R executeWith<R>(List<int> items, R Function(Pointer<OBX_id_array>) fn) {
    // allocate a temporary structure
    final ptr = ffi.allocate<OBX_id_array>();

    // fill it with data
    OBX_id_array array = ptr.ref;
    array.length = items.length;
    array._itemsPtr = ffi.allocate<Uint64>(count: array.length);
    for (int i = 0; i < items.length; ++i) {
      array._itemsPtr.elementAt(i).value = items[i];
    }

    // call the function with the structure and free afterwards
    try {
      return fn(ptr);
    } finally {
      ffi.free(array._itemsPtr);
      ffi.free(ptr);
    }
  }
}

// TODO change to a struct
class ByteBuffer {
  Pointer<Uint8> _ptr;
  int _size;

  ByteBuffer(this._ptr, this._size);

  ByteBuffer.allocate(Uint8List dartData, [bool align = true]) {
    _ptr = ffi.allocate<Uint8>(count: align ? ((dartData.length + 3.0) ~/ 4.0) * 4 : dartData.length);
    for (int i = 0; i < dartData.length; ++i) {
      _ptr.elementAt(i).value = dartData[i];
    }
    _size = dartData.length;
  }

  ByteBuffer.fromOBXBytes(Pointer<Uint64> obxPtr) {
    // extract fields from "struct OBX_bytes"
    _ptr = Pointer<Uint8>.fromAddress(obxPtr.value);
    _size = obxPtr.elementAt(1).value;
  }

  get ptr => _ptr;

  get voidPtr => Pointer<Void>.fromAddress(_ptr.address);

  get address => _ptr.address;

  get size => _size;

  Uint8List get data {
    var buffer = Uint8List(size);
    for (int i = 0; i < size; ++i) {
      buffer[i] = _ptr.elementAt(i).value;
    }
    return buffer;
  }

  // We're importing with the ffi alias because of this thing here
  free() => ffi.free(_ptr);
}

// TODO change to a struct
class _SerializedByteBufferArray {
  Pointer<Uint64> _outerPtr,
      _innerPtr; // outerPtr points to the instance itself, innerPtr points to the respective OBX_bytes_array.bytes

  _SerializedByteBufferArray(this._outerPtr, this._innerPtr);

  get ptr => _outerPtr;

  free() {
    ffi.free(_innerPtr);
    ffi.free(_outerPtr);
  }
}

// TODO change to a struct
class ByteBufferArray {
  List<ByteBuffer> _buffers;

  ByteBufferArray(this._buffers);

  ByteBufferArray.fromOBXBytesArray(Pointer<Uint64> bytesArray) {
    _buffers = [];
    Pointer<Uint64> bufferPtrs = Pointer<Uint64>.fromAddress(bytesArray.value); // bytesArray.bytes
    int numBuffers = bytesArray.elementAt(1).value; // bytesArray.count
    for (int i = 0; i < numBuffers; ++i) {
      _buffers.add(ByteBuffer.fromOBXBytes(bufferPtrs.elementAt(2 * i)));
    } // 2 * i, because each instance of "struct OBX_bytes" has .data and .size
  }

  _SerializedByteBufferArray toOBXBytesArray() {
    Pointer<Uint64> bufferPtrs = ffi.allocate<Uint64>(count: _buffers.length * 2);
    for (int i = 0; i < _buffers.length; ++i) {
      bufferPtrs.elementAt(2 * i).value = _buffers[i].ptr.address as int;
      bufferPtrs.elementAt(2 * i + 1).value = buffers[i].size as int;
    }

    Pointer<Uint64> outerPtr = ffi.allocate<Uint64>(count: 2);
    outerPtr.value = bufferPtrs.address;
    outerPtr.elementAt(1).value = _buffers.length;
    return _SerializedByteBufferArray(outerPtr, bufferPtrs);
  }

  get buffers => _buffers;
}

class OBX_int8_array extends Struct {
  Pointer<Uint8> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<int> items() => _itemsPtr.asTypedList(count);
}

class OBX_int16_array extends Struct {
  Pointer<Uint16> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<int> items() => _itemsPtr.asTypedList(count);
}

class OBX_int32_array extends Struct {
  Pointer<Uint32> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<int> items() => _itemsPtr.asTypedList(count);
}

class OBX_int64_array extends Struct {
  Pointer<Uint64> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<int> items() => _itemsPtr.asTypedList(count);
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

  List<double> items() => _itemsPtr.asTypedList(count);
}


class OBX_double_array extends Struct {

  Pointer<Double> _itemsPtr;

  @IntPtr() // size_t
  int count;

  List<double> items() => _itemsPtr.asTypedList(count);
}