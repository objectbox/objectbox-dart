// ignore_for_file: deprecated_member_use

import 'dart:io';

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

  setUp(() {
    env = TestEnv('box');
    box = env.box;
    store = env.store;
  });

  tearDown(() => env.closeAndDelete());

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

    object.tString = "Hello again";
    int updateId = box.put(object, mode: PutMode.update);
    expect(updateId, greaterThan(0));
    expect(object.id, updateId);
  });

  test('.put() update mode failures', () {
    final box = store.box<TestEntity2>();
    expect(
        () => box.put(TestEntity2(id: 0), mode: PutMode.update),
        throwsA(predicate((ArgumentError e) => e
            .toString()
            .contains('ID is not set (zero) for object to update'))));

    expect(
        () => box.put(TestEntity2(id: 5), mode: PutMode.update),
        throwsA(predicate((StorageException e) =>
            e.message.contains("object put failed: ID is higher or equal"))));
  });

  test('use after close throws', () {
    // Obtain box reference before store is closed.
    final box = env.box;
    final boxNonRel = env.store.box<TestEntityNonRel>();
    env.closeAndDelete();

    expectStoreClosed(Function function) {
      expect(function,
          throwsA(predicate((StateError e) => e.message == "Store is closed")));
    }

    // Use entity with relations to test transaction code path in put.
    expectStoreClosed(() => box.put(TestEntity(tString: 'Never put')));
    // Use entity without relations to test non-transaction code path in put.
    expectStoreClosed(
        () => boxNonRel.put(TestEntityNonRel.filled(tString: 'Never put')));

    expectStoreClosed(() =>
        boxNonRel.putQueued(TestEntityNonRel.filled(tString: 'Never put')));

    expectStoreClosed(() => box.count());
    expectStoreClosed(() => box.isEmpty());
    expectStoreClosed(() => box.contains(1));
    expectStoreClosed(() => box.containsMany([1, 2]));
    expectStoreClosed(() => box.remove(1));
    expectStoreClosed(() => box.removeMany([1, 2]));
    expectStoreClosed(() => box.removeAll());
  });

  test('.putAsync', () async {
    // Supports relations, so add some.
    final a = TestEntity(tString: 'Hello A');
    a.relA.target = RelatedEntityA(tInt: 1);
    final b = TestEntity(tString: 'Hello B');
    b.relManyA.add(RelatedEntityA(tInt: 2));
    // Launch two async puts.
    Future<int> putA = box.putAsync(a);
    Future<int> putB = box.putAsync(b);
    // Async put does not guarantee order, so can't expect ID values.
    final aId = await putA;
    final bId = await putB;
    expect(aId, greaterThan(0));
    expect(bId, greaterThan(0));
    // Check new IDs are *not* set on given objects.
    expect(a.id, 0);
    expect(b.id, 0);
    expect(a.relA.target!.id, isNull);
    expect(b.relManyA[0].id, isNull);
    // Check objects and relations were saved.
    expect(box.get(aId)!.relA.target!.tInt, 1);
    expect(box.get(bId)!.relManyA[0].tInt, 2);
  });

  test('.putAndGetAsync', () async {
    // Supports relations, so add some.
    final a = TestEntity(tString: 'Hello A');
    a.relA.target = RelatedEntityA(tInt: 1);
    final b = TestEntity(tString: 'Hello B');
    b.relManyA.add(RelatedEntityA(tInt: 2));
    // Launch two async puts.
    Future<TestEntity> putA = box.putAndGetAsync(a);
    Future<TestEntity> putB = box.putAndGetAsync(b);
    // Async put does not guarantee order, so can't expect ID values.
    final aStored = await putA;
    final bStored = await putB;
    expect(aStored.id, greaterThan(0));
    expect(bStored.id, greaterThan(0));
    // Check new IDs are *not* set on given objects.
    expect(a.id, 0);
    expect(b.id, 0);
    expect(a.relA.target!.id, isNull);
    expect(b.relManyA[0].id, isNull);
    // Check new IDs are set on returned objects.
    expect(aStored.id, greaterThan(0));
    expect(bStored.id, greaterThan(0));
    expect(aStored.relA.target!.id, greaterThan(0));
    expect(bStored.relManyA[0].id, greaterThan(0));
    // Check objects and relations were saved.
    expect(box.get(aStored.id)!.relA.target!.tInt, 1);
    expect(box.get(bStored.id)!.relManyA[0].tInt, 2);
  });

  test('.putAsync failures', () async {
    final box = store.box<TestEntity2>();
    await expectLater(
        () async =>
            await box.putAsync(TestEntity2(id: 0), mode: PutMode.update),
        throwsA(predicate((ArgumentError e) => e
            .toString()
            .contains('ID is not set (zero) for object to update'))));

    await expectLater(
        await box.putAsync(TestEntity2(id: 1), mode: PutMode.insert), 1);

    // Note: regular put API used by putAsync returns default error,
    // unlike queue API which has special errors for ID not found or not new.
    await expectLater(
        () async =>
            await box.putAsync(TestEntity2(id: 5), mode: PutMode.update),
        throwsA(predicate((StorageException e) =>
            e.message.contains("object put failed: ID is higher or equal"))));

    expect(box.count(), 1);

    await expectLater(
        () async =>
            await box.putAsync(TestEntity2(id: 1), mode: PutMode.insert),
        throwsA(predicate(
            (ObjectBoxException e) => e.message == 'object put failed')));

    {
      // check unique constraint violation behavior
      await box.putAsync(TestEntity2(id: 0)..value = 42);
      final object = TestEntity2(id: 0)..value = 42;
      final future = box.putAsync(object);

      await expectLater(
          () async => await future,
          throwsA(predicate((UniqueViolationException e) =>
              e.message.contains("Unique constraint"))));

      expect(object.id, 0); // ID must remain unassigned
    }
  });

  test('.putQueuedAwaitResult', () async {
    final box = store.box<TestEntityNonRel>();
    final a = TestEntityNonRel.filled(id: 0);
    final b = TestEntityNonRel.filled(id: 0);
    Future<int> aId = box.putQueuedAwaitResult(a);
    expect(a.id, 0);
    Future<int> bId = box.putQueuedAwaitResult(b);
    expect(b.id, 0);
    expect(await aId, 1);
    expect(await bId, 2);
    expect(a.id, 1);
    expect(b.id, 2);
  });

  test('.putQueuedAwaitResult failures', () async {
    final box = store.box<TestEntity2>();
    // Note: not using `await expectLater` as putAsync has an
    // internal queue that guarantees order.
    expect(
        () => box
            .putQueuedAwaitResult(TestEntity2(), mode: PutMode.update)
            .timeout(defaultTimeout),
        throwsA(predicate((ArgumentError e) =>
            e.message ==
            "putAsync failed: Putting object failed because ID is not set (zero) for object to update (OBX_ERROR code 10002)")));

    expect(
        await box
            .putQueuedAwaitResult(TestEntity2(id: 1), mode: PutMode.insert)
            .timeout(defaultTimeout),
        1);
    expect(
        () async => await box
            .putQueuedAwaitResult(TestEntity2(id: 5), mode: PutMode.update)
            .timeout(defaultTimeout),
        throwsA(predicate((StorageException e) =>
            e.message.contains("putAsync failed: ID is higher or equal"))));
    expect(box.count(), 1);

    expect(
        () async => await box
            .putQueuedAwaitResult(TestEntity2(id: 1), mode: PutMode.insert)
            .timeout(defaultTimeout),
        throwsA(predicate((ObjectBoxException e) =>
            e.toString().contains('object with the given ID already exists'))));

    {
      // check unique constraint violation behavior
      await box.putQueuedAwaitResult(TestEntity2()..value = 42);
      final object = TestEntity2()..value = 42;
      final future = box.putQueuedAwaitResult(object);

      if (Platform.isMacOS && !atLeastDart('3.1.0')) {
        // Before Dart 3.1 an incorrect exception is thrown on macOS.
        expect(
            () async => await future,
            throwsA(
                predicate((e) => e is ObjectBoxException && e.message == '')));
      } else {
        expect(
            () async => await future,
            throwsA(predicate((e) =>
                e is UniqueViolationException &&
                e.message.contains('Unique constraint'))));
      }

      expect(object.id, isNull); // ID must remain unassigned
    }
  });

  test('.putQueuedWithFuture many', () async {
    final items = List.generate(
        env.short ? 100 : 1000, (i) => TestEntityNonRel.filled(id: 0));
    final futures =
        items.map(store.box<TestEntityNonRel>().putQueuedAwaitResult).toList();
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
    store.awaitQueueSubmitted();
    expect(box.count(), items.length);
  });

  test('.putQueued failures', () async {
    expect(
        () => store
            .box<TestEntity2>()
            .putQueued(TestEntity2(), mode: PutMode.update),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, "message", contains("ID is not set"))));

    expect(
        () => store
            .box<TestEntityNonRel>()
            .putQueued(TestEntityNonRel.filled(id: 5), mode: PutMode.insert),
        throwsA(isA<ArgumentError>().having((e) => e.message, "message",
            contains("Use ID 0 (zero) to insert new objects"))));

    store.awaitQueueCompletion();
    expect(store.box<TestEntity2>().count(), 0);
    expect(store.box<TestEntityNonRel>().count(), 0);
  });

  test('.get() returns the correct item', () async {
    final testEntities = simpleItems();
    box.putMany(testEntities);

    final int putId = testEntities[2].id;

    assertItem(TestEntity? item) {
      expect(item, isNotNull);
      expect(item!.id, equals(putId));
      expect(item.tString, equals('Three'));
    }

    assertItem(box.get(putId));
    assertItem(await box.getAsync(putId));
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

  test('.put() replaces duplicate values on a unique replace field on insert',
      () {
    // insert without conflict
    box.putMany([
      TestEntity.uniqueReplace(replaceLong: 1, tString: 'original-1'),
      TestEntity.uniqueReplace(replaceLong: 2, tString: 'original-2')
    ]);
    expect(box.count(), equals(2));

    // insert with conflict, deletes ID 1 and inserts ID 3
    box.put(TestEntity.uniqueReplace(replaceLong: 1, tString: 'replacement-1'));
    expect(box.count(), equals(2));
    final replaced = box.get(3)!;
    expect(replaced.replaceLong, equals(1));
    expect(replaced.tString, equals('replacement-1'));
  });

  test('.put() replaces duplicate values on a unique replace field on update',
      () {
    // update without conflict
    var first = TestEntity.uniqueReplace(replaceLong: 1, tString: 'first');
    box.put(first);
    first.replaceLong = 2;
    box.put(first);
    expect(box.count(), equals(1));
    final updated = box.get(1)!;
    expect(updated.replaceLong, equals(2));
    expect(updated.tString, 'first');

    // update with conflict, deletes ID 2 and keeps ID 1
    box.put(TestEntity.uniqueReplace(replaceLong: 1, tString: 'second'));
    first.replaceLong = 1;
    box.put(first);
    expect(box.count(), equals(1));
    final updated2 = box.get(1)!;
    expect(updated2.replaceLong, equals(1));
    expect(updated2.tString, 'first');
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

  assertPutManyItems(List<TestEntity> items, {required bool expectIdSet}) {
    // Check IDs on objects in relations.
    final relIdMatcher = expectIdSet ? greaterThan(0) : isNull;
    expect(items[0].relA.target!.id, relIdMatcher);
    expect(items[1].relB.target!.id, relIdMatcher);
    expect(items[2].relManyA[0].id, relIdMatcher);

    // Check objects and relations were inserted.
    final List<TestEntity> itemsFetched = box.getAll();
    expect(itemsFetched.length, 3);
    expect(itemsFetched[0].tString, 'One');
    expect(itemsFetched[0].relA.target!.tInt, 1);
    expect(itemsFetched[1].tString, 'Two');
    expect(itemsFetched[1].relB.target!.tString, "2");
    expect(itemsFetched[2].tString, 'Three');
    expect(itemsFetched[2].relManyA[0].tInt, 3);
  }

  test('.putMany inserts multiple items', () {
    final List<TestEntity> items = [
      TestEntity(tString: 'One')..relA.target = RelatedEntityA(tInt: 1),
      TestEntity(tString: 'Two')..relB.target = RelatedEntityB(tString: "2"),
      TestEntity(tString: 'Three')..relManyA.add(RelatedEntityA(tInt: 3))
    ];
    final ids = box.putMany(items);

    // Check returned IDs are valid and set on given objects.
    for (int i = 0; i < ids.length; i++) {
      var id = ids[i];
      expect(id, greaterThan(0));
      expect(items[i].id, id);
    }

    assertPutManyItems(items, expectIdSet: true);
  });

  test('.putManyAsync inserts multiple items', () async {
    // Need to define inside test closure to avoid Dart over-capturing store
    // and box which can't be sent to worker isolate.
    final List<TestEntity> items = [
      TestEntity(tString: 'One')..relA.target = RelatedEntityA(tInt: 1),
      TestEntity(tString: 'Two')..relB.target = RelatedEntityB(tString: "2"),
      TestEntity(tString: 'Three')..relManyA.add(RelatedEntityA(tInt: 3))
    ];
    final ids = await box.putManyAsync(items);

    // Check returned IDs are valid and *not* set on given objects.
    for (int i = 0; i < ids.length; i++) {
      var id = ids[i];
      expect(id, greaterThan(0));
      expect(items[i].id, 0);
    }

    assertPutManyItems(items, expectIdSet: false);
  });

  test('.putAndGetManyAsync inserts multiple items', () async {
    // Need to define inside test closure to avoid Dart over-capturing store
    // and box which can't be sent to worker isolate.
    final List<TestEntity> items = [
      TestEntity(tString: 'One')..relA.target = RelatedEntityA(tInt: 1),
      TestEntity(tString: 'Two')..relB.target = RelatedEntityB(tString: "2"),
      TestEntity(tString: 'Three')..relManyA.add(RelatedEntityA(tInt: 3))
    ];
    final storedItems = await box.putAndGetManyAsync(items);

    // Check returned IDs are *not* set on given objects.
    for (final item in items) {
      expect(item.id, 0);
    }

    // Check IDs are set on returned objects.
    for (final item in storedItems) {
      expect(item.id, greaterThan(0));
    }

    assertPutManyItems(storedItems, expectIdSet: true);
  });

  test('.getAll/getMany works on large arrays', () async {
    // This would fail on 32-bit system if objectbox-c
    // obx_supports_bytes_array() wasn't respected
    final length = 10 * 1000;
    final largeString = 'A' * length;
    expect(largeString.length, length);

    box.put(TestEntity(tString: largeString));
    box.put(TestEntity(tString: largeString));

    assertGetAll(List<TestEntity> items) {
      expect(items.length, 2);
      expect(items[0].tString, largeString);
      expect(items[1].tString, largeString);
    }

    assertGetAll(box.getAll());
    assertGetAll(await box.getAllAsync());

    box.put(TestEntity(tString: largeString));

    assertGetMany(List<TestEntity?> items) {
      expect(items.length, 2);
      expect(items[0]!.tString, largeString);
      expect(items[1]!.tString, largeString);
    }

    assertGetMany(box.getMany([1, 2]));
    assertGetMany(await box.getManyAsync([1, 2]));
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
    final uint16Max = 65535;
    final int32Min = -2147483648;
    final int32Max = 2147483647;
    final int64Min = -9223372036854775808;
    final int64Max = 9223372036854775807;
    final List<TestEntity> items = [
      ...[int8Min, int8Max].map((n) => TestEntity(tByte: n)),
      ...[int16Min, int16Max].map((n) => TestEntity(tShort: n)),
      ...[0, uint16Max].map((n) => TestEntity(tChar: n)),
      ...[int32Min, int32Max].map((n) => TestEntity(tInt: n)),
      ...[int64Min, int64Max].map((n) => TestEntity(tLong: n))
    ];
    expect('${items[8].tLong}', equals('$int64Min'));
    expect('${items[9].tLong}', equals('$int64Max'));
    final List<TestEntity?> fetchedItems = box.getMany(box.putMany(items));
    expect(fetchedItems[0]!.tByte, equals(int8Min));
    expect(fetchedItems[1]!.tByte, equals(int8Max));
    expect(fetchedItems[2]!.tShort, equals(int16Min));
    expect(fetchedItems[3]!.tShort, equals(int16Max));
    expect(fetchedItems[4]!.tChar, equals(0));
    expect(fetchedItems[5]!.tChar, equals(uint16Max));
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
      ...valsFloat.map((n) => TestEntity(tFloat: n)),
      ...valsDouble.map((n) => TestEntity(tDouble: n))
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

  test('null simple types are handled correctly', () {
    final TestEntity item = box.get(box.put(TestEntity()))!;
    expect(item.id, isNotNull);
    expect(item.tString, isNull);
    expect(item.tLong, isNull);
    expect(item.tDouble, isNull);
    expect(item.tBool, isNull);
    expect(item.tDate, isNull);
    expect(item.tDateNano, isNull);
    expect(item.tByte, isNull);
    expect(item.tShort, isNull);
    expect(item.tChar, isNull);
    expect(item.tInt, isNull);
    expect(item.tFloat, isNull);
  });

  test('null vector types are handled correctly', () {
    final TestEntity item = box.get(box.put(TestEntity()))!;
    expect(item.id, isNotNull);
    expect(item.tStrings, isNull);

    final vectorBox = store.box<TestEntityScalarVectors>();
    final item2 = vectorBox.get(vectorBox.put(TestEntityScalarVectors()))!;
    expect(item2.id, isNotNull);
    expect(item2.tByteList, isNull);
    expect(item2.tInt8List, isNull);
    expect(item2.tUint8List, isNull);

    expect(item2.tCharList, isNull);

    expect(item2.tShortList, isNull);
    expect(item2.tInt16List, isNull);
    expect(item2.tUint16List, isNull);

    expect(item2.tIntList, isNull);
    expect(item2.tInt32List, isNull);
    expect(item2.tUint32List, isNull);

    expect(item2.tLongList, isNull);
    expect(item2.tInt64List, isNull);
    expect(item2.tUint64List, isNull);

    expect(item2.tFloatList, isNull);
    expect(item2.tFloat32List, isNull);
    expect(item2.tDoubleList, isNull);
    expect(item2.tFloat64List, isNull);
  });

  test('simple types are handled correctly', () {
    TestEntity item = TestEntity(
        tString: 'Hello',
        tLong: 1234,
        tDouble: 3.14159,
        tBool: true,
        tByte: 123,
        tShort: -4567,
        tChar: 'Ā'.codeUnitAt(0),
        // U+0100
        tInt: 789012,
        tFloat: -2.71);
    final fetchedItem = box.get(box.put(item))!;
    expect(fetchedItem.tString, equals('Hello'));
    expect(fetchedItem.tLong, equals(1234));
    expect((fetchedItem.tDouble! - 3.14159).abs(), lessThan(0.000000000001));
    expect(fetchedItem.tBool, equals(true));
    expect(fetchedItem.tByte, equals(123));
    expect(fetchedItem.tShort, equals(-4567));
    expect(fetchedItem.tChar, equals('Ā'.codeUnitAt(0)));
    expect(fetchedItem.tInt, equals(789012));
    expect((fetchedItem.tFloat! - (-2.71)).abs(), lessThan(0.0000001));
  });

  test('vector types are handled correctly', () {
    // String vector
    final id = box.put(TestEntity(tStrings: ['foo', 'bar']));

    final item = box.get(id)!;
    expect(item.id, id);
    expect(item.tStrings, ['foo', 'bar']);

    // Integer and floating point vectors
    final vectorBox = store.box<TestEntityScalarVectors>();
    final id2 = vectorBox.put(TestEntityScalarVectors.withData(1));

    final item2 = vectorBox.get(id2)!;
    expect(item2.id, id2);

    expect(item2.tByteList, [-11, 11]);
    expect(item2.tInt8List, [-11, 11]);
    expect(item2.tUint8List, [11, 12]);

    expect(item2.tCharList, [1001, 1002]);

    expect(item2.tShortList, [-1001, 1001]);
    expect(item2.tInt16List, [-1001, 1001]);
    expect(item2.tUint16List, [1001, 1002]);

    expect(item2.tIntList, [-100001, 100001]);
    expect(item2.tInt32List, [-100001, 100001]);
    expect(item2.tUint32List, [100001, 100002]);

    expect(item2.tLongList, [-10000000001, 10000000001]);
    expect(item2.tInt64List, [-10000000001, 10000000001]);
    expect(item2.tUint64List, [10000000001, 10000000002]);

    expect(item2.tFloatList![0], closeTo(-20.1, 0.00001));
    expect(item2.tFloatList![1], closeTo(20.1, 0.00001));
    expect(item2.tFloat32List![0], closeTo(-20.1, 0.00001));
    expect(item2.tFloat32List![1], closeTo(20.1, 0.00001));

    expect(item2.tDoubleList, [-2000.00001, 2000.00001]);
    expect(item2.tFloat64List, [-2000.00001, 2000.00001]);
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
    expect(box.remove(id), equals(true));
    contains = box.contains(id);
    expect(contains, equals(false));
  });

  test('.containsMany() works', () {
    List<int> ids = box.putMany(simpleItems());
    bool contains = box.containsMany(ids);
    expect(contains, equals(true));
    //check with one missing id
    expect(box.remove(ids[1]), isTrue);
    contains = box.containsMany(ids);
    expect(contains, equals(false));
    //check complementary
    box.removeAll();
    contains = box.containsMany(ids);
    expect(contains, equals(false));
  });

  test('.remove(id) works', () async {
    final List<int> ids = box.putMany(simpleItems());
    // Removes existing object
    expect(box.remove(ids[1]), isTrue);
    expect(box.count(), equals(5));

    expect(await box.removeAsync(ids[2]), isTrue);
    expect(box.count(), equals(4));

    // Fails to remove a not existing object
    expect(box.remove(ids[1]), isFalse);
    expect(await box.removeAsync(ids[1]), isFalse);
    expect(box.count(), equals(4));
  });

  test('.removeMany(ids) works', () async {
    final List<int> ids = box.putMany(simpleItems());
    // Removes existing objects and returns count.
    var fiveAndSix = ids.sublist(4);
    expect(box.removeMany(fiveAndSix), 2);
    expect(box.count(), equals(4));

    expect(await box.removeManyAsync(ids.sublist(0, 2) /* 1 + 2 */), 2);
    expect(box.count(), equals(2));

    // Does nothing if objects do not exist, returns count of 0.
    expect(box.removeMany(fiveAndSix), 0);
    expect(await box.removeManyAsync(fiveAndSix), 0);
    expect(box.count(), equals(2));

    // Verify the correct items were removed.
    final List<int?> remainingIds = box.getAll().map((o) => o.id).toList();
    expect(remainingIds, unorderedEquals(ids.sublist(2, 4) /* 2 + 3 */));
  });

  test('.removeAll() works', () {
    box.putMany(simpleItems());
    expect(box.removeAll(), 6);
    expect(box.count(), 0);
  });

  test('.removeAllAsync() works', () async {
    box.putMany(simpleItems());
    expect(await box.removeAllAsync(), 6);
    expect(box.count(), equals(0));
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

  test('simple write in txn works - async', () async {
    int count;
    void callback(Store store, List<TestEntity> param) {
      store.box<TestEntity>().putMany(param);
    }

    await store.runInTransactionAsync(TxMode.write, callback, simpleItems());
    count = box.count();
    expect(count, equals(6));
  });

  test('async txn - send and receive relations', () async {
    final testBox = store.box<TestEntity>();
    testBox.putMany(simpleItems());
    // Get objects from Box so relations are attached.
    final testObjects = testBox.getAll();

    List<TestEntity> callback(Store store, List<TestEntity> receivedObjects) {
      // Check ToOne and ToMany classes can access store.
      for (var object in receivedObjects) {
        object.relA.target;
        object.relManyA.length;
      }

      // Return objects with attached relations to main isolate.
      return store.box<TestEntity>().getAll();
    }

    // Send objects with attached relations to worker isolate.
    var isolateResponse =
        await store.runInTransactionAsync(TxMode.read, callback, testObjects);
    expect(isolateResponse.length, equals(6));
    // Check ToOne and ToMany classes can access store.
    for (var object in isolateResponse) {
      object.relA.target;
      object.relManyA.length;
    }
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

  test('failing transactions - async', () async {
    expect(
        () async => await store.runInTransactionAsync(TxMode.write,
                (Store store, List<TestEntity> param) {
              store.box<TestEntity>().putMany(param);
              // Note: we're throwing conditionally (but always true) so that
              // the return type is not [Never]. See [Transaction.execute()]
              // testing for the return type to be a [Future]. [Never] is a
              // base class to everything, so a [Future] is also a [Never].
              // Also not creating exception instance inline to avoid Dart
              // over-capturing the Store and trying to send it back to the
              // main isolate [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
              testThrowException();
              return 1;
            }, simpleItems()),
        throwsA('test-exception'));
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

  test('recursive write in write transaction - async', () async {
    await store.runInTransactionAsync(TxMode.write,
        (Store store, List<TestEntity> param) {
      final box = store.box<TestEntity>();
      box.putMany(param);
      store.runInTransaction(TxMode.write, () {
        // Re-set IDs to re-insert.
        for (var element in param) {
          element.id = 0;
        }
        box.putMany(param);
      });
    }, simpleItems());
    expect(box.count(), equals(12));
  });

  test('recursive read in write transaction', () {
    int count = store.runInTransaction(TxMode.write, () {
      box.putMany(simpleItems());
      return store.runInTransaction(TxMode.read, box.count);
    });
    expect(count, equals(6));
  });

  test('recursive read in write transaction - async', () async {
    int count = await store.runInTransactionAsync(TxMode.write,
        (Store store, List<TestEntity> param) {
      final box = store.box<TestEntity>();
      box.putMany(param);
      return store.runInTransaction(TxMode.read, box.count);
    }, simpleItems());
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

  test('recursive write in async read -> fails during creation', () {
    expect(
        () => store.runInTransactionAsync(TxMode.read,
                (Store store, List<TestEntity> param) {
              final box = store.box<TestEntity>();
              box.count();
              return store.runInTransaction(
                  TxMode.write, () => box.putMany(param));
            }, simpleItems()),
        throwsA(predicate((StateError e) => e.toString().contains(
            'Bad state: failed to create transaction: Cannot start a write transaction inside a read only transaction (OBX_ERROR code 10001)'))));
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

  // https://github.com/objectbox/objectbox-dart/issues/550
  test("get with nested get reads all properties", () {
    final box = env.store.box<TestEntityReadDuringRead>();
    final id =
        box.put(TestEntityReadDuringRead()..strings2 = ["A2", "B2", "C3"]);
    // Do a database read of another box (to avoid stack overflow)
    // as part of calling a property setter.
    env.box.putMany(simpleItems());
    readDuringReadCalledFromSetter = () {
      env.box.getAll();
    };
    final actual = box.get(id)!;
    readDuringReadCalledFromSetter = null; // Do not leak the box instance.
    expect(actual.strings2, hasLength(3));
  });

  // https://github.com/objectbox/objectbox-dart/issues/550
  test("query with nested query returns all results", () {
    final box = env.store.box<TestEntityReadDuringRead>();
    box.put(TestEntityReadDuringRead());
    box.put(TestEntityReadDuringRead());
    // Do a query of another box (to avoid stack overflow)
    // as part of calling a property setter.
    env.box.putMany(simpleItems());
    var nestedCountUnexpected = false;
    readDuringReadCalledFromSetter = () {
      final query = env.box.query().build();
      final count = query.find().length;
      if (count != 6) nestedCountUnexpected = true;
      query.close();
    };
    final query = box.query().build();
    final all = query.find();
    query.close();

    expect(all.length, 2);
    expect(nestedCountUnexpected, false);

    readDuringReadCalledFromSetter = null; // Do not leak the box instance.
  });

  // https://github.com/objectbox/objectbox-dart/issues/550
  test("query with nested throwing query forwards error", () {
    final box = env.store.box<TestEntityReadDuringRead>();
    final id = box.put(TestEntityReadDuringRead());
    // Query for an object that will throw when being read
    // as part of calling a property setter.
    final throwingBox = env.store.box<ThrowingInConverters>();
    throwingBox.put(ThrowingInConverters(throwOnGet: true));
    readDuringReadCalledFromSetter = () {
      throwingBox.query().build().find();
    };
    // The outer query should forward the exception of the nested query.
    expect(() => box.get(id), ThrowingInConverters.throwsIn("Setter"));

    readDuringReadCalledFromSetter = null; // Do not leak the box instance.
  });
}

List<TestEntity> simpleItems() => ['One', 'Two', 'Three', 'Four', 'Five', 'Six']
    .map((s) => TestEntity(tString: s))
    .toList();

void testThrowException() {
  if (1 + 1 == 2) throw 'test-exception';
}
