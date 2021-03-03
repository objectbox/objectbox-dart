import 'dart:typed_data';
import 'dart:ffi';

import 'package:ffi/ffi.dart' show allocate, free;
import 'package:benchmark_harness/benchmark_harness.dart';

// Results:
// $ ~/lib/dart-2.12-beta/bin/dart run bin/native_pointers.dart
// AsTypedList[size=256](RunTime): 1.4307100324198732 us.
// AsTypedListUint64[size=32](RunTime): 1.4447894242577477 us.
//
// A quick profiling session shows .asTypedList() taking about 90% of the time,
// which is consistent with profiling objectbox-dart Box.read().

void main() {
  final sizeInBytes = 256;
  AsTypedList(sizeInBytes).report();

  // just checking if using a larger underlying type would help with anything
  AsTypedListUint64((sizeInBytes / 8).floor()).report();
}

class AsTypedList extends BenchmarkBase {
  final int length;
  Pointer<Uint8> nativePtr;

  AsTypedList(this.length) : super('${AsTypedList}[size=$length]');

  @override
  void run() {
    final typedList = nativePtr.asTypedList(length);
    final data = ByteData.view(typedList.buffer, typedList.offsetInBytes);
    // actually using the data (read flatbuffers) doesn't matter here
  }

  @override
  void setup() => nativePtr = allocate<Uint8>(count: length);

  @override
  void teardown() => free(nativePtr);
}

class AsTypedListUint64 extends BenchmarkBase {
  final int length;
  Pointer<Uint64> nativePtr;

  AsTypedListUint64(this.length) : super('${AsTypedListUint64}[size=$length]');

  @override
  void run() {
    final typedList = nativePtr.asTypedList(length);
    final data = ByteData.view(typedList.buffer, typedList.offsetInBytes);
    // actually using the data (read flatbuffers) doesn't matter here
  }

  @override
  void setup() => nativePtr = allocate<Uint64>(count: length);

  @override
  void teardown() => free(nativePtr);
}
