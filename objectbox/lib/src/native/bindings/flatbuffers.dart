import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../../flatbuffers/flat_buffers.dart' as fb;
import 'nativemem.dart';

// ignore_for_file: public_member_api_docs

// Note: touch this file with caution, it's a hotspot and optimized for our use.

class BuilderWithCBuffer {
  final _allocator = Allocator();
  final int _initialSize;
  final int _resetIfLargerThan;

  late fb.Builder _fbb;

  fb.Builder get fbb => _fbb;

  @pragma('vm:prefer-inline')
  Pointer<Void> get bufPtr => Pointer<Void>.fromAddress(
      _allocator.bufAddress + _allocator._capacity - _fbb.size);

  BuilderWithCBuffer({int initialSize = 256, int resetIfLargerThan = 64 * 1024})
      : _initialSize = initialSize,
        _resetIfLargerThan = resetIfLargerThan {
    _fbb = fb.Builder(initialSize: initialSize, allocator: _allocator);
  }

  @pragma('vm:prefer-inline')
  void resetIfLarge() {
    if (_allocator._capacity > _resetIfLargerThan) {
      clear();
      _fbb = fb.Builder(initialSize: _initialSize, allocator: _allocator);
    }
  }

  void clear() => _allocator.freeAll();

  Allocator get allocator => _allocator;
}

class Allocator extends fb.Allocator {
  // We may, in practice, have only two active allocations: one used and one
  // for resizing. Therefore, we use a ring buffer of a fixed size (2).
  // Note: keep the list fixed-size - those are much faster to index
  final _allocs = List<Pointer<Uint8>>.filled(2, nullptr, growable: false);

  // only used for sanity checks:
  final _data = List<ByteData?>.filled(2, null, growable: false);

  // currently used allocator index
  int _index = 0;

  // allocated buffer capacity
  int _capacity = 0;

  @pragma('vm:prefer-inline')
  int get bufAddress {
    assert(_allocs[_index].address != 0);
    return _allocs[_index].address;
  }

  // flips _index from 0 to 1 (or back), returning the new value
  @pragma('vm:prefer-inline')
  int _flipIndex() => _index == 0 ? ++_index : --_index;

  @override
  ByteData allocate(int size) {
    _capacity = size;
    final index = _flipIndex();
    _allocs[index] = calloc<Uint8>(size);
    _data[index] = ByteData.view(_allocs[index].asTypedList(size).buffer);
    return _data[index]!;
  }

  @override
  void deallocate(ByteData data) {
    final index = _index == 0 ? 1 : 0; // get the other index

    // only used for sanity checks:
    assert(_data[index] == data);

    calloc.free(_allocs[index]);
    _allocs[index] = nullptr;
  }

  @pragma('vm:prefer-inline')
  @override
  void clear(ByteData data, bool isFresh) {
    if (isFresh) return; // freshly allocated data is zero-ed out (see [calloc])

    // only used for sanity checks:
    assert(_data[_index] == data);
    assert(_allocs[_index].address != 0);

    // TODO - there are other options to clear the builder, see how other
    //        FlatBuffer implementations do it.
    memset(_allocs[_index], 0, data.lengthInBytes);
  }

  void freeAll() {
    if (_allocs[0].address != 0) calloc.free(_allocs[0]);
    if (_allocs[1].address != 0) calloc.free(_allocs[1]);
  }
}

/// Implements a native data access wrapper to circumvent Pointer.asTypedList()
/// slowness. The idea is to reuse the same buffer and rather memcpy the data,
/// which ends up being faster than calling asTypedList(). Hopefully, we will
/// be able to remove this if (when) asTypedList() gets optimized in Dart SDK.
class ReaderWithCBuffer {
  // See /benchmark/bin/native_pointers.dart for the max buffer size where it
  // still makes sense to use memcpy. On Linux, memcpy starts to be slower at
  // about 10-15 KiB. TODO test on other platforms to find an optimal limit.
  static const _maxBuffer = 4 * 1024;
  final _bufferPtr = malloc<Uint8>(_maxBuffer);
  late final ByteBuffer _buffer = _bufferPtr.asTypedList(_maxBuffer).buffer;

  ReaderWithCBuffer() {
    assert(_bufferPtr.asTypedList(_maxBuffer).offsetInBytes == 0);
  }

  void clear() => malloc.free(_bufferPtr);

  ByteData access(Pointer<Uint8> dataPtr, int size) {
    if (size > _maxBuffer) {
      final uint8List = dataPtr.asTypedList(size);
      return ByteData.view(uint8List.buffer, uint8List.offsetInBytes, size);
    } else {
      memcpy(_bufferPtr, dataPtr, size);
      return ByteData.view(_buffer, 0, size);
    }
  }
}
