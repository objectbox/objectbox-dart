import 'dart:io';
import 'dart:typed_data';

import 'package:objectbox/objectbox.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'entity2.dart';
import 'test_env.dart';

// We want to have types explicit - verifying the return types of functions.
// ignore_for_file: omit_local_variable_types

void main() {
  late TestEnv env;
  late Store store;
  late Box<TestEntity> box;

  final simpleItems = () => ['One', 'Two', 'Three', 'Four', 'Five', 'Six']
      .map((s) => TestEntity(tString: s))
      .toList();

  setUp(() {
    env = TestEnv('box');
    box = env.box;
    store = env.store;
  });

  tearDown(() => env.close());

  test('store box vending', () {
    final box1 = store.box<TestEntity>();
    expect(box1.isEmpty(), isTrue);
    int putId = env.box.put(TestEntity(tString: 'Hello'));
    expect(box1.get(putId)!.tString, equals('Hello'));

    // All accesses to a box for a given entity return the same instance.
    expect(box1, equals(store.box<TestEntity>()));
    expect(box1, equals(Box<TestEntity>(store)));
  });

  test('.put() returns a valid id', () {
    final object = TestEntity(tString: 'Hello');
    expect(object.id, isZero);
    int putId = box.put(object);
    expect(putId, greaterThan(0));
    expect(object.id, equals(putId)); // ID on the object is updated
  });

  test('.putAsync', () async {
    final box = store.box<TestEntityNonRel>();
    final a = TestEntityNonRel.filled(id: 0);
    final b = TestEntityNonRel.filled(id: 0);
    Future<int> aId = box.putAsync(a);
    expect(a.id, 0);
    Future<int> bId = box.putAsync(b);
    expect(b.id, 0);
    expect(await aId, 1);
    expect(await bId, 2);
    expect(a.id, 1);
    expect(b.id, 2);
  });

  test('.putAsync failures', () async {
    final box = store.box<TestEntity2>();
    expect(
        () => box
            .putAsync(TestEntity2(), mode: PutMode.update)
            .timeout(defaultTimeout),
        throwsA(predicate(
            (ArgumentError e) => e.toString().contains('ID is not set'))));

    expect(
        await box
            .putAsync(TestEntity2(id: 1), mode: PutMode.insert)
            .timeout(defaultTimeout),
        1);
    expect(
        () async => await box
            .putAsync(TestEntity2(id: 5), mode: PutMode.update)
            .timeout(defaultTimeout),
        throwsA(predicate((ObjectBoxException e) =>
            e.toString().contains('object with the given ID not found'))));
    expect(box.count(), 1);

    expect(
        () async => await box
            .putAsync(TestEntity2(id: 1), mode: PutMode.insert)
            .timeout(defaultTimeout),
        throwsA(predicate((ObjectBoxException e) =>
            e.toString().contains('object with the given ID already exists'))));

    {
      // check unique constraint violation behavior
      await box.putAsync(TestEntity2()..value = 42);
      final object = TestEntity2()..value = 42;
      final future = box.putAsync(object);

      try {
        await future;
      } catch (e) {
        // TODO: Mac in GitHub CI (not locally reproducible yet)...
        if (Platform.isMacOS) {
          expect(e is ObjectBoxException, isTrue);
          expect((e as ObjectBoxException).message, '');
        } else {
          expect(e is UniqueViolationException, isTrue);
          expect(e.toString(), contains('Unique constraint'));
        }
      }

      expect(object.id, isNull); // ID must remain unassigned
    }
  });

  test('.putAsync many', () async {
    final items = List.generate(
        env.short ? 100 : 1000, (i) => TestEntityNonRel.filled(id: 0));
    final futures = items.map(store.box<TestEntityNonRel>().putAsync).toList();
    print('${futures.length} futures collected');
    final ids = await Future.wait(futures);
    print('${ids.length} futures finished');
    for (int i = 0; i < items.length; i++) {
      expect(items[i].id, ids[i]);
    }
  });

  test('.putQueued', () {
    final box = store.box<TestEntityNonRel>();
    final items = List.generate(
        env.short ? 100 : 1000, (i) => TestEntityNonRel.filled(id: 0));
    final ids = items.map(box.putQueued).toList();
    for (int i = 0; i < items.length; i++) {
      expect(items[i].id, ids[i]);
    }
    store.awaitAsyncSubmitted();
    expect(box.count(), items.length);
  });

  test('.putQueued failures', () async {
    expect(
        () => store
            .box<TestEntity2>()
            .putQueued(TestEntity2(), mode: PutMode.update),
        throwsA(predicate(
            (ArgumentError e) => e.toString().contains('ID is not set'))));

    expect(
        () => store
            .box<TestEntityNonRel>()
            .putQueued(TestEntityNonRel.filled(id: 5), mode: PutMode.insert),
        throwsA(predicate((ArgumentError e) =>
            e.toString().contains('Use ID 0 (zero) to insert new entities'))));

    store.awaitAsyncCompletion();
    expect(store.box<TestEntity2>().count(), 0);
    expect(store.box<TestEntityNonRel>().count(), 0);
  });

  test('.get() returns the correct item', () {
    final int putId = box.put(TestEntity(
        tString: 'Hello',
        tStrings: ['foo', 'bar'],
        tByteList: [1, 99, -54],
        tUint8List: Uint8List.fromList([2, 50, 78]),
        tInt8List: Int8List.fromList([-16, 20, 43])));
    final TestEntity item = box.get(putId)!;
    expect(item.id, equals(putId));
    expect(item.tString, equals('Hello'));
    expect(item.tStrings, equals(['foo', 'bar']));
    expect(item.tByteList, equals([1, 99, -54]));
    expect(item.tUint8List, equals([2, 50, 78]));
    expect(item.tInt8List, equals([-16, 20, 43]));
  });

  test('.get() returns null on non-existent item', () {
    expect(box.get(1), isNull);
  });

  test('.put() and box.get() keep Unicode characters', () {
    final String text = '😄你好';
    final TestEntity inst = box.get(box.put(TestEntity(tString: text)))!;
    expect(inst.tString, equals(text));
  });

  test('.put() can update an item', () {
    final int putId1 = box.put(TestEntity(tString: 'One'));
    final int putId2 = box.put(TestEntity(tString: 'Two')..id = putId1);
    expect(putId2, equals(putId1));
    final TestEntity item = box.get(putId2)!;
    expect(item.tString, equals('Two'));
  });

  test('.put() cannot add duplicate values on a unique field', () {
    final u1 = TestEntity.unique(
        uString: 'a', uLong: 1, uInt: 1, uShort: 1, uByte: 1, uChar: 1);
    final again = TestEntity.unique(
        uString: 'a', uLong: 1, uInt: 1, uShort: 1, uByte: 1, uChar: 1);

    expect(
        () => box.putMany([u1, again]),
        throwsA(predicate((UniqueViolationException e) =>
            e.toString().contains('same property value already exists'))));
  });

  test('.getAll retrieves all items', () {
    final int id1 = box.put(TestEntity(tString: 'One'));
    final int id2 = box.put(TestEntity(tString: 'Two'));
    final int id3 = box.put(TestEntity(tString: 'Three'));
    final List<TestEntity> items = box.getAll();
    expect(items.length, equals(3));
    expect(items.where((i) => i.id == id1).single.tString, equals('One'));
    expect(items.where((i) => i.id == id2).single.tString, equals('Two'));
    expect(items.where((i) => i.id == id3).single.tString, equals('Three'));
  });

  test('.putMany inserts multiple items', () {
    final List<TestEntity> items = [
      TestEntity(tString: 'One'),
      TestEntity(tString: 'Two'),
      TestEntity(tString: 'Three')
    ];
    box.putMany(items);
    final List<TestEntity> itemsFetched = box.getAll();
    expect(itemsFetched.length, equals(items.length));
    expect(itemsFetched[0].tString, equals(items[0].tString));
    expect(itemsFetched[1].tString, equals(items[1].tString));
    expect(itemsFetched[2].tString, equals(items[2].tString));
  });

  test('.putMany returns the new item IDs', () {
    final List<TestEntity> items = [
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven'
    ].map((s) => TestEntity(tString: s)).toList();
    final List<int> ids = box.putMany(items);
    expect(ids.length, equals(items.length));
    for (var i = 0; i < items.length; ++i) {
      expect(items[i].id, equals(ids[i])); // IDs on the objects are updated
      expect(box.get(ids[i])!.tString, equals(items[i].tString));
    }
  });

  test('.getAll/getMany works on large arrays', () {
    // This would fail on 32-bit system if objectbox-c
    // obx_supports_bytes_array() wasn't respected
    final length = 10 * 1000;
    final largeString = 'A' * length;
    expect(largeString.length, length);

    box.put(TestEntity(tString: largeString));
    box.put(TestEntity(tString: largeString));

    List<TestEntity?> items = box.getAll();
    expect(items.length, 2);
    expect(items[0]!.tString, largeString);
    expect(items[1]!.tString, largeString);

    box.put(TestEntity(tString: largeString));

    items = box.getMany([1, 2]);
    expect(items.length, 2);
    expect(items[0]!.tString, largeString);
    expect(items[1]!.tString, largeString);
  });

  test('.getMany correctly handles non-existent items', () {
    final List<TestEntity> items =
        ['One', 'Two'].map((s) => TestEntity(tString: s)).toList();
    final List<int> ids = box.putMany(items);
    int otherId = 1;
    while (ids.indexWhere((id) => id == otherId) != -1) {
      ++otherId;
    }
    final List<TestEntity?> fetchedItems =
        box.getMany([ids[0], otherId, ids[1]]);
    expect(fetchedItems.length, equals(3));
    expect(fetchedItems[0]!.tString, equals('One'));
    expect(fetchedItems[1], isNull);
    expect(fetchedItems[2]!.tString, equals('Two'));
  });

  test('.getMany result list fixed vs growable', () {
    // Unfortunately there's no property telling whether the list is growable...
    final mustThrow = throwsA(predicate(
        (UnsupportedError e) => e.toString().contains('fixed-length list')));

    expect(() => box.getMany([]).add(null), mustThrow);
    box.getMany([], growableResult: true).add(null);

    expect(() => box.getMany([1]).add(null), mustThrow);
    box.getMany([1], growableResult: true).add(null);
  });

  test('all limit integers are stored correctly', () {
    final int8Min = -128;
    final int8Max = 127;
    final int16Min = -32768;
    final int16Max = 32767;
    final int32Min = -2147483648;
    final int32Max = 2147483647;
    final int64Min = -9223372036854775808;
    final int64Max = 9223372036854775807;
    final List<TestEntity> items = [
      ...[int8Min, int8Max].map((n) => TestEntity(tChar: n)).toList(),
      ...[int8Min, int8Max].map((n) => TestEntity(tByte: n)).toList(),
      ...[int16Min, int16Max].map((n) => TestEntity(tShort: n)).toList(),
      ...[int32Min, int32Max].map((n) => TestEntity(tInt: n)).toList(),
      ...[int64Min, int64Max].map((n) => TestEntity(tLong: n)).toList()
    ];
    expect('${items[8].tLong}', equals('$int64Min'));
    expect('${items[9].tLong}', equals('$int64Max'));
    final List<TestEntity?> fetchedItems = box.getMany(box.putMany(items));
    expect(fetchedItems[0]!.tChar, equals(int8Min));
    expect(fetchedItems[1]!.tChar, equals(int8Max));
    expect(fetchedItems[2]!.tByte, equals(int8Min));
    expect(fetchedItems[3]!.tByte, equals(int8Max));
    expect(fetchedItems[4]!.tShort, equals(int16Min));
    expect(fetchedItems[5]!.tShort, equals(int16Max));
    expect(fetchedItems[6]!.tInt, equals(int32Min));
    expect(fetchedItems[7]!.tInt, equals(int32Max));
    expect(fetchedItems[8]!.tLong, equals(int64Min));
    expect(fetchedItems[9]!.tLong, equals(int64Max));
  });

  test('special floating point values are handled correctly', () {
    final valsFloat = [
      double.infinity,
      1.1754943508222875e-38,
      3.4028234663852886e+38,
      -3.4028234663852886e+38,
      double.nan,
      double.negativeInfinity
    ];
    final valsDouble = [
      double.infinity,
      double.maxFinite,
      -double.maxFinite,
      double.minPositive,
      double.nan,
      double.negativeInfinity
    ];
    final List<TestEntity> items = [
      ...valsFloat.map((n) => TestEntity(tFloat: n)).toList(),
      ...valsDouble.map((n) => TestEntity(tDouble: n)).toList()
    ];
    final List<TestEntity?> fetchedItems = box.getMany(box.putMany(items));
    List<double> fetchedVals = [];
    for (var i = 0; i < fetchedItems.length; i++) {
      fetchedVals.add(i < valsFloat.length
          ? fetchedItems[i]!.tFloat!
          : fetchedItems[i]!.tDouble!);
    }

    for (var i = 0; i < fetchedVals.length; i++) {
      double expected = i < valsFloat.length
          ? valsFloat[i]
          : valsDouble[i - valsFloat.length];
      if (expected.isNaN) {
        expect(fetchedVals[i].isNaN, equals(true));
      } else {
        expect(fetchedVals[i], equals(expected));
      }
    }
  });

  test('null properties are handled correctly', () {
    final List<TestEntity> items = [
      TestEntity(),
      TestEntity(tLong: 10),
      TestEntity(tString: 'Hello')
    ];
    final List<TestEntity?> fetchedItems = box.getMany(box.putMany(items));
    expect(fetchedItems[0]!.id, isNotNull);
    expect(fetchedItems[0]!.tLong, isNull);
    expect(fetchedItems[0]!.tString, isNull);
    expect(fetchedItems[0]!.tBool, isNull);
    expect(fetchedItems[0]!.tDouble, isNull);
    expect(fetchedItems[1]!.id, isNotNull);
    expect(fetchedItems[1]!.tLong, isNotNull);
    expect(fetchedItems[1]!.tString, isNull);
    expect(fetchedItems[1]!.tBool, isNull);
    expect(fetchedItems[1]!.tDouble, isNull);
    expect(fetchedItems[2]!.id, isNotNull);
    expect(fetchedItems[2]!.tLong, isNull);
    expect(fetchedItems[2]!.tString, isNotNull);
    expect(fetchedItems[2]!.tBool, isNull);
    expect(fetchedItems[2]!.tDouble, isNull);
  });

  test('all types are handled correctly', () {
    TestEntity item = TestEntity(
        tString: 'Hello',
        tLong: 1234,
        tDouble: 3.14159,
        tBool: true,
        tByte: 123,
        tShort: -4567,
        tChar: 'x'.codeUnitAt(0),
        tInt: 789012,
        tFloat: -2.71);
    final fetchedItem = box.get(box.put(item))!;
    expect(fetchedItem.tString, equals('Hello'));
    expect(fetchedItem.tLong, equals(1234));
    expect((fetchedItem.tDouble! - 3.14159).abs(), lessThan(0.000000000001));
    expect(fetchedItem.tBool, equals(true));
    expect(fetchedItem.tByte, equals(123));
    expect(fetchedItem.tShort, equals(-4567));
    expect(fetchedItem.tChar, equals('x'.codeUnitAt(0)));
    expect(fetchedItem.tInt, equals(789012));
    expect((fetchedItem.tFloat! - (-2.71)).abs(), lessThan(0.0000001));
  });

  test('.count() works', () {
    expect(box.count(), equals(0));
    box.putMany(simpleItems());
    expect(box.count(), equals(6));
    expect(box.count(limit: 2), equals(2));
    expect(box.count(limit: 10), equals(6));
    //add more
    box.putMany(simpleItems());
    expect(box.count(), equals(12));
  });

  test('.isEmpty() works', () {
    bool isEmpty = box.isEmpty();
    expect(isEmpty, equals(true));
    //check complementary
    box.putMany(simpleItems());
    isEmpty = box.isEmpty();
    expect(isEmpty, equals(false));
  });

  test('.contains() works', () {
    int id = box.put(TestEntity(tString: 'container'));
    bool contains = box.contains(id);
    expect(contains, equals(true));
    //check complementary
    box.remove(id);
    contains = box.contains(id);
    expect(contains, equals(false));
  });

  test('.containsMany() works', () {
    List<int> ids = box.putMany(simpleItems());
    bool contains = box.containsMany(ids);
    expect(contains, equals(true));
    //check with one missing id
    box.remove(ids[1]);
    contains = box.containsMany(ids);
    expect(contains, equals(false));
    //check complementary
    box.removeAll();
    contains = box.containsMany(ids);
    expect(contains, equals(false));
  });

  test('.remove(id) works', () {
    final List<int> ids = box.putMany(simpleItems());
    //check if single id remove works
    expect(box.remove(ids[1]), equals(true));
    expect(box.count(), equals(5));
    //check what happens if id already deleted -> throws OBJBOXEX 404
    bool success = box.remove(ids[1]);
    expect(box.count(), equals(5));
    expect(success, equals(false));
  });

  test('.remove() returns false on non-existent item', () {
    box.removeAll();
    expect(box.remove(1), isFalse);
  });

  test('.removeMany(ids) works', () {
    final List<int> ids = box.putMany(simpleItems());
    expect(box.count(), equals(6));
    box.removeMany(ids.sublist(4));
    expect(box.count(), equals(4));
    //again test what happens if ids already deleted
    box.removeMany(ids.sublist(4));
    expect(box.count(), equals(4));

    // verify the right items were removed
    final List<int?> remainingIds = box.getAll().map((o) => o.id).toList();
    expect(remainingIds, unorderedEquals(ids.sublist(0, 4)));
  });

  test('.removeAll() works', () {
    box.putMany(simpleItems());
    int removed = box.removeAll();
    expect(removed, equals(6));
    expect(box.count(), equals(0));
    //try with different number of items
    List<TestEntity> items =
        ['one', 'two', 'three'].map((s) => TestEntity(tString: s)).toList();
    box.putMany(items);
    removed = box.removeAll();
    expect(removed, equals(3));
  });

  test('simple write in txn works', () {
    int count;
    void fn() {
      box.putMany(simpleItems());
    }

    store.runInTransaction(TxMode.write, fn);
    count = box.count();
    expect(count, equals(6));
  });

  test('failing transactions', () {
    expect(
        () => store.runInTransaction(TxMode.write, () {
              box.putMany(simpleItems());
              // note: we're throwing conditionally (but always true) so that
              // the return type is not [Never]. See [Transaction.execute()]
              // testing for the return type to be a [Future]. [Never] is a
              // base class to everything, so a [Future] is also a [Never].
              if (box == env.box) throw 'test-exception';
              return 1;
            }),
        throwsA(predicate((String e) => e == 'test-exception')));
    expect(box.count(), equals(0));
  });

  test('recursive write in write transaction', () {
    store.runInTransaction(TxMode.write, () {
      box.putMany(simpleItems());
      store.runInTransaction(TxMode.write, () {
        box.putMany(simpleItems());
      });
    });
    expect(box.count(), equals(12));
  });

  test('recursive read in write transaction', () {
    int count = store.runInTransaction(TxMode.write, () {
      box.putMany(simpleItems());
      return store.runInTransaction(TxMode.read, box.count);
    });
    expect(count, equals(6));
  });

  test('recursive write in read -> fails during creation', () {
    expect(
        () => store.runInTransaction(TxMode.read, () {
              box.count();
              return store.runInTransaction(
                  TxMode.write, () => box.putMany(simpleItems()));
            }),
        throwsA(predicate((StateError e) =>
            e.toString().contains('failed to create transaction'))));
  });

  test('failing in recursive txn', () {
    store.runInTransaction(TxMode.write, () {
      //should throw code10001 -> valid until fix
      List<int> ids =
          store.runInTransaction(TxMode.read, () => box.putMany(simpleItems()));
      expect(ids.length, equals(6));
    });
  });

  test('assignable IDs', () {
    // RelatedEntityA.id IS NOT assignable so this must fail
    final box = env.store.box<RelatedEntityA>();
    expect(
        () => box.put(RelatedEntityA()..id = 1),
        throwsA(predicate((ArgumentError e) => e
            .toString()
            .contains('ID is higher or equal to internal ID sequence'))));
    expect(box.isEmpty(), isTrue);

    // TestEntity2.id IS assignable so this must pass
    final box2 = store.box<TestEntity2>();
    final object = TestEntity2(id: 2);
    box2.put(object);
    expect(object.id, 2);
    final read = box2.get(2);
    expect(read, isNotNull);
  });

  test('DateTime field', () {
    final object = TestEntity();
    object.tDate = DateTime.now();
    object.tDateNano = DateTime.now();
    final objectUtc = TestEntity();
    objectUtc.tDate = object.tDate!.toUtc();
    objectUtc.tDateNano = object.tDateNano!.toUtc();

    {
      // first, test some assumptions the code generator makes
      final millis = object.tDate!.millisecondsSinceEpoch;
      final time1 = DateTime.fromMillisecondsSinceEpoch(millis);
      expect(object.tDate!.difference(time1).inMilliseconds, equals(0));

      final nanos = object.tDateNano!.microsecondsSinceEpoch * 1000;
      final time2 = DateTime.fromMicrosecondsSinceEpoch((nanos / 1000).round());
      expect(object.tDateNano!.difference(time2).inMicroseconds, equals(0));
    }

    box.putMany([object, objectUtc, TestEntity()]);
    final items = box.getAll();

    // DateTime has microsecond precision in dart but is stored in ObjectBox
    // with millisecond precision so allow a sub-millisecond difference.
    expect(items[0].tDate!.difference(object.tDate!).inMilliseconds, 0);
    expect(items[1].tDate!.difference(object.tDate!).inMilliseconds, 0);
    // DateTime is always restored with local time zone in ObjectBox.
    expect(items[0].tDate!.isUtc, false);
    expect(items[1].tDate!.isUtc, false);

    expect(items[0].tDateNano, object.tDateNano);
    expect(items[1].tDateNano, object.tDateNano);
    expect(items[2].tDate, isNull);
    expect(items[2].tDateNano, isNull);
  });

  test('large-data', () {
    final numBytes = 1024 * 1024;
    final str = List.generate(numBytes, (i) => 'A').join();
    expect(str.length, numBytes);
    box.put(TestEntity(tString: str));
    expect(box.get(1)!.tString, str);
    env.store.close();
  });

  test(
      'TX multiple cursors',
      () => store.runInTransaction(TxMode.write, () {
            final box2 = store.box<TestEntity2>();
            box.put(TestEntity());
            box2.put(TestEntity2());
            box.get(1);
            box2.get(1);
          }));

  test('throwing in converters', () {
    late Box<ThrowingInConverters> box = store.box();

    box.put(ThrowingInConverters());
    box.put(ThrowingInConverters(throwOnGet: true));
    expect(() => box.put(ThrowingInConverters(throwOnPut: true)),
        ThrowingInConverters.throwsIn('Getter'));

    expect(
        () => box.putMany([
              ThrowingInConverters(),
              ThrowingInConverters(),
              ThrowingInConverters(throwOnPut: true)
            ]),
        ThrowingInConverters.throwsIn('Getter'));

    expect(box.count(), 2);

    box.get(1);
    expect(() => box.get(2), ThrowingInConverters.throwsIn('Setter'));
    expect(() => box.getAll(), ThrowingInConverters.throwsIn('Setter'));
  });
}
