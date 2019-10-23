import "package:test/test.dart";
import "package:objectbox/objectbox.dart";
import "entity.dart";
import 'test_env.dart';

void main() {
  TestEnv env;
  Box box;

  final List<TestEntity> simple_items =
      ["One", "Two", "Three", "Four", "Five", "Six"].map((s) => TestEntity.initText(s)).toList();

  setUp(() {
    env = TestEnv<TestEntity>(TestEntity_OBXDefs, "box");
    box = env.box;
  });

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
    for (int i = 0; i < items.length; ++i) {
      expect(box.get(ids[i]).text, equals(items[i].text));
    }
  });

  test(".getMany correctly handles non-existant items", () {
    final List<TestEntity> items = ["One", "Two"].map((s) => TestEntity.initText(s)).toList();
    final List<int> ids = box.putMany(items);
    int otherId = 1;
    while (ids.indexWhere((id) => id == otherId) != -1) {
      ++otherId;
    }
    final List<TestEntity> fetchedItems = box.getMany([ids[0], otherId, ids[1]]);
    expect(fetchedItems.length, equals(3));
    expect(fetchedItems[0].text, equals("One"));
    expect(fetchedItems[1], equals(null));
    expect(fetchedItems[2].text, equals("Two"));
  });

  test(".count() works", () {
    expect(box.count(), equals(0));
    List<int> ids = box.putMany(simple_items);
    expect(box.count(), equals(6));
    expect(box.count(limit: 2), equals(2));
    expect(box.count(limit: 10), equals(6));
    //add more
    ids.addAll(box.putMany(simple_items));
    expect(box.count(), equals(12));
  });

  test(".isEmpty() works", () {
    bool isEmpty = box.isEmpty();
    expect(isEmpty, equals(true));
    //check complementary
    box.putMany(simple_items);
    isEmpty = box.isEmpty();
    expect(isEmpty, equals(false));
  });

  test(".contains() works", () {
    int id = box.put(TestEntity.initText("container"));
    bool contains = box.contains(id);
    expect(contains, equals(true));
    //check complementary
    box.remove(id);
    contains = box.contains(id);
    expect(contains, equals(false));
  });

  test(".containsMany() works", () {
    List<int> ids = box.putMany(simple_items);
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
    final List<int> ids = box.putMany(simple_items);
    //check if single id remove works
    expect(box.remove(ids[1]), equals(true));
    expect(box.count(), equals(5));
    //check what happens if id already deleted -> throws OBJBOXEX 404
    bool success = box.remove(ids[1]);
    expect(box.count(), equals(5));
    expect(success, equals(false));
  });

  test(".removeMany(ids) works", () {
    final List<int> ids = box.putMany(simple_items);
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
    List<int> ids = box.putMany(simple_items);
    int removed = box.removeAll();
    expect(removed, equals(6));
    expect(box.count(), equals(0));
    //try with different number of items
    List<TestEntity> items = ["one", "two", "three"].map((s) => TestEntity.initText(s)).toList();
    ids.addAll(box.putMany(items));
    removed = box.removeAll();
    expect(removed, equals(3));
  });

  tearDown(() {
    env.close();
  });
}
