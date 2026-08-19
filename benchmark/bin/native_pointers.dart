import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:objectbox/src/native/bindings/nativemem.dart';
import 'package:objectbox_benchmark/benchmark.dart';

// Results
// Dart 3.0.5 (Flutter 3.10.5)
// Ubuntu 22.04.3 (WSL2, AMD Ryzen 7 5700X, 8-Core, 3.40 GHz, Uwe)
//
// $ dart compile exe bin/native_pointers.dart
// $ ./bin/native_pointers.exe
//
// AsTypedList[size=256](single iteration):   0.0160 us
// TypedListMemCopy(single iteration):        0.0163 us
//
// AsTypedList[size=1024](single iteration):  0.0165 us
// TypedListMemCopy(single iteration):        0.0232 us

/// This compares the performance of using Dart's Pointer.asTypedList vs.
/// manual memcpy to a buffer.
void main() async {
  final sizeInBytes = 1024;
  await AsTypedList(sizeInBytes).report();
  await TypedListMemCopy(sizeInBytes).report();
}

class AsTypedList extends Benchmark {
  final int length;
  late final Pointer<Uint8> nativePtr;

  AsTypedList(this.length)
    : super('$AsTypedList[size=$length]', iterations: 1000);

  @override
  void runIteration(int i) {
    final typedList = nativePtr.asTypedList(length);
    ByteData.view(typedList.buffer, typedList.offsetInBytes);
    // actually using the data (read flatbuffers) doesn't matter here
  }

  @override
  void setup() => nativePtr = malloc<Uint8>(length);

  @override
  void teardown() {
    malloc.free(nativePtr);
    super.teardown();
  }
}

class TypedListMemCopy extends Benchmark {
  final int length;
  late final Pointer<Uint8> nativePtr;
  late final Pointer<Uint8> nativePtr2;
  late final ByteBuffer buffer;
  late final ByteData data;

  TypedListMemCopy(this.length) : super('$TypedListMemCopy', iterations: 1000);

  @override
  void runIteration(int i) {
    memcpy(nativePtr, nativePtr2, length);
    ByteData.view(buffer, length);
    // actually using the data (read flatbuffers) doesn't matter here
  }

  @override
  void setup() {
    nativePtr = malloc<Uint8>(length);
    nativePtr2 = malloc<Uint8>(length);
    assert(nativePtr.asTypedList(length).offsetInBytes == 0);
    buffer = nativePtr.asTypedList(length).buffer;
    data = ByteData.view(buffer, 0);
  }

  @override
  void teardown() {
    malloc.free(nativePtr);
    malloc.free(nativePtr2);
    super.teardown();
  }
}
