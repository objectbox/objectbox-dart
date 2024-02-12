import 'dart:ffi';
import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:objectbox/internal.dart';
import 'package:objectbox/src/native/bindings/flatbuffers.dart';
import 'package:objectbox/src/native/bindings/nativemem.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

Uint8List addFbData(fb.Builder fbb) {
  fbb.startTable(2);
  fbb.addInt32(0, 24);
  fbb.addInt64(1, 42);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

void main() {
  test('custom flatbuffers builder', () {
    for (var initialSize in [1024, 1]) {
      printOnFailure('initialSize=$initialSize');

      final fb1 = BuilderWithCBuffer(initialSize: initialSize);
      final list1a = addFbData(fb1.fbb);
      final list1b = fb1.bufPtr.cast<Uint8>().asTypedList(fb1.fbb.size());

      printOnFailure(list1a.toString());
      printOnFailure(list1b.toString());

      // test resetting
      fb1.fbb.reset();
      expect(addFbData(fb1.fbb), equals(list1a));
      expect(
          fb1.bufPtr.cast<Uint8>().asTypedList(fb1.fbb.size()), equals(list1b));

      fb1.clear();
    }
  });

  bytesSum(ByteData data) => data.buffer.asInt8List().reduce((v, e) => v + e);

  // Note: only checks content initialized by TestEntity.filled
  void checkSameEntities(TestEntityNonRel a, TestEntityNonRel b) {
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
    // Closing manually below, but clean up if any expect fails before
    addTearDown(() => env.closeAndDelete());

    final binding = getObjectBoxModel().bindings[TestEntityNonRel]
        as EntityDefinition<TestEntityNonRel>;

    final source = TestEntityNonRel.filled();
    // Test the "dagger" char (0x20 0x20) which may cause problems if
    // utf16/ascii isn't recognized properly.
    source.tString = '${source.tString!}†asdf';

    final fb1 = BuilderWithCBuffer();
    binding.objectToFB(source, fb1.fbb);
    final fbData = ByteData.view(
        fb1.bufPtr.cast<Uint8>().asTypedList(fb1.fbb.size()).buffer);

    // must have the same content after reading back
    final target = binding.objectFromFB(env.store, fbData);

    // Note: we don't do check yet, because the default flatbuffers reader
    // reads lists lazily, on the first access and this would cause the next
    // [checkSameEntities()] after clearing the buffer to also pass.
    // checkSameEntities(target, source);

    // explicitly clear the allocated memory
    memset(fb1.bufPtr.cast<Uint8>(), 0, fbData.lengthInBytes);
    // fbData is now cleared as well, it's not a copy
    expect(bytesSum(fbData.buffer.asByteData()), isZero);

    // clearing the data must not affect already read objects
    // Note: it previously did because of upstream flatbuffers lazy reading
    checkSameEntities(target, source);

    // must be empty after reading again
    checkSameEntities(
        binding.objectFromFB(env.store, fbData), TestEntityNonRel());

    // note: accessing fbData after fb1.clear() is illegal (memory is freed)
    fb1.clear();
    env.closeAndDelete();

    // clearing the data must not affect already read objects
    checkSameEntities(target, source);
  });
}
