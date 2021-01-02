import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:objectbox/objectbox.dart';
import 'entity.dart';
import 'test_env.dart';

void main() {
  /*late final*/ TestEnv env;

  setUp(() {
    env = TestEnv('box');
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

    final read = env.box.get(1);
    expect(read.tString, equals(src.tString));
    expect(read.relA.hasValue, isTrue);
    expect(read.relA.targetId, 1);
    expect(read.relA.target.tInt, 42);
    expect(read.relA.target.relB.target.tString, equals('B1'));
  });
}
