import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'lib/lib.dart';
import 'lib/objectbox.g.dart';
import '../test_env.dart';
import '../common.dart';

void main() {
  late TestEnv<A> env;
  final jsonModel = readModelJson('lib');
  final defs = getObjectBoxModel();
  final model = defs.model;

  setUp(() {
    env = TestEnv<A>(defs);
  });

  tearDown(() {
    env.close();
  });

  commonModelTests(defs, jsonModel);

  test('project must be generated properly', () {
    expect(TestEnv.dir.existsSync(), true);
    expect(File('lib/objectbox.g.dart').existsSync(), true);
    expect(File('lib/objectbox-model.json').existsSync(), true);
  });

  test('types', () {
    expect(property(model, 'A.tBool').type, OBXPropertyType.Bool);
    expect(property(model, 'A.tLong').type, OBXPropertyType.Long);
    expect(property(model, 'A.tDouble').type, OBXPropertyType.Double);
    expect(property(model, 'A.tString').type, OBXPropertyType.String);
    expect(property(model, 'A.tDate').type, OBXPropertyType.Date);
    expect(property(model, 'A.tDateNano').type, OBXPropertyType.DateNano);
    expect(property(model, 'A.tListInt').type, OBXPropertyType.ByteVector);
    expect(property(model, 'A.tInt8List').type, OBXPropertyType.ByteVector);
    expect(property(model, 'A.tUint8List').type, OBXPropertyType.ByteVector);
    expect(property(model, 'A.tListString').type, OBXPropertyType.StringVector);
  });

  test('db-ops-A', () {
    final box = env.store.box<A>();
    expect(box.count(), 0);

    expect(
      () => box.put(
        A(0, 0, 0, '', 0, 0, [], Uint8List(0), [], false, Int8List(0)),
      ),
      throwsA(
        predicate(
          (ArgumentError e) => e.toString().contains('You must assign an ID'),
        ),
      ),
    );

    final inserted = A(
      42,
      1,
      2,
      'foo',
      3,
      4,
      [5, 6],
      Uint8List(1),
      ['foo', 'bar'],
      true,
      Int8List(2),
    );
    box.put(inserted);
    final read = box.get(inserted.id)!;
    expect(read.tBool, inserted.tBool);
    expect(read.tLong, inserted.tLong);
    expect(read.tDouble, inserted.tDouble);
    expect(read.tString, inserted.tString);
    expect(read.tDate, inserted.tDate);
    expect(read.tDateNano, inserted.tDateNano);
    expect(read.tListInt, inserted.tListInt);
    expect(read.tInt8List, inserted.tInt8List);
    expect(read.tUint8List, inserted.tUint8List);
    expect(read.tListString, inserted.tListString);
  });

  test('db-ops-B', () {
    final box = env.store.box<B>();
    expect(box.count(), 0);

    final inserted = B();
    box.put(inserted);
    expect(inserted.id, 1);
    box.get(inserted.id)!;
  });
}
