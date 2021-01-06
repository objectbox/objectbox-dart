import 'dart:ffi';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:flat_buffers/flat_buffers.dart' as fbUpstream;
import 'package:objectbox/flatbuffers/flat_buffers.dart' as fbCustom;

void main() {
  test('custom flatbuffers builder', () {
    [1024, 1].forEach((initialSize) {
      printOnFailure('initialSize=$initialSize');

      final fb1 = fbCustom.Builder(initialSize: initialSize);
      fb1.startTable();
      fb1.addFloat32(0, 24);
      fb1.addFloat64(1, 42);
      final list1a = fb1.finish(fb1.endTable());
      final list1b = fb1.bufPtr.cast<Uint8>().asTypedList(fb1.bufPtrSize);

      final fb2 = fbUpstream.Builder(initialSize: initialSize);
      fb2.startTable();
      fb2.addFloat32(0, 24);
      fb2.addFloat64(1, 42);
      final list2 = fb2.finish(fb2.endTable());

      printOnFailure(list1a.toString());
      printOnFailure(list2.toString());
      expect(list1a, equals(list2));
      expect(list1a, equals(list1b));

      fb1.bufPtrFree();
    });
  });
}
