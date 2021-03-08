import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../../flatbuffers/flat_buffers.dart' as fb;

// ignore_for_file: public_member_api_docs

// Note: touch this file with caution, it's a hotspot and optimized for our use.

class BuilderWithCBuffer {
  final _allocator = Allocator();
  final int _initialSize;
  final int _resetIfLargerThan;

  /*late final*/
  fb.Builder _fbb;

  fb.Builder get fbb => _fbb;

  Pointer<Void> get bufPtr => Pointer<Void>.fromAddress(
      _allocator.bufAddress + _allocator._capacity - _fbb.size);

  BuilderWithCBuffer({int initialSize = 256, int resetIfLargerThan = 64 * 1024})
      : _initialSize = initialSize,
        _resetIfLargerThan = resetIfLargerThan {
    _fbb = fb.Builder(initialSize: initialSize, allocator: _allocator);
  }

  void resetIfLarge() {
    if (_allocator._capacity > _resetIfLargerThan) {
      clear();
      _fbb = fb.Builder(initialSize: _initialSize, allocator: _allocator);
    }
  }

  void clear() => _allocator.freeAll();

  Allocator get allocator => _allocator;
}

// FFI signature
typedef _dart_memset = void Function(Pointer<Uint8>, int, int);
typedef _c_memset = Void Function(Pointer<Uint8>, Int32, IntPtr);

_dart_memset /*?*/ fbMemset;

class Allocator extends fb.Allocator {
  // We may, in practice, have only two active allocations: one used and one
  // for resizing. Therefore, we use a ring buffer of a fixed size (2).
  // Note: keep the list fixed-size - those are much faster to index
  final _allocs = List<Pointer<Uint8>>.filled(2, nullptr, growable: false);

  // only used for sanity checks:
  final _data = List<ByteData /*?*/ >.filled(2, null, growable: false);

  // currently used allocator index
  int _index = 0;

  // allocated buffer capacity
  int _capacity = 0;

  int get bufAddress {
    assert(_allocs[_index].address != 0);
    return _allocs[_index].address;
  }

  // flips _index from 0 to 1 (or back), returning the new value
  int _flipIndex() => _index == 0 ? ++_index : --_index;

  @override
  ByteData allocate(int size) {
    _capacity = size;
    final index = _flipIndex();
    _allocs[index] = calloc<Uint8>(size) /*!*/;
    _data[index] = ByteData.view(_allocs[index].asTypedList(size).buffer);
    return _data[index] /*!*/;
  }

  @override
  void deallocate(ByteData data) {
    final index = _index == 0 ? 1 : 0; // get the other index

    // only used for sanity checks:
    assert(_data[index] == data);

    calloc.free(_allocs[index]);
    _allocs[index] = nullptr;
  }

  @override
  void clear(ByteData data, bool isFresh) {
    if (isFresh) return; // freshly allocated data is zero-ed out (see [calloc])

    if (fbMemset == null) {
      if (Platform.isWindows) {
        try {
          // DynamicLibrary.process() is not available on Windows, let's load a
          // lib that defines 'memset()' it - should be mscvr100 or mscvrt DLL.
          // mscvr100.dll is in the frequently installed MSVC Redistributable.
          fbMemset = DynamicLibrary.open('msvcr100.dll')
              .lookupFunction<_c_memset, _dart_memset>('memset');
        } catch (_) {
          // fall back if we can't load a native memset()
          fbMemset = (Pointer<Uint8> ptr, int byte, int size) {
            final bytes = ptr.cast<Uint8>();
            for (var i = 0; i < size; i++) {
              bytes[i] = byte;
            }
          };
        }
      } else {
        fbMemset = DynamicLibrary.process()
            .lookupFunction<_c_memset, _dart_memset>('memset');
      }
    }

    // only used for sanity checks:
    assert(_data[_index] == data);
    assert(_allocs[_index].address != 0);

    fbMemset /*!*/ (_allocs[_index], 0, data.lengthInBytes);
  }

  void freeAll() {
    if (_allocs[0].address != 0) calloc.free(_allocs[0]);
    if (_allocs[1].address != 0) calloc.free(_allocs[1]);
  }
}
