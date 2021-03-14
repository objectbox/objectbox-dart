import 'dart:typed_data';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
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

void main() {
  final sizeInBytes = 256;
  AsTypedList(sizeInBytes).report();

  // just checking if using a larger underlying type would help with anything
  AsTypedListUint64((sizeInBytes / 8).floor()).report();
}

class AsTypedList extends Benchmark {
  final int length;
  late final Pointer<Uint8> nativePtr;

  AsTypedList(this.length)
      : super('${AsTypedList}[size=$length]', iterations: 1000);

  @override
  void runIteration(int i) {
    final typedList = nativePtr.asTypedList(length);
    ByteData.view(typedList.buffer, typedList.offsetInBytes);
    // actually using the data (read flatbuffers) doesn't matter here
  }

  @override
  void setup() => nativePtr = malloc<Uint8>(length);

  @override
  void teardown() => malloc.free(nativePtr);
}

class AsTypedListUint64 extends Benchmark {
  final int length;
  late final Pointer<Uint64> nativePtr;

  AsTypedListUint64(this.length)
      : super('${AsTypedListUint64}[size=$length]', iterations: 1000);

  @override
  void runIteration(int i) {
    final typedList = nativePtr.asTypedList(length);
    ByteData.view(typedList.buffer, typedList.offsetInBytes);
    // actually using the data (read flatbuffers) doesn't matter here
  }

  @override
  void setup() => nativePtr = malloc<Uint64>(length);

  @override
  void teardown() => malloc.free(nativePtr);
}
