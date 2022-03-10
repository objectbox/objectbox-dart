import 'package:objectbox/src/relations/to_many.dart';
import 'package:test/test.dart';

import 'entity_immutable.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv('immutable_relations');
  });

  tearDown(() => env.closeAndDelete());

  group('ToOne', () {
    test('put', () {
      final Box<TestEntityImmutableRel> box = env.store.box();

      var src = TestEntityImmutableRel(tString: 'Hello');
      expect(src.relA.hasValue, isFalse);
      expect(src.relA.target, isNull);
      src.relA.target = RelatedImmutableEntityA(tInt: 42);
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

      src.relA.target!.relB.target = RelatedImmutableEntityB(tString: 'B1');

      // use the same target on two relations - must insert only once
      src.relB.target = src.relA.target!.relB.target;

      src = box.putImmutable(src);

      var read = box.get(1)!;
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
      env.store
          .box<RelatedImmutableEntityB>()
          .putImmutable(readRelARelB.target!);

      read = box.get(1)!;
      readRelA = read.relA;
      readRelARelB = readRelA.target!.relB;
      readRelARelBRelA = readRelARelB.target!.relA;
      expect(readRelARelBRelA.targetId, readRelA.targetId);

      // remove a relation, using [targetId]
      readRelARelB.targetId = 0;
      env.store.box<RelatedImmutableEntityA>().putImmutable(readRelA.target!);
      read = box.get(1)!;
      readRelA = read.relA;
      readRelARelB = readRelA.target!.relB;
      expect(readRelARelB.target, isNull);
      expect(readRelARelB.targetId, isZero);

      // remove a relation, using [target]
      read.relA.target = null;
      box.putImmutable(read);
      read = box.get(1)!;
      expect(read.relA.target, isNull);
      expect(read.relA.targetId, isZero);
    });

    test('putMany & simple ID query', () {
      final Box<TestEntityImmutableRel> box = env.store.box();
      final src = TestEntityImmutableRel(tString: 'Hello');
      src.relA.target = RelatedImmutableEntityA(tInt: 42);
      box.putImmutableMany([src, TestEntityImmutableRel(tString: 'there')]);
      expect(src.relA.targetId, 1);

      var query = box.query(TestEntityImmutableRel_.relA.equals(1)).build();
      expect(query.count(), 1);
      var read = query.find()[0];
      expect(read.tString, equals('Hello'));
      expect(read.relA.targetId, equals(1));
      query.close();

      query = box.query(TestEntityImmutableRel_.relA.equals(0)).build();
      expect(query.count(), 1);
      read = query.find()[0];
      expect(read.tString, equals('there'));
      expect(read.relA.targetId, equals(0));
      query.close();
    });

    test('query link', () {
      final box = env.store.box<TestEntityImmutableRel>();
      final src1 = TestEntityImmutableRel(tString: 'foo');
      src1.relA.target = RelatedImmutableEntityA(tInt: 5);
      final src2 = TestEntityImmutableRel(tString: 'bar');
      src2.relA.target = RelatedImmutableEntityA(tInt: 10);
      src2.relA.target!.relB.target = RelatedImmutableEntityB(tString: 'deep');
      box.putImmutableMany([src1, src2]);

      {
        final qb = box.query();
        qb.link(TestEntityImmutableRel_.relA,
            RelatedImmutableEntityA_.tInt.equals(10));
        final query = qb.build();
        final found = query.find();
        expect(found.length, 1);
        expect(found[0].tString, 'bar');
        query.close();
      }

      {
        final qb = box.query();
        qb.link(TestEntityImmutableRel_.relA).link(
            RelatedImmutableEntityA_.relB,
            RelatedImmutableEntityB_.tString.equals('deep'));
        final query = qb.build();
        final found = query.find();
        expect(found.length, 1);
        expect(found[0].tString, 'bar');
        query.close();
      }
    });
  });

  group('ToMany', () {
    TestEntityImmutableRel? src;
    setUp(() {
      src = TestEntityImmutableRel(tString: 'Hello');
    });

    test('put', () {
      final box = env.store.box<TestEntityImmutableRel>();
      expect(src!.relManyA, isNotNull);
      // Add three
      src!.relManyA.add(RelatedImmutableEntityA(tInt: 1));
      src!.relManyA.addAll([
        RelatedImmutableEntityA(tInt: 2),
        src!.relManyA[0],
        RelatedImmutableEntityA(tInt: 3)
      ]);
      box.putImmutable(src!);

      src = box.get(1);
      check(src!.relManyA.relation, items: [1, 2, 3], added: [], removed: []);

      // Remove one
      src!.relManyA.relation.removeWhere((e) => e.tInt == 2);
      check(src!.relManyA.relation, items: [1, 3], added: [], removed: [2]);
      box.putImmutable(src!);

      src = box.get(1);
      check(src!.relManyA.relation, items: [1, 3], added: [], removed: []);

      // Add existing again, add new one
      src!.relManyA.add(src!.relManyA[0]);
      src!.relManyA.add(RelatedImmutableEntityA(tInt: 4));
      check(src!.relManyA.relation,
          items: [1, 1, 3, 4], added: [1, 4], removed: []);
      box.putImmutable(src!);

      src = box.get(1);
      check(src!.relManyA.relation, items: [1, 3, 4], added: [], removed: []);

      // Remove one, add one
      src!.relManyA.relation.removeWhere((element) => element.tInt == 3);
      src!.relManyA.add(RelatedImmutableEntityA(tInt: 5));
      check(src!.relManyA.relation, items: [1, 4, 5], added: [5], removed: [3]);
      box.putImmutable(src!);
      src = box.get(1);
      check(src!.relManyA.relation, items: [1, 4, 5], added: [], removed: []);

      // Remove all
      src!.relManyA.clear();
      check(src!.relManyA.relation, items: [], added: [], removed: [1, 4, 5]);
      box.putImmutable(src!);
      src = box.get(1);
      check(src!.relManyA.relation, items: [], added: [], removed: []);
    });

    test('applyToDb', () {
      final box = env.store.box<TestEntityImmutableRel>();
      final entity = src!;
      expect(entity.relManyA, isNotNull);

      // Put with empty ToMany
      box.putImmutable(entity);
      check(entity.relManyA.relation, items: [], added: [], removed: []);

      // Add one
      entity.relManyA.add(RelatedImmutableEntityA(tInt: 1));
      entity.relManyA.applyToDb();
      check(entity.relManyA.relation, items: [1], added: [], removed: []);

      // Remove all
      entity.relManyA.clear();
      entity.relManyA.applyToDb();
      check(entity.relManyA.relation, items: [], added: [], removed: []);
    });

    test('applyToDb not attached throws', () {
      final entity = src!;
      expect(entity.relManyA, isNotNull);

      entity.relManyA.add(RelatedImmutableEntityA(tInt: 1));
      expect(
          entity.relManyA.applyToDb,
          throwsA(predicate((StateError e) => e.toString().contains(
              "ToMany relation field not initialized. Don't call applyToDb() on new objects, use box.put() instead."))));
    });

    test("don't load old data when just adding", () {
      final box = env.store.box<TestEntityImmutableRel>();
      expect(src!.relManyA, isNotNull);
      src!.relManyA.add(RelatedImmutableEntityA(tInt: 1));
      src!.relManyA.addAll([
        RelatedImmutableEntityA(tInt: 2),
        src!.relManyA[0],
        RelatedImmutableEntityA(tInt: 3)
      ]);
      box.putImmutable(src!);

      src = box.get(1);
      check(src!.relManyA.relation, items: [1, 2, 3], added: [], removed: []);
      expect(InternalToManyTestAccess(src!.relManyA).itemsLoaded, isTrue);

      src = box.get(1);
      expect(InternalToManyTestAccess(src!.relManyA).itemsLoaded, isFalse);
      final rel = RelatedImmutableEntityA(tInt: 4);
      src!.relManyA.add(rel);
      src!.relManyA.addAll([RelatedImmutableEntityA(tInt: 5), rel]);
      expect(InternalToManyTestAccess(src!.relManyA).itemsLoaded, isFalse);
      src = box.putImmutable(src!);
      expect(InternalToManyTestAccess(src!.relManyA).itemsLoaded, isFalse);
      src = box.get(1);
      check(src!.relManyA.relation,
          items: [1, 2, 3, 4, 5], added: [], removed: []);
    });
  });

  group('to-one backlink', () {
    late Box<RelatedImmutableEntityB> boxB;
    late Box<TestEntityImmutableRel> box;
    setUp(() {
      boxB = env.store.box();
      box = env.store.box();
      box.putImmutable(TestEntityImmutableRel(tString: 'foo')
        ..relB.target = RelatedImmutableEntityB(tString: 'foo B'));
      box.putImmutable(TestEntityImmutableRel(tString: 'bar')
        ..relB.target = RelatedImmutableEntityB(tString: 'bar B'));
      box.putImmutable(
          TestEntityImmutableRel(tString: 'bar2')..relB.targetId = 2);

      boxB.putImmutable(RelatedImmutableEntityB(tString: 'not referenced'));
    });

    test('put and get', () {
      final List<RelatedImmutableEntityB?> b = boxB.getAll();
      expect(b[0]!.id, 1);
      expect(b[0]!.tString, 'foo B');
      expect(b[1]!.id, 2);
      expect(b[1]!.tString, 'bar B');
      expect(b[2]!.id, 3);
      expect(b[2]!.tString, 'not referenced');

      final strings = (TestEntityImmutableRel? e) => e!.tString;
      expect(b[0]!.testEntities.map(strings), sameAsList(['foo']));
      expect(b[1]!.testEntities.map(strings), sameAsList(['bar', 'bar2']));
      expect(b[2]!.testEntities.length, isZero);

      // Update an existing target.
      b[1]!.testEntities.add(box.get(1)!); // foo
      expect(
          b[1]!.testEntities.map(strings), sameAsList(['foo', 'bar', 'bar2']));
      b[1]!.testEntities.removeWhere((e) => e.tString == 'bar');
      expect(b[1]!.testEntities.map(strings), sameAsList(['foo', 'bar2']));
      boxB.putImmutable(b[1]!);
      b[1] = boxB.get(b[1]!.id!);
      expect(b[1]!.testEntities.map(strings), sameAsList(['foo', 'bar2']));

      // Insert a new target, already with some "source" entities pointing to it.
      var newB = RelatedImmutableEntityB();
      expect(newB.testEntities.length, isZero);
      newB.testEntities.add(box.get(1)!); // foo
      newB.testEntities
          .add(TestEntityImmutableRel(tString: 'newly created from B'));
      newB = boxB.putImmutable(newB);
      expect(newB.testEntities[0].id, 1);
      expect(newB.testEntities[1].id, 4);

      expect(box.get(4)!.tString, equals('newly created from B'));
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
      var b = RelatedImmutableEntityB();
      b.testEntities.add(TestEntityImmutableRel(tString: 'Foo'));
      b = boxB.putImmutable(b);
      expect(b.testEntities.length, 1);
    });

    test('query', () {
      final qb = boxB.query();
      qb.backlink(
        TestEntityImmutableRel_.relB,
        TestEntityImmutableRel_.tString.startsWith('bar'),
      );
      final query = qb.build();
      final b = query.find();
      expect(b.length, 1);
      expect(b.first.tString, 'bar B');
      query.close();
    });
  });

  group('to-many backlink', () {
    late Box<RelatedImmutableEntityA> boxA;
    late Box<TestEntityImmutableRel> box;
    setUp(() {
      boxA = env.store.box();
      box = env.store.box();
      box.putImmutable(TestEntityImmutableRel(tString: 'foo')
        ..relManyA.add(RelatedImmutableEntityA(tInt: 1)));
      box.putImmutable(TestEntityImmutableRel(tString: 'bar')
        ..relManyA.add(RelatedImmutableEntityA(tInt: 2)));
      box.putImmutable(
          TestEntityImmutableRel(tString: 'bar2')..relManyA.add(boxA.get(2)!));

      boxA.putImmutable(RelatedImmutableEntityA(tInt: 3)); // not referenced
    });

    test('put and get', () {
      final a = boxA.getAll();
      expect(a[0].id, 1);
      expect(a[0].tInt, 1);
      expect(a[1].id, 2);
      expect(a[1].tInt, 2);
      expect(a[2].id, 3);
      expect(a[2].tInt, 3);

      final strings = (TestEntityImmutableRel? e) => e!.tString;
      expect(a[0].testEntities.map(strings), sameAsList(['foo']));
      expect(a[1].testEntities.map(strings), sameAsList(['bar', 'bar2']));
      expect(a[2].testEntities.length, isZero);

      // Update an existing target.
      a[1].testEntities.add(box.get(1)!); // foo
      expect(
          a[1].testEntities.map(strings), sameAsList(['foo', 'bar', 'bar2']));
      a[1].testEntities.removeWhere((e) => e.tString == 'bar');
      expect(a[1].testEntities.map(strings), sameAsList(['foo', 'bar2']));
      a[1] = boxA.putImmutable(a[1]);
      a[1] = boxA.get(a[1].id!)!;
      expect(a[1].testEntities.map(strings), sameAsList(['foo', 'bar2']));

      // Insert a new target with some "source" entities pointing to it.
      var newA = RelatedImmutableEntityA(tInt: 4);
      expect(newA.testEntities.length, isZero);
      newA.testEntities.add(box.get(1)!); // foo
      newA.testEntities
          .add(TestEntityImmutableRel(tString: 'newly created from A'));
      newA = boxA.putImmutable(newA);
      expect(newA.testEntities[0].id, 1);
      expect(newA.testEntities[1].id, 4);

      expect(box.get(4)!.tString, equals('newly created from A'));
      newA = boxA.get(newA.id!)!;
      expect(newA.testEntities.map(strings),
          sameAsList(['foo', 'newly created from A']));

      // The previous put also affects TestEntityImmutableRel(foo) - added target (tInt=4).
      expect(box.get(1)!.relManyA.map(toInt), sameAsList([1, 2, 4]));
    });

    test('query', () {
      final qb = boxA.query();
      qb.backlinkMany(TestEntityImmutableRel_.relManyA,
          TestEntityImmutableRel_.tString.startsWith('bar'));
      final query = qb.build();
      final a = query.find();
      expect(a.length, 1);
      expect(a.first.tInt, 2);
      query.close();
    });
  });

  test('trees', () {
    final box = env.store.box<TreeNodeImmutable>();
    var root = TreeNodeImmutable('R');
    root.children.addAll([TreeNodeImmutable('R.1'), TreeNodeImmutable('R.2')]);
    root.children[1].children.add(TreeNodeImmutable('R.2.1'));
    root = box.putImmutable(root);
    expect(box.count(), 4);
    final read = box.get(1)!;
    root.expectSameAs(read);
  });

  test('cycles', () {
    var a = RelatedImmutableEntityA();
    var b = RelatedImmutableEntityB();
    a.relB.target = b;
    b.relA.target = a;
    a = env.store.box<RelatedImmutableEntityA>().putImmutable(a);
    b = a.relB.target!;

    final readB = env.store.box<RelatedImmutableEntityB>().get(b.id!)!;
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

extension TreeNodeEquals on TreeNodeImmutable {
  void expectSameAs(TreeNodeImmutable other) {
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
