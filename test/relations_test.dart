import 'package:objectbox/src/relations/to_many.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

void main() {
  /*late final*/ TestEnv env;

  setUp(() {
    env = TestEnv('relations');
  });

  tearDown(() {
    env?.close();
  });

  test('to-one put', () {
    final src = TestEntity(tString: 'Hello');
    src.relA.attach(env.store);
    src.relB.attach(env.store);

    expect(src.relA.hasValue, isFalse);
    expect(src.relA.target, isNull);
    src.relA.target = RelatedEntityA(tInt: 42);
    expect(src.relA.hasValue, isTrue);
    expect(src.relA.target, isNotNull);
    expect(src.relA.targetId, isZero);
    expect(src.relA.target.tInt, 42);

    src.relA.target.relB.attach(env.store);
    src.relA.target.relB.target = RelatedEntityB(tString: 'B1');

    // use the same target on two relations - must insert only once
    src.relB.target = src.relA.target.relB.target;

    env.box.put(src);

    var read = env.box.get(1);
    expect(read.tString, equals(src.tString));
    expect(read.relA.hasValue, isTrue);
    expect(read.relA.targetId, 1);
    var readRelA = read.relA;
    expect(readRelA.target.tInt, 42);
    var readRelARelB = readRelA.target.relB;
    expect(readRelARelB.target.tString, equals('B1'));

    // it's the same DB object ID but different instances (read twice)
    expect(read.relB.targetId, equals(readRelARelB.targetId));
    expect(read.relB.target, isNot(equals(readRelARelB.target)));

    // attach an existing item
    var readRelARelBRelA = readRelARelB.target.relA;
    expect(readRelARelBRelA.hasValue, isFalse);
    readRelARelBRelA.target = readRelA.target;
    expect(readRelARelBRelA.hasValue, isTrue);
    expect(readRelARelBRelA.targetId, readRelA.targetId);
    env.store.box<RelatedEntityB>().put(readRelARelB.target);

    read = env.box.get(1);
    readRelA = read.relA;
    readRelARelB = readRelA.target.relB;
    readRelARelBRelA = readRelARelB.target.relA;
    expect(readRelARelBRelA.targetId, readRelA.targetId);

    // remove a relation, using [targetId]
    readRelARelB.targetId = 0;
    env.store.box<RelatedEntityA>().put(readRelA.target);
    read = env.box.get(1);
    readRelA = read.relA;
    readRelARelB = readRelA.target.relB;
    expect(readRelARelB.target, isNull);
    expect(readRelARelB.targetId, isZero);

    // remove a relation, using [target]
    read.relA.target = null;
    env.store.box<TestEntity>().put(read);
    read = env.box.get(1);
    expect(read.relA.target, isNull);
    expect(read.relA.targetId, isZero);
  });

  test('to-one lazy loading', () {
    final srcBox = env.box;
    final targetBox = env.store.box<RelatedEntityA>();
    final src = TestEntity(tString: 'Hello');
    final target = RelatedEntityA(tInt: 42);
    target.id = targetBox.put(target);

    src.relA.attach(env.store);
    src.relA.target = target;
    srcBox.put(src);

    final read = env.box.get(1);
    expect(read.relA.targetId, target.id);
    // to verify the target is loaded lazily, we update it before accessing
    target.tInt = 99;
    targetBox.put(target);
    expect(read.relA.target.tInt, 99);
  });

  test('to-one putMany & simple ID query', () {
    final src = TestEntity(tString: 'Hello');
    src.relA.attach(env.store);
    src.relA.target = RelatedEntityA(tInt: 42);
    env.box.putMany([src, TestEntity(tString: 'there')]);
    expect(src.relA.targetId, 1);

    var query = env.box.query(TestEntity_.relA.equals(1)).build();
    expect(query.count(), 1);
    var read = query.find()[0];
    expect(read.tString, equals('Hello'));
    expect(read.relA.targetId, equals(1));
    query.close();

    query = env.box.query(TestEntity_.relA.equals(0)).build();
    expect(query.count(), 1);
    read = query.find()[0];
    expect(read.tString, equals('there'));
    expect(read.relA.targetId, equals(0));
    query.close();
  });

  test('to-one query link', () {
    final src1 = TestEntity(tString: 'foo');
    src1.relA.attach(env.store);
    src1.relA.target = RelatedEntityA(tInt: 5);
    final src2 = TestEntity(tString: 'bar');
    src2.relA.attach(env.store);
    src2.relA.target = RelatedEntityA(tInt: 10);
    src2.relA.target.relB.attach(env.store);
    src2.relA.target.relB.target = RelatedEntityB(tString: 'deep');
    env.box.putMany([src1, src2]);

    {
      final qb = env.box.query();
      qb.link(TestEntity_.relA, RelatedEntityA_.tInt.equals(10));
      final query = qb.build();
      final found = query.find();
      expect(found.length, 1);
      expect(found[0].tString, 'bar');
      query.close();
    }

    {
      final qb = env.box.query();
      qb
          .link(TestEntity_.relA)
          .link(RelatedEntityA_.relB, RelatedEntityB_.tString.equals('deep'));
      final query = qb.build();
      final found = query.find();
      expect(found.length, 1);
      expect(found[0].tString, 'bar');
      query.close();
    }
  });

  group('ToMany list management', () {
    ToMany<TestEntity> rel;

    setUp(() {
      rel = ToMany<TestEntity>();
    });

    test('basics', () {
      // test adding new objects as well as existing (duplicate) objects
      rel.add(TestEntity(tInt: 1));
      rel.addAll([TestEntity(tInt: 2), rel[0], TestEntity(tInt: 3)]);
      rel.add(rel[2]);
      expect(rel.length, 5);
      expect(rel.toSet().length, 3);

      check(rel, items: [1, 1, 1, 2, 3], added: [1, 2, 3], removed: []);

      // replace one of the duplicate objects with a new one
      expect(rel[2].tInt, equals(1));
      rel[2] = TestEntity(tInt: 4);
      check(rel, items: [1, 1, 2, 3, 4], added: [1, 2, 3, 4], removed: []);

      expect(rel[0].tInt, equals(1));
      expect(rel[4].tInt, equals(1));
      rel.removeAt(0);
      check(rel, items: [1, 2, 3, 4], added: [1, 2, 3, 4], removed: []);
      rel.removeAt(3);
      check(rel, items: [2, 3, 4], added: [2, 3, 4], removed: []);

      rel.length = 1;
      check(rel, items: [2], added: [2], removed: []);
    });

    test('removal', () {
      // bypass ToMany's list management to fake data loaded from DB
      InternalToManyTestAccess<TestEntity>(rel).items.addAll(
          [TestEntity(tInt: 1), TestEntity(tInt: 2), TestEntity(tInt: 3)]);
      check(rel, items: [1, 2, 3], added: [], removed: []);

      rel.removeAt(1);
      check(rel, items: [1, 3], added: [], removed: [2]);

      rel.remove(rel[1]);
      check(rel, items: [1], added: [], removed: [2, 3]);

      rel.add(TestEntity(tInt: 4));
      check(rel, items: [1, 4], added: [4], removed: [2, 3]);

      rel.remove(rel[1]);
      check(rel, items: [1], added: [], removed: [2, 3]);

      rel.add(rel[0]);
      check(rel, items: [1, 1], added: [1], removed: [2, 3]);
      rel.remove(rel[0]);
      check(rel, items: [1], added: [], removed: [2, 3]);
    });
  });

  group('ToMany', () {
    TestEntity src;
    setUp(() {
      src = TestEntity(tString: 'Hello');
      src.relA.attach(env.store);
    });

    test('put', () {
      expect(src.relManyA, isNotNull);
      src.relManyA.add(RelatedEntityA(tInt: 1));
      src.relManyA.addAll(
          [RelatedEntityA(tInt: 2), src.relManyA[0], RelatedEntityA(tInt: 3)]);
      env.box.put(src);

      src = env.box.get(1);
      check(src.relManyA, items: [1, 2, 3], added: [], removed: []);

      src.relManyA.removeWhere((e) => e.tInt == 2);
      check(src.relManyA, items: [1, 3], added: [], removed: [2]);
      env.box.put(src);

      src = env.box.get(1);
      check(src.relManyA, items: [1, 3], added: [], removed: []);

      src.relManyA.add(src.relManyA[0]);
      src.relManyA.add(RelatedEntityA(tInt: 4));
      check(src.relManyA, items: [1, 1, 3, 4], added: [1, 4], removed: []);
      env.box.put(src);

      src = env.box.get(1);
      check(src.relManyA, items: [1, 3, 4], added: [], removed: []);
    });
  });
}

int toInt(e) => e.tInt;

void check<E>(ToMany<E> rel,
    {List<int> items, List<int> added, List<int> removed}) {
  final relT = InternalToManyTestAccess(rel);
  expect(relT.items.map(toInt), unorderedEquals(items));
  expect(relT.added.map(toInt), unorderedEquals(added));
  expect(relT.removed.map(toInt), unorderedEquals(removed));
}
