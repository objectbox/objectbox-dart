import 'package:objectbox/src/relations/to_many.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'entity2.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv('relations');
  });

  tearDown(() => env.close());

  group('ToOne', () {
    test('put', () {
      final src = TestEntity(tString: 'Hello');
      expect(src.relA.hasValue, isFalse);
      expect(src.relA.target, isNull);
      src.relA.target = RelatedEntityA(tInt: 42);
      expect(src.relA.hasValue, isTrue);
      expect(src.relA.target, isNotNull);
      expect(src.relA.target!.tInt, 42);

      // Can't access targetId on new objects (not coming from box) unless
      // attached manually.
      expect(
          () => src.relA.targetId,
          throwsA(predicate(
              (StateError e) => e.toString().contains('call attach('))));
      src.relA.attach(env.store);
      expect(src.relA.targetId, isZero);

      src.relA.target!.relB.target = RelatedEntityB(tString: 'B1');

      // use the same target on two relations - must insert only once
      src.relB.target = src.relA.target!.relB.target;

      env.box.put(src);

      var read = env.box.get(1)!;
      expect(read.tString, equals(src.tString));
      expect(read.relA.hasValue, isTrue);
      expect(read.relA.targetId, 1);
      var readRelA = read.relA;
      expect(readRelA.target!.tInt, 42);
      var readRelARelB = readRelA.target!.relB;
      expect(readRelARelB.target!.tString, equals('B1'));

      // it's the same DB object ID but different instances (read twice)
      expect(read.relB.targetId, equals(readRelARelB.targetId));
      expect(read.relB.target, isNot(equals(readRelARelB.target)));

      // attach an existing item
      var readRelARelBRelA = readRelARelB.target!.relA;
      expect(readRelARelBRelA.hasValue, isFalse);
      readRelARelBRelA.target = readRelA.target;
      expect(readRelARelBRelA.hasValue, isTrue);
      expect(readRelARelBRelA.targetId, readRelA.targetId);
      env.store.box<RelatedEntityB>().put(readRelARelB.target!);

      read = env.box.get(1)!;
      readRelA = read.relA;
      readRelARelB = readRelA.target!.relB;
      readRelARelBRelA = readRelARelB.target!.relA;
      expect(readRelARelBRelA.targetId, readRelA.targetId);

      // remove a relation, using [targetId]
      readRelARelB.targetId = 0;
      env.store.box<RelatedEntityA>().put(readRelA.target!);
      read = env.box.get(1)!;
      readRelA = read.relA;
      readRelARelB = readRelA.target!.relB;
      expect(readRelARelB.target, isNull);
      expect(readRelARelB.targetId, isZero);

      // remove a relation, using [target]
      read.relA.target = null;
      env.store.box<TestEntity>().put(read);
      read = env.box.get(1)!;
      expect(read.relA.target, isNull);
      expect(read.relA.targetId, isZero);
    });

    test('lazy loading', () {
      final srcBox = env.box;
      final targetBox = env.store.box<RelatedEntityA>();
      final src = TestEntity(tString: 'Hello');
      final target = RelatedEntityA(tInt: 42);
      target.id = targetBox.put(target);

      src.relA.target = target;
      srcBox.put(src);

      final read = env.box.get(1)!;
      expect(read.relA.targetId, target.id);
      // to verify the target is loaded lazily, we update it before accessing
      target.tInt = 99;
      targetBox.put(target);
      expect(read.relA.target!.tInt, 99);
    });

    test('putMany & simple ID query', () {
      final src = TestEntity(tString: 'Hello');
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

    test('query link', () {
      final src1 = TestEntity(tString: 'foo');
      src1.relA.target = RelatedEntityA(tInt: 5);
      final src2 = TestEntity(tString: 'bar');
      src2.relA.target = RelatedEntityA(tInt: 10);
      src2.relA.target!.relB.target = RelatedEntityB(tString: 'deep');
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
  });

  group('ToMany list management', () {
    late ToMany<TestEntity> rel;

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
    TestEntity? src;
    setUp(() {
      src = TestEntity(tString: 'Hello');
    });

    test('put', () {
      expect(src!.relManyA, isNotNull);
      src!.relManyA.add(RelatedEntityA(tInt: 1));
      src!.relManyA.addAll(
          [RelatedEntityA(tInt: 2), src!.relManyA[0], RelatedEntityA(tInt: 3)]);
      env.box.put(src!);

      src = env.box.get(1);
      check(src!.relManyA, items: [1, 2, 3], added: [], removed: []);

      src!.relManyA.removeWhere((e) => e.tInt == 2);
      check(src!.relManyA, items: [1, 3], added: [], removed: [2]);
      env.box.put(src!);

      src = env.box.get(1);
      check(src!.relManyA, items: [1, 3], added: [], removed: []);

      src!.relManyA.add(src!.relManyA[0]);
      src!.relManyA.add(RelatedEntityA(tInt: 4));
      check(src!.relManyA, items: [1, 1, 3, 4], added: [1, 4], removed: []);
      env.box.put(src!);

      src = env.box.get(1);
      check(src!.relManyA, items: [1, 3, 4], added: [], removed: []);
    });

    // note: this requires box.attach() in Java/Kotlin, should not here.
    test('put: self-assigned ID on source', () {
      src!.id = 42;
      src!.relManyA.add(RelatedEntityA(tInt: 1));
      env.box.put(src!);

      src = env.box.get(42);
      check(src!.relManyA, items: [1], added: [], removed: []);
    });

    test("don't load old data when just adding", () {
      expect(src!.relManyA, isNotNull);
      src!.relManyA.add(RelatedEntityA(tInt: 1));
      src!.relManyA.addAll(
          [RelatedEntityA(tInt: 2), src!.relManyA[0], RelatedEntityA(tInt: 3)]);
      env.box.put(src!);

      src = env.box.get(1);
      check(src!.relManyA, items: [1, 2, 3], added: [], removed: []);
      expect(InternalToManyTestAccess(src!.relManyA).itemsLoaded, isTrue);

      src = env.box.get(1);
      expect(InternalToManyTestAccess(src!.relManyA).itemsLoaded, isFalse);
      final rel = RelatedEntityA(tInt: 4);
      src!.relManyA.add(rel);
      src!.relManyA.addAll([RelatedEntityA(tInt: 5), rel]);
      expect(InternalToManyTestAccess(src!.relManyA).itemsLoaded, isFalse);
      env.box.put(src!);
      expect(InternalToManyTestAccess(src!.relManyA).itemsLoaded, isFalse);
      src = env.box.get(1);
      check(src!.relManyA, items: [1, 2, 3, 4, 5], added: [], removed: []);
    });

    test('query link', () {
      final src1 = TestEntity(tString: 'foo');
      src1.relManyA.add(RelatedEntityA(tInt: 5));
      final src2 = TestEntity(tString: 'bar');
      src2.relManyA.add(RelatedEntityA(tInt: 10));
      src2.relManyA[0].relB.target = RelatedEntityB(tString: 'deep');
      env.box.putMany([src1, src2]);

      {
        final qb = env.box.query();
        qb.linkMany(TestEntity_.relManyA, RelatedEntityA_.tInt.equals(10));
        final query = qb.build();
        final found = query.find();
        expect(found.length, 1);
        expect(found[0].tString, 'bar');
        query.close();
      }

      {
        final qb = env.box.query();
        qb
            .linkMany(TestEntity_.relManyA)
            .link(RelatedEntityA_.relB, RelatedEntityB_.tString.equals('deep'));
        final query = qb.build();
        final found = query.find();
        expect(found.length, 1);
        expect(found[0].tString, 'bar');
        query.close();
      }
    });
  });

  group('to-one backlink', () {
    late Box<RelatedEntityB> boxB;
    setUp(() {
      boxB = env.store.box();
      env.box.put(TestEntity(tString: 'foo')
        ..relB.target = RelatedEntityB(tString: 'foo B'));
      env.box.put(TestEntity(tString: 'bar')
        ..relB.target = RelatedEntityB(tString: 'bar B'));
      env.box.put(TestEntity(tString: 'bar2')..relB.targetId = 2);

      boxB.put(RelatedEntityB()..tString = 'not referenced');
    });

    test('put and get', () {
      final List<RelatedEntityB?> b = boxB.getAll();
      expect(b[0]!.id, 1);
      expect(b[0]!.tString, 'foo B');
      expect(b[1]!.id, 2);
      expect(b[1]!.tString, 'bar B');
      expect(b[2]!.id, 3);
      expect(b[2]!.tString, 'not referenced');

      final strings = (TestEntity? e) => e!.tString;
      expect(b[0]!.testEntities.map(strings), sameAsList(['foo']));
      expect(b[1]!.testEntities.map(strings), sameAsList(['bar', 'bar2']));
      expect(b[2]!.testEntities.length, isZero);

      // Update an existing target.
      b[1]!.testEntities.add(env.box.get(1)!); // foo
      expect(
          b[1]!.testEntities.map(strings), sameAsList(['foo', 'bar', 'bar2']));
      b[1]!.testEntities.removeWhere((e) => e.tString == 'bar');
      expect(b[1]!.testEntities.map(strings), sameAsList(['foo', 'bar2']));
      boxB.put(b[1]!);
      b[1] = boxB.get(b[1]!.id!);
      expect(b[1]!.testEntities.map(strings), sameAsList(['foo', 'bar2']));

      // Insert a new target, already with some "source" entities pointing to it.
      var newB = RelatedEntityB();
      expect(newB.testEntities.length, isZero);
      newB.testEntities.add(env.box.get(1)!); // foo
      newB.testEntities.add(TestEntity(tString: 'newly created from B'));
      boxB.put(newB);
      expect(newB.testEntities[0].id, 1);
      expect(newB.testEntities[1].id, 4);

      expect(env.box.get(4)!.tString, equals('newly created from B'));
      newB = boxB.get(newB.id!)!;
      expect(newB.testEntities.map(strings),
          sameAsList(['foo', 'newly created from B']));

      // The previous put also affects b[1], 'foo' is not related anymore.
      b[1] = boxB.get(b[1]!.id!);
      expect(b[1]!.testEntities.map(strings), sameAsList(['bar2']));
    });

    test('put on ToMany side before loading', () {
      // Test [ToMany._addedBeforeLoad] field - there was previously an issue
      // causing the backlinked item to be shown twice in ToMany.
      final b = RelatedEntityB();
      b.testEntities.add(TestEntity());
      boxB.put(b);
      expect(b.testEntities.length, 1);
    });

    test('query', () {
      final qb = boxB.query();
      qb.backlink(TestEntity_.relB, TestEntity_.tString.startsWith('bar'));
      final query = qb.build();
      final b = query.find();
      expect(b.length, 1);
      expect(b.first.tString, 'bar B');
      query.close();
    });
  });

  group('to-many backlink', () {
    late Box<RelatedEntityA> boxA;
    setUp(() {
      boxA = env.store.box();
      env.box.put(
          TestEntity(tString: 'foo')..relManyA.add(RelatedEntityA(tInt: 1)));
      env.box.put(
          TestEntity(tString: 'bar')..relManyA.add(RelatedEntityA(tInt: 2)));
      env.box.put(TestEntity(tString: 'bar2')..relManyA.add(boxA.get(2)!));

      boxA.put(RelatedEntityA()..tInt = 3); // not referenced
    });

    test('put and get', () {
      final a = boxA.getAll();
      expect(a[0].id, 1);
      expect(a[0].tInt, 1);
      expect(a[1].id, 2);
      expect(a[1].tInt, 2);
      expect(a[2].id, 3);
      expect(a[2].tInt, 3);

      final strings = (TestEntity? e) => e!.tString;
      expect(a[0].testEntities.map(strings), sameAsList(['foo']));
      expect(a[1].testEntities.map(strings), sameAsList(['bar', 'bar2']));
      expect(a[2].testEntities.length, isZero);

      // Update an existing target.
      a[1].testEntities.add(env.box.get(1)!); // foo
      expect(
          a[1].testEntities.map(strings), sameAsList(['foo', 'bar', 'bar2']));
      a[1].testEntities.removeWhere((e) => e.tString == 'bar');
      expect(a[1].testEntities.map(strings), sameAsList(['foo', 'bar2']));
      boxA.put(a[1]);
      a[1] = boxA.get(a[1].id!)!;
      expect(a[1].testEntities.map(strings), sameAsList(['foo', 'bar2']));

      // Insert a new target with some "source" entities pointing to it.
      var newA = RelatedEntityA(tInt: 4);
      expect(newA.testEntities.length, isZero);
      newA.testEntities.add(env.box.get(1)!); // foo
      newA.testEntities.add(TestEntity(tString: 'newly created from A'));
      boxA.put(newA);
      expect(newA.testEntities[0].id, 1);
      expect(newA.testEntities[1].id, 4);

      expect(env.box.get(4)!.tString, equals('newly created from A'));
      newA = boxA.get(newA.id!)!;
      expect(newA.testEntities.map(strings),
          sameAsList(['foo', 'newly created from A']));

      // The previous put also affects TestEntity(foo) - added target (tInt=4).
      expect(env.box.get(1)!.relManyA.map(toInt), sameAsList([1, 2, 4]));
    });

    test('query', () {
      final qb = boxA.query();
      qb.backlinkMany(
          TestEntity_.relManyA, TestEntity_.tString.startsWith('bar'));
      final query = qb.build();
      final a = query.find();
      expect(a.length, 1);
      expect(a.first.tInt, 2);
      query.close();
    });
  });

  test('trees', () {
    final box = env.store.box<TreeNode>();
    final root = TreeNode('R');
    root.children.addAll([TreeNode('R.1'), TreeNode('R.2')]);
    root.children[1].children.add(TreeNode('R.2.1'));
    box.put(root);
    expect(box.count(), 4);
    final read = box.get(1)!;
    root.expectSameAs(read);
  });

  test('cycles', () {
    final a = RelatedEntityA();
    final b = RelatedEntityB();
    a.relB.target = b;
    b.relA.target = a;
    env.store.box<RelatedEntityA>().put(a);

    final readB = env.store.box<RelatedEntityB>().get(b.id!)!;
    expect(a.relB.targetId, readB.id!);
    expect(readB.relA.target!.id, a.id);
  });
}

int toInt(dynamic e) => e.tInt as int;

void check<E>(ToMany<E> rel,
    {required List<int> items,
    required List<int> added,
    required List<int> removed}) {
  final relT = InternalToManyTestAccess(rel);
  expect(relT.items.map(toInt), unorderedEquals(items));
  expect(relT.added.map(toInt), unorderedEquals(added));
  expect(relT.removed.map(toInt), unorderedEquals(removed));
}

extension TreeNodeEquals on TreeNode {
  void expectSameAs(TreeNode other) {
    printOnFailure('Comparing tree nodes $path and ${other.path}');
    expect(id, other.id);
    expect(path, other.path);
    expect(parent.targetId, other.parent.targetId);
    expect(children.length, other.children.length);
    for (var i = 0; i < children.length; i++) {
      children[i].expectSameAs(other.children[i]);
    }
  }
}
