import "dart:io";
import "package:test/test.dart";
import "package:objectbox/objectbox.dart";
part "basics_test.g.dart";

@Entity(id: 1, uid: 1)
class TestEntity {
  @Id(id: 1, uid: 1001)
  int id;

  @Property(id: 2, uid: 1002)
  String text;

  @Property(id: 3, uid: 1003)
  int number;

  @Property(id: 4, uid: 1004)
  double d;

  @Property(id: 5, uid: 1005)
  bool b;

  TestEntity();

  TestEntity.initId(this.id, this.text);
  TestEntity.initInteger(this.number);
  TestEntity.initIntegerAndText(this.number, this.text);
  TestEntity.initText(this.text);
  TestEntity.initDoubleAndBoolean(this.d, this.b);
}

main() {
  Store store, store2;
  Box box, box2;

  setUp(() {
    store = Store([
      [TestEntity, TestEntity_OBXDefs]
    ]);
    box = Box<TestEntity>(store);
  });

  group("box", () {
    test(".put() returns a valid id", () {
      int putId = box.put(TestEntity.initText("Hello"));
      expect(putId, greaterThan(0));
    });

    test(".get() returns the correct item", () {
      final int putId = box.put(TestEntity.initText("Hello"));
      final TestEntity item = box.get(putId);
      expect(item.id, equals(putId));
      expect(item.text, equals("Hello"));
    });

    test(".put() and box.get() keep Unicode characters", () {
      final String text = "😄你好";
      final TestEntity inst = box.get(box.put(TestEntity.initText(text)));
      expect(inst.text, equals(text));
    });

    test(".put() can update an item", () {
      final int putId1 = box.put(TestEntity.initText("One"));
      final int putId2 = box.put(TestEntity.initId(putId1, "Two"));
      expect(putId2, equals(putId1));
      final TestEntity item = box.get(putId2);
      expect(item.text, equals("Two"));
    });

    test(".getAll retrieves all items", () {
      final int id1 = box.put(TestEntity.initText("One"));
      final int id2 = box.put(TestEntity.initText("Two"));
      final int id3 = box.put(TestEntity.initText("Three"));
      final List<TestEntity> items = box.getAll();
      expect(items.length, equals(3));
      expect(items.where((i) => i.id == id1).single.text, equals("One"));
      expect(items.where((i) => i.id == id2).single.text, equals("Two"));
      expect(items.where((i) => i.id == id3).single.text, equals("Three"));
    });

    test(".putMany inserts multiple items", () {
      final List<TestEntity> items = [
        TestEntity.initText("One"),
        TestEntity.initText("Two"),
        TestEntity.initText("Three")
      ];
      box.putMany(items);
      final List<TestEntity> itemsFetched = box.getAll();
      expect(itemsFetched.length, equals(items.length));
    });

    test(".putMany returns the new item IDs", () {
      final List<TestEntity> items =
          ["One", "Two", "Three", "Four", "Five", "Six", "Seven"].map((s) => TestEntity.initText(s)).toList();
      final List<int> ids = box.putMany(items);
      expect(ids.length, equals(items.length));
      for (int i = 0; i < items.length; ++i) expect(box.get(ids[i]).text, equals(items[i].text));
    });

    test(".getMany correctly handles non-existant items", () {
      final List<TestEntity> items = ["One", "Two"].map((s) => TestEntity.initText(s)).toList();
      final List<int> ids = box.putMany(items);
      int otherId = 1;
      while (ids.indexWhere((id) => id == otherId) != -1) ++otherId;
      final List<TestEntity> fetchedItems = box.getMany([ids[0], otherId, ids[1]]);
      expect(fetchedItems.length, equals(3));
      expect(fetchedItems[0].text, equals("One"));
      expect(fetchedItems[1], equals(null));
      expect(fetchedItems[2].text, equals("Two"));
    });
  });

  group("query", () {
    test(".null and .notNull", () {
      box.putMany([
        TestEntity.initDoubleAndBoolean(0.1, true),
        TestEntity.initDoubleAndBoolean(0.3, false),
        TestEntity.initText("one"),
        TestEntity.initText("two"),
      ] as List<TestEntity>);

      final d = TestEntity_.d;
      final b = TestEntity_.b;
      final t = TestEntity_.text;

      final qbNull    = box.query(b.isNull()).build();
      final qbNotNull = box.query(b.notNull()).build();
      final qtNull    = box.query(t.isNull()).build();
      final qtNotNull = box.query(t.notNull()).build();
      final qdNull    = box.query(t.isNull()).build();
      final qdNotNull = box.query(t.notNull()).build();

      [ qbNull, qbNotNull, qtNull, qtNotNull, qdNull, qdNotNull ]
        .forEach((q) {
          expect(q.count(), 2);
          q.close();
        });
    });

    test(".count doubles and booleans", () {
      box.putMany([
        TestEntity.initDoubleAndBoolean(0.1, true),
        TestEntity.initDoubleAndBoolean(0.3, false),
        TestEntity.initDoubleAndBoolean(0.5, true),
        TestEntity.initDoubleAndBoolean(0.7, false),
        TestEntity.initDoubleAndBoolean(0.9, true)
      ] as List<TestEntity>);

      final d = TestEntity_.d;
      final b = TestEntity_.b;

      // final anyQuery0 = (d == 0.8) & (b == false) | (d == 0.7) & (b == false) | d.between(0.5, 0.3); ; // TODO figure out why adding between breaks the chain
      final anyQuery0 = (d == 0.8) & (b == false) | (d == 0.7) & (b == false);

      final allQuery0 = (d == 0.1) & (b == true);

      final q0    = box.query(b.equal(false)).build();
      final qany0 = box.query(anyQuery0 as QueryCondition).build();
      final qall0 = box.query(allQuery0 as QueryCondition).build();

      expect(q0.count(), 2);
      expect(qany0.count(), 3);
      expect(qall0.count(), 1);

      [ q0, qany0, qall0 ].forEach((q) => q.close());
    });

    test(".count items after grouping with and/or", () {
      box.put(TestEntity.initText("Hello"));
      box.put(TestEntity.initText("Goodbye"));
      box.put(TestEntity.initText("World"));

      box.put(TestEntity.initInteger(1337));
      box.put(TestEntity.initInteger(80085));

      box.put(TestEntity.initIntegerAndText(-1337, "meh"));
      box.put(TestEntity.initIntegerAndText(-1332 + -5, "bleh"));
      box.put(TestEntity.initIntegerAndText(1337, "Goodbye"));

      final text = TestEntity_.text;
      final number = TestEntity_.number;

      QueryCondition cond1 = ((text == "Hello") as QueryCondition) | ((number == 1337) as QueryCondition);
      QueryCondition cond2 = text.equal("Hello") | number.equal(1337);
      QueryCondition cond3 = text.equal("What?").and(text.equal("Hello")).or(text.equal("World"));
      QueryCondition cond4 = text.equal("Goodbye").and(number.equal(1337)).or(number.equal(1337)).or(text.equal("Cruel")).or(text.equal("World"));
      QueryCondition cond5 = text.equal("bleh") & number.equal(-1337);
      QueryCondition cond6 = ((text == "Hello") as QueryCondition) & ((number == 1337) as QueryCondition);

      final selfInference1 = (text == "Hello") & (number == 1337);
      final selfInference2 = (text == "Hello") | (number == 1337);
      // QueryCondition cond0 = (text == "Hello") | (number == 1337); // TODO research why broken without the cast

      /*
      // doesn't work
      final anyGroupCondition0 = <QueryCondition>[text == "meh", text == "bleh"];
      final allGroupCondition0 = <QueryCondition>[text == "Goodbye", number == 1337];
      */

      final anyGroupCondition0 = <QueryCondition>[text.equal("meh"), text.equal("bleh")];
      final allGroupCondition0 = <QueryCondition>[text.equal("Goodbye"), number.equal(1337)];


      final queryAny0 = box.queryAny(anyGroupCondition0).build();
      final queryAll0 = box.queryAll(allGroupCondition0).build();

      final q1 = box.query(cond1).build();
      final q2 = box.query(cond2).build();
      final q3 = box.query(cond3).build();
      final q4 = box.query(cond4).build();

      box.query(selfInference1 as QueryCondition);
      box.query(selfInference2 as QueryCondition);

      expect(q1.count(), 3);
      expect(q2.count(), 3);
      expect(q3.count(), 1);
      expect(q4.count(), 3);
      expect(queryAny0.count(), 2);
      expect(queryAll0.count(), 1);

      [ q1, q2, q3, q4, queryAny0, queryAll0 ].forEach((q) => q.close());
    });
  });

  tearDown(() {
    if (store != null) store.close();
    store = null;
    var dir = new Directory("objectbox");
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
}
