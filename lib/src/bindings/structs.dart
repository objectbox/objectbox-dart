import "dart:ffi";
import "dart:typed_data" show Uint8List;

class IDArray {
  // wrapper for "struct OBX_id_array"
  Pointer<Uint64> _idsPtr, _structPtr;

  IDArray(List<int> ids) {
    _idsPtr = Pointer<Uint64>.allocate(count: ids.length);
    for (int i = 0; i < ids.length; ++i) _idsPtr.elementAt(i).store(ids[i]);
    _structPtr = Pointer<Uint64>.allocate(count: 2);
    _structPtr.store(_idsPtr.address);
    _structPtr.elementAt(1).store(ids.length);
  }

  get ptr => _structPtr;

  free() {
    _idsPtr.free();
    _structPtr.free();
  }
}

class ByteBuffer {
  Pointer<Uint8> _ptr;
  int _size;

  ByteBuffer(this._ptr, this._size);

  ByteBuffer.allocate(Uint8List dartData, [bool align = true]) {
    _ptr = Pointer<Uint8>.allocate(count: align ? ((dartData.length + 3.0) ~/ 4.0) * 4 : dartData.length);
    for (int i = 0; i < dartData.length; ++i) _ptr.elementAt(i).store(dartData[i]);
    _size = dartData.length;
  }

  ByteBuffer.fromOBXBytes(Pointer<Uint64> obxPtr) {
    // extract fields from "struct OBX_bytes"
    _ptr = Pointer<Uint8>.fromAddress(obxPtr.load<int>());
    _size = obxPtr.elementAt(1).load<int>();
  }

  get ptr => _ptr;
  get voidPtr => Pointer<Void>.fromAddress(_ptr.address);
  get address => _ptr.address;
  get size => _size;

  Uint8List get data {
    var buffer = new Uint8List(size);
    for (int i = 0; i < size; ++i) buffer[i] = _ptr.elementAt(i).load<int>();
    return buffer;
  }

  free() => _ptr.free();
}

class _SerializedByteBufferArray {
  Pointer<Uint64> _outerPtr,
      _innerPtr; // outerPtr points to the instance itself, innerPtr points to the respective OBX_bytes_array.bytes

  _SerializedByteBufferArray(this._outerPtr, this._innerPtr);
  get ptr => _outerPtr;

  free() {
    _innerPtr.free();
    _outerPtr.free();
  }
}

class ByteBufferArray {
  List<ByteBuffer> _buffers;

  ByteBufferArray(this._buffers);

  ByteBufferArray.fromOBXBytesArray(Pointer<Uint64> bytesArray) {
    _buffers = [];
    Pointer<Uint64> bufferPtrs = Pointer<Uint64>.fromAddress(bytesArray.load<int>()); // bytesArray.bytes
    int numBuffers = bytesArray.elementAt(1).load<int>(); // bytesArray.count
    for (int i = 0; i < numBuffers; ++i) // loop through instances of "struct OBX_bytes"
      _buffers.add(ByteBuffer.fromOBXBytes(
          bufferPtrs.elementAt(2 * i))); // 2 * i, because each instance of "struct OBX_bytes" has .data and .size
  }

  _SerializedByteBufferArray toOBXBytesArray() {
    Pointer<Uint64> bufferPtrs = Pointer<Uint64>.allocate(count: _buffers.length * 2);
    for (int i = 0; i < _buffers.length; ++i) {
      bufferPtrs.elementAt(2 * i).store(_buffers[i].ptr.address as int);
      bufferPtrs.elementAt(2 * i + 1).store(_buffers[i].size as int);
    }

    Pointer<Uint64> outerPtr = Pointer<Uint64>.allocate(count: 2);
    outerPtr.store(bufferPtrs.address);
    outerPtr.elementAt(1).store(_buffers.length);
    return _SerializedByteBufferArray(outerPtr, bufferPtrs);
  }

  get buffers => _buffers;
}
