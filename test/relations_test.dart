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
    expect(read.relA.target.tInt, 42);
    expect(read.relA.target.relB.target.tString, equals('B1'));

    // attach an existing item
    expect(read.relA.target.relB.target.relA.hasValue, isFalse);
    read.relA.target.relB.target.relA.target = read.relA.target;
    expect(read.relA.target.relB.target.relA.hasValue, isTrue);
    expect(read.relA.target.relB.target.relA.targetId, read.relA.targetId);
    env.store.box<RelatedEntityB>().put(read.relA.target.relB.target);

    read = env.box.get(1);
    expect(read.relA.target.relB.target.relA.targetId, read.relA.targetId);

    // remove a relation, using [targetId]
    read.relA.target.relB.targetId = 0;
    env.store.box<RelatedEntityA>().put(read.relA.target);
    read = env.box.get(1);
    expect(read.relA.target.relB.target, isNull);
    expect(read.relA.target.relB.targetId, isZero);

    // remove a relation, using [target]
    read.relA.target= null;
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
    env.box.put(src);

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
}
