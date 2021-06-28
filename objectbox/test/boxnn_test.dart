import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:objectbox/objectbox.dart';
import 'entity.dart';
import 'test_env.dart';

// Tests non-nullable fields
void main() {
  late TestEnv env;
  late Box<TestEntityNotNull> box;

  setUp(() {
    env = TestEnv('box-nn');
    box = env.store.box();
  });

  tearDown(() => env.close());

  test('CRUD', () {
    final objects = [
      TestEntityNotNull(),
      TestEntityNotNull(),
      TestEntityNotNull(
        tStrings: ['list', 'items'],
        tByteList: [14, -50, 44],
        tInt8List: Int8List.fromList([1, 8, -17]),
        tUint8List: Uint8List.fromList([2, 199]),
      )
    ];
    box.put(objects[0]);
    box.putMany(objects.sublist(1));
    expect(box.count(), 3);

    for (var i = 0; i < 3; i++) {
      final object = objects[i];
      final fetchedItem = box.get(i + 1)!;
      expect(fetchedItem.tString, object.tString);
      expect(fetchedItem.tLong, object.tLong);
      expect(fetchedItem.tDouble, object.tDouble);
      expect(fetchedItem.tBool, object.tBool);
      expect(fetchedItem.tStrings, object.tStrings);
      expect(fetchedItem.tByteList, object.tByteList);
      expect(fetchedItem.tInt8List, object.tInt8List);
      expect(fetchedItem.tUint8List, object.tUint8List);
    }
  });

  test('.putAsync', () async {
    expect(await box.putAsync(TestEntityNotNull()), 1);
  });

  test('assignable IDs', () {
    final object = TestEntityNotNull(id: 2);
    box.put(object);
    expect(object.id, 2);
    final read = box.get(2);
    expect(read, isNotNull);
  });

  // basically the same as in box_test.dart
  test('DateTime field', () {
    final object = TestEntityNotNull();
    object.tDate = DateTime.now();
    object.tDateNano = DateTime.now();

    {
      // first, test some assumptions the code generator makes
      final millis = object.tDate.millisecondsSinceEpoch;
      final time1 = DateTime.fromMillisecondsSinceEpoch(millis);
      expect(object.tDate.difference(time1).inMilliseconds, equals(0));

      final nanos = object.tDateNano.microsecondsSinceEpoch * 1000;
      final time2 = DateTime.fromMicrosecondsSinceEpoch((nanos / 1000).round());
      expect(object.tDateNano.difference(time2).inMicroseconds, equals(0));
    }

    box.put(object);
    final items = box.getAll();

    // DateTime has microsecond precision in dart but is stored in ObjectBox
    // with millisecond precision so allow a sub-millisecond difference.
    expect(items[0].tDate.difference(object.tDate).inMilliseconds, 0);

    expect(items[0].tDateNano, object.tDateNano);
  });
}
