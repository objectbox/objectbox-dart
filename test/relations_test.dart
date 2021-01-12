import 'dart:typed_data';

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

    expect(src.relA.hasValue, isFalse);
    expect(src.relA.target, isNull);
    src.relA.target = RelatedEntityA(tInt: 42);
    expect(src.relA.hasValue, isTrue);
    expect(src.relA.target, isNotNull);
    expect(src.relA.targetId, isZero);
    expect(src.relA.target.tInt, 42);

    src.relA.target.relB.attach(env.store);
    src.relA.target.relB.target = RelatedEntityB(tString: 'B1');

    // TODO wait for #62, now duplicates the object without object ID assignment
    // src.relB.target = src.relA.target.relB.target;

    env.box.put(src);

    var read = env.box.get(1);
    expect(read.tString, equals(src.tString));
    expect(read.relA.hasValue, isTrue);
    expect(read.relA.targetId, 1);
    var readRelA = read.relA;
    expect(readRelA.target.tInt, 42);
    var readRelARelB = readRelA.target.relB;
    expect(readRelARelB.target.tString, equals('B1'));

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
}
