import 'dart:ffi';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:flat_buffers/flat_buffers.dart' as fb_upstream;
import 'package:objectbox/src/bindings/flatbuffers.dart';

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

      final fb1 = BuilderWithCBuffer(initialSize: initialSize);
      final list1a = addFbData(fb1.fbb);
      final list1b = fb1.bufPtr.asTypedList(fb1.fbb.size);

      final fb2 = fb_upstream.Builder(initialSize: initialSize);
      final list2 = addFbData(fb2);

      printOnFailure(list1a.toString());
      printOnFailure(list1b.toString());
      printOnFailure(list2.toString());
      expect(list1a, equals(list2));
      expect(list1b, equals(list2));

      // test resetting
      fb1.fbb.reset();
      expect(addFbData(fb1.fbb), equals(list1a));
      expect(fb1.bufPtr.asTypedList(fb1.fbb.size), equals(list1b));

      fb1.close();
    });
  });
}
