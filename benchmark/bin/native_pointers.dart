import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:objectbox/src/native/bindings/nativemem.dart';
import 'package:objectbox_benchmark/benchmark.dart';

// Results (Dart SDK 2.12):
// $ dart run bin/native_pointers.dart
// AsTypedList[size=256](Single iteration): 0.1300 us
// AsTypedList[size=256](Runtime per unit): 0.1300 us
// AsTypedList[size=256](Runs per second):  7 692 912
// AsTypedList[size=256](Units per second): 7 692 912
// AsTypedListUint64[size=32](Single iteration): 0.1402 us
// AsTypedListUint64[size=32](Runtime per unit): 0.1402 us
// AsTypedListUint64[size=32](Runs per second):  7 131 882
// AsTypedListUint64[size=32](Units per second): 7 131 882
//
// A quick profiling session shows .asTypedList() taking about 90% of the time,
// which is consistent with profiling objectbox-dart Box.read().

void main() async {
  final sizeInBytes = 1024;
  await AsTypedList(sizeInBytes).report();

  // just checking if using a larger underlying type would help with anything
  // await AsTypedListUint64((sizeInBytes / 8).floor()).report();

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

class AsTypedListUint64 extends Benchmark {
  final int length;
  late final Pointer<Uint64> nativePtr;

  AsTypedListUint64(this.length)
      : super('$AsTypedListUint64[size=$length]', iterations: 1000);

  @override
  void runIteration(int i) {
    final typedList = nativePtr.asTypedList(length);
    ByteData.view(typedList.buffer, typedList.offsetInBytes);
    // actually using the data (read flatbuffers) doesn't matter here
  }

  @override
  void setup() => nativePtr = malloc<Uint64>(length);

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
