import 'dart:ffi';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:flat_buffers/flat_buffers.dart' as fbUpstream;
import 'package:objectbox/flatbuffers/flat_buffers.dart' as fbCustom;

Uint8List addFbData(dynamic fbb) {
  fbb.startTable();
  fbb.addInt32(0, 24);
  fbb.addInt64(1, 42);
  return fbb.finish(fbb.endTable());
}

void main() {
  test('custom flatbuffers builder', () {
    [1024, 1].forEach((initialSize) {
      printOnFailure('initialSize=$initialSize');

      final fb1 = fbCustom.Builder(initialSize: initialSize);
      final list1a = addFbData(fb1);
      final list1b = fb1.bufPtr.cast<Uint8>().asTypedList(fb1.bufPtrSize);

      final fb2 = fbUpstream.Builder(initialSize: initialSize);
      final list2 = addFbData(fb2);

      printOnFailure(list1a.toString());
      printOnFailure(list2.toString());
      expect(list1a, equals(list2));
      expect(list1a, equals(list1b));

      // test resetting
      fb1.reset();
      expect(addFbData(fb1), equals(list1a));
      expect(
          fb1.bufPtr.cast<Uint8>().asTypedList(fb1.bufPtrSize), equals(list1b));

      fb1.bufPtrFree();
    });
  });
}
