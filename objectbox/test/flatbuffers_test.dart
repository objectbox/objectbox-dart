import 'dart:ffi';
import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb_upstream;
import 'package:objectbox/internal.dart';
import 'package:objectbox/src/bindings/flatbuffers.dart';
import 'package:objectbox/flatbuffers/flat_buffers.dart' as fb;
import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

Uint8List addFbData(fb.Builder fbb) {
  fbb.startTable(2);
  fbb.addInt32(0, 24);
  fbb.addInt64(1, 42);
  return fbb.finish(fbb.endTable());
}

Uint8List addFbDataUpstream(fb_upstream.Builder fbb) {
  fbb.startTable();
  fbb.addInt32(0, 24);
  fbb.addInt64(1, 42);
  return fbb.finish(fbb.endTable());
}

void main() {
  test('custom flatbuffers builder', () {
    [1024, 1].forEach((initialSize) {
      printOnFailure('initialSize=$initialSize');

      final fb1 = BuilderWithCBuffer(initialSize: initialSize);
      final list1a = addFbData(fb1.fbb);
      final list1b = fb1.bufPtr.cast<Uint8>().asTypedList(fb1.fbb.size);

      final fb2 = fb_upstream.Builder(initialSize: initialSize);
      final list2 = addFbDataUpstream(fb2);

      printOnFailure(list1a.toString());
      printOnFailure(list1b.toString());
      printOnFailure(list2.toString());
      expect(list1a, equals(list2));
      expect(list1b, equals(list2));

      // test resetting
      fb1.fbb.reset();
      expect(addFbData(fb1.fbb), equals(list1a));
      expect(
          fb1.bufPtr.cast<Uint8>().asTypedList(fb1.fbb.size), equals(list1b));

      fb1.clear();
    });
  });

  final bytesSum =
      (ByteData data) => data.buffer.asInt8List().reduce((v, e) => v + e);

  test('allocator', () {
    final allocator = Allocator();

    final buf1 = allocator.allocate(1024);
    allocator.clear(buf1, true);

    final buf2 = allocator.allocate(1024);
    allocator.clear(buf2, true);

    expect(bytesSum(buf1), isZero);
    expect(bytesSum(buf2), isZero);

    buf2.setInt8(42, 1);
    expect(bytesSum(buf1), isZero);
    expect(bytesSum(buf2), 1);

    allocator.clear(buf2, true);
    expect(bytesSum(buf2), isZero);

    allocator.deallocate(buf1);
    allocator.freeAll();
  });

  // Note: only checks content initialized by TestEntity.filled
  void checkSameEntities(TestEntity a, TestEntity b) {
    expect(a.tString, b.tString);
    expect(a.tBool, b.tBool);
    expect(a.tByte, b.tByte);
    expect(a.tChar, b.tChar);
    expect(a.tShort, b.tShort);
    expect(a.tInt, b.tInt);
    expect(a.tLong, b.tLong);
    expect(a.tFloat, b.tFloat);
    expect(a.tDouble, b.tDouble);
    expect(a.tStrings, b.tStrings);
    expect(a.tByteList, b.tByteList);
    expect(a.tInt8List, b.tInt8List);
    expect(a.tUint8List, b.tUint8List);
  }

  test('generated code', () {
    final env = TestEnv('fb');

    final binding = getObjectBoxModel().bindings[TestEntity]
        as EntityDefinition<TestEntity>;

    final source = TestEntity.filled();

    final fb1 = BuilderWithCBuffer();
    binding.objectToFB(source, fb1.fbb);
    final fbData = fb1.bufPtr.cast<Uint8>().asTypedList(fb1.fbb.size);

    // must have the same content after reading back
    final target = binding.objectFromFB(env.store, fbData);

    // Note: we don't do check yet, because the default flatbuffers reader
    // reads lists lazily, on the first access and this would cause the next
    // [checkSameEntities()] after clearing the buffer to also pass.
    // checkSameEntities(target, source);

    // explicitly clear the allocated memory
    fbMemset(fb1.bufPtr.cast<Uint8>(), 0, fbData.lengthInBytes);
    // fbData is now cleared as well, it's not a copy
    expect(bytesSum(fbData.buffer.asByteData()), isZero);

    // clearing the data must not affect already read objects
    // Note: it previously did because of upstream flatbuffers lazy reading
    checkSameEntities(target, source);

    // must be empty after reading again
    checkSameEntities(binding.objectFromFB(env.store, fbData), TestEntity());

    // note: accessing fbData after fb1.clear() is illegal (memory is freed)
    fb1.clear();
    env.close();

    // clearing the data must not affect already read objects
    checkSameEntities(target, source);
  });
}
