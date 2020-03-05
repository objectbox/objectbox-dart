import "package:test/test.dart";
import "package:objectbox/objectbox.dart";
import "entity.dart";
import 'test_env.dart';

void main() {
  TestEnv env;
  Box box;
  Store store;

  final List<TestEntity> simpleItems =
      ["One", "Two", "Three", "Four", "Five", "Six"].map((s) => TestEntity(tString: s)).toList();

  setUp(() {
    env = TestEnv("box");
    box = env.box;
    store = env.store;
  });

  test(".put() returns a valid id", () {
    int putId = box.put(TestEntity(tString: "Hello"));
    expect(putId, greaterThan(0));
  });

  test(".get() returns the correct item", () {
    final int putId = box.put(TestEntity(tString: "Hello"));
    final TestEntity item = box.get(putId);
    expect(item.id, equals(putId));
    expect(item.tString, equals("Hello"));
  });

  test(".put() and box.get() keep Unicode characters", () {
    final String text = "😄你好";
    final TestEntity inst = box.get(box.put(TestEntity(tString: text)));
    expect(inst.tString, equals(text));
  });

  test(".put() can update an item", () {
    final int putId1 = box.put(TestEntity(tString: "One"));
    final int putId2 = box.put(TestEntity(tString: "Two")..id = putId1);
    expect(putId2, equals(putId1));
    final TestEntity item = box.get(putId2);
    expect(item.tString, equals("Two"));
  });

  test(".getAll retrieves all items", () {
    final int id1 = box.put(TestEntity(tString: "One"));
    final int id2 = box.put(TestEntity(tString: "Two"));
    final int id3 = box.put(TestEntity(tString: "Three"));
    final List<TestEntity> items = box.getAll();
    expect(items.length, equals(3));
    expect(items.where((i) => i.id == id1).single.tString, equals("One"));
    expect(items.where((i) => i.id == id2).single.tString, equals("Two"));
    expect(items.where((i) => i.id == id3).single.tString, equals("Three"));
  });

  test(".putMany inserts multiple items", () {
    final List<TestEntity> items = [
      TestEntity(tString: "One"),
      TestEntity(tString: "Two"),
      TestEntity(tString: "Three")
    ];
    box.putMany(items);
    final List<TestEntity> itemsFetched = box.getAll();
    expect(itemsFetched.length, equals(items.length));
    expect(itemsFetched[0].tString, equals(items[0].tString));
    expect(itemsFetched[1].tString, equals(items[1].tString));
    expect(itemsFetched[2].tString, equals(items[2].tString));
  });

  test(".putMany returns the new item IDs", () {
    final List<TestEntity> items =
        ["One", "Two", "Three", "Four", "Five", "Six", "Seven"].map((s) => TestEntity(tString: s)).toList();
    final List<int> ids = box.putMany(items);
    expect(ids.length, equals(items.length));
    for (int i = 0; i < items.length; ++i) {
      expect(box.get(ids[i]).tString, equals(items[i].tString));
    }
  });

  test(".getAll/getMany works on large arrays", () {
    // This would fail on 32-bit system if objectbox-c obx_supports_bytes_array() wasn't respected
    final length = 10 * 1000;
    final largeString = 'A' * length;
    expect(largeString.length, length);

    box.put(TestEntity(tString: largeString));
    box.put(TestEntity(tString: largeString));

    List<TestEntity> items = box.getAll();
    expect(items.length, 2);
    expect(items[0].tString, largeString);
    expect(items[1].tString, largeString);

    box.put(TestEntity(tString: largeString));

    items = box.getMany([1, 2]);
    expect(items.length, 2);
    expect(items[0].tString, largeString);
    expect(items[1].tString, largeString);
  });

  test(".getMany correctly handles non-existent items", () {
    final List<TestEntity> items = ["One", "Two"].map((s) => TestEntity(tString: s)).toList();
    final List<int> ids = box.putMany(items);
    int otherId = 1;
    while (ids.indexWhere((id) => id == otherId) != -1) {
      ++otherId;
    }
    final List<TestEntity> fetchedItems = box.getMany([ids[0], otherId, ids[1]]);
    expect(fetchedItems.length, equals(3));
    expect(fetchedItems[0].tString, equals("One"));
    expect(fetchedItems[1], equals(null));
    expect(fetchedItems[2].tString, equals("Two"));
  });

  test("all limit integers are stored correctly", () {
    final int8Min = -128;
    final int8Max = 127;
    final uint8Min = 0;
    final uint8Max = 255;
    final int16Min = -32768;
    final int16Max = 32767;
    final int32Min = -2147483648;
    final int32Max = 2147483647;
    final int64Min = -9223372036854775808;
    final int64Max = 9223372036854775807;
    final List<TestEntity> items = [
      ...[int8Min, int8Max].map((n) => TestEntity(tChar: n)).toList(),
      ...[uint8Min, uint8Max].map((n) => TestEntity(tByte: n)).toList(),
      ...[int16Min, int16Max].map((n) => TestEntity(tShort: n)).toList(),
      ...[int32Min, int32Max].map((n) => TestEntity(tInt: n)).toList(),
      ...[int64Min, int64Max].map((n) => TestEntity(tLong: n)).toList()
    ];
    expect("${items[8].tLong}", equals("$int64Min"));
    expect("${items[9].tLong}", equals("$int64Max"));
    final List<TestEntity> fetchedItems = box.getMany(box.putMany(items));
    expect(fetchedItems[0].tChar, equals(int8Min));
    expect(fetchedItems[1].tChar, equals(int8Max));
    expect(fetchedItems[2].tByte, equals(uint8Min));
    expect(fetchedItems[3].tByte, equals(uint8Max));
    expect(fetchedItems[4].tShort, equals(int16Min));
    expect(fetchedItems[5].tShort, equals(int16Max));
    expect(fetchedItems[6].tInt, equals(int32Min));
    expect(fetchedItems[7].tInt, equals(int32Max));
    expect(fetchedItems[8].tLong, equals(int64Min));
    expect(fetchedItems[9].tLong, equals(int64Max));
  });

  test("special floating point values are handled correctly", () {
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
    final List<TestEntity> fetchedItems = box.getMany(box.putMany(items));
    List<double> fetchedVals = [];
    for (var i = 0; i < fetchedItems.length; i++) {
      fetchedVals.add(i < valsFloat.length ? fetchedItems[i].tFloat : fetchedItems[i].tDouble);
    }

    for (var i = 0; i < fetchedVals.length; i++) {
      double expected = i < valsFloat.length ? valsFloat[i] : valsDouble[i - valsFloat.length];
      if (expected.isNaN) {
        expect(fetchedVals[i].isNaN, equals(true));
      } else {
        expect(fetchedVals[i], equals(expected));
      }
    }
  });

  test("null properties are handled correctly", () {
    final List<TestEntity> items = [TestEntity(), TestEntity(tLong: 10), TestEntity(tString: "Hello")];
    final List<TestEntity> fetchedItems = box.getMany(box.putMany(items));
    expect(fetchedItems[0].id, isNot(equals(null)));
    expect(fetchedItems[0].tLong, equals(null));
    expect(fetchedItems[0].tString, equals(null));
    expect(fetchedItems[0].tBool, equals(null));
    expect(fetchedItems[0].tDouble, equals(null));
    expect(fetchedItems[1].id, isNot(equals(null)));
    expect(fetchedItems[1].tLong, isNot(equals(null)));
    expect(fetchedItems[1].tString, equals(null));
    expect(fetchedItems[1].tBool, equals(null));
    expect(fetchedItems[1].tDouble, equals(null));
    expect(fetchedItems[2].id, isNot(equals(null)));
    expect(fetchedItems[2].tLong, equals(null));
    expect(fetchedItems[2].tString, isNot(equals(null)));
    expect(fetchedItems[2].tBool, equals(null));
    expect(fetchedItems[2].tDouble, equals(null));
  });

  test("all types are handled correctly", () {
    TestEntity item = TestEntity(
        tString: "Hello",
        tLong: 1234,
        tDouble: 3.14159,
        tBool: true,
        tByte: 123,
        tShort: -4567,
        tChar: 'x'.codeUnitAt(0),
        tInt: 789012,
        tFloat: -2.71);
    final fetchedItem = box.get(box.put(item));
    expect(fetchedItem.tString, equals("Hello"));
    expect(fetchedItem.tLong, equals(1234));
    expect((fetchedItem.tDouble - 3.14159).abs(), lessThan(0.000000000001));
    expect(fetchedItem.tBool, equals(true));
    expect(fetchedItem.tByte, equals(123));
    expect(fetchedItem.tShort, equals(-4567));
    expect(fetchedItem.tChar, equals('x'.codeUnitAt(0)));
    expect(fetchedItem.tInt, equals(789012));
    expect((fetchedItem.tFloat - (-2.71)).abs(), lessThan(0.0000001));
  });

  test(".count() works", () {
    expect(box.count(), equals(0));
    List<int> ids = box.putMany(simpleItems);
    expect(box.count(), equals(6));
    expect(box.count(limit: 2), equals(2));
    expect(box.count(limit: 10), equals(6));
    //add more
    ids.addAll(box.putMany(simpleItems));
    expect(box.count(), equals(12));
  });

  test(".isEmpty() works", () {
    bool isEmpty = box.isEmpty();
    expect(isEmpty, equals(true));
    //check complementary
    box.putMany(simpleItems);
    isEmpty = box.isEmpty();
    expect(isEmpty, equals(false));
  });

  test(".contains() works", () {
    int id = box.put(TestEntity(tString: "container"));
    bool contains = box.contains(id);
    expect(contains, equals(true));
    //check complementary
    box.remove(id);
    contains = box.contains(id);
    expect(contains, equals(false));
  });

  test(".containsMany() works", () {
    List<int> ids = box.putMany(simpleItems);
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

  test(".remove(id) works", () {
    final List<int> ids = box.putMany(simpleItems);
    //check if single id remove works
    expect(box.remove(ids[1]), equals(true));
    expect(box.count(), equals(5));
    //check what happens if id already deleted -> throws OBJBOXEX 404
    bool success = box.remove(ids[1]);
    expect(box.count(), equals(5));
    expect(success, equals(false));
  });

  test(".removeMany(ids) works", () {
    final List<int> ids = box.putMany(simpleItems);
    expect(box.count(), equals(6));
    box.removeMany(ids.sublist(4));
    expect(box.count(), equals(4));
    //again test what happens if ids already deleted
    box.removeMany(ids.sublist(4));
    expect(box.count(), equals(4));

    // verify the right items were removed
    final List<int> remainingIds = box.getAll().map((o) => (o as TestEntity).id).toList();
    expect(remainingIds, unorderedEquals(ids.sublist(0, 4)));
  });

  test(".removeAll() works", () {
    List<int> ids = box.putMany(simpleItems);
    int removed = box.removeAll();
    expect(removed, equals(6));
    expect(box.count(), equals(0));
    //try with different number of items
    List<TestEntity> items = ["one", "two", "three"].map((s) => TestEntity(tString: s)).toList();
    ids.addAll(box.putMany(items));
    removed = box.removeAll();
    expect(removed, equals(3));
  });

  test("simple write in txn works", () {
    int count;
    fn() {
      box.putMany(simpleItems);
    }

    store.runInTransaction(TxMode.Write, fn);
    count = box.count();
    expect(count, equals(6));
  });

  test("failing transactions", () {
    try {
      store.runInTransaction(TxMode.Write, () {
        box.putMany(simpleItems);
        throw Exception("Test exception");
      });
    } on Exception {
      ; //otherwise test fails due to not handling exceptions
    } finally {
      expect(box.count(), equals(0));
    }
  });

  test("recursive write in write transaction", () {
    store.runInTransaction(TxMode.Write, () {
      box.putMany(simpleItems);
      store.runInTransaction(TxMode.Write, () {
        box.putMany(simpleItems);
      });
    });
    expect(box.count(), equals(12));
  });

  test("recursive read in write transaction", () {
    int count = store.runInTransaction(TxMode.Write, () {
      box.putMany(simpleItems);
      return store.runInTransaction(TxMode.Read, () {
        return box.count();
      });
    });
    expect(count, equals(6));
  });

  test("recursive write in read -> fails during creation", () {
    try {
      store.runInTransaction(TxMode.Read, () {
        box.count();
        return store.runInTransaction(TxMode.Write, () {
          return box.putMany(simpleItems);
        });
      });
    } on ObjectBoxException catch (ex) {
      expect(ex.toString(), startsWith("ObjectBoxException: failed to create transaction"));
    }
  });

  test("failing in recursive txn", () {
    store.runInTransaction(TxMode.Write, () {
      //should throw code10001 -> valid until fix
      List<int> ids = store.runInTransaction(TxMode.Read, () {
        return box.putMany(simpleItems);
      });
      expect(ids.length, equals(6));
    });
  });

  tearDown(() {
    env.close();
  });
}
