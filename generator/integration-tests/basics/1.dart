import 'dart:io';
import 'lib/lib.dart';
import 'lib/objectbox.g.dart';
import 'package:test/test.dart';
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

  test('sync annotation', () {
    expect(entity(model, 'A').flags, equals(0));
    expect(entity(jsonModel, 'A').flags, equals(0));

    expect(entity(model, 'D').flags, equals(OBXEntityFlags.SYNC_ENABLED));
    expect(entity(jsonModel, 'D').flags, equals(OBXEntityFlags.SYNC_ENABLED));

    expect(
      entity(model, 'E').flags,
      equals(OBXEntityFlags.SYNC_ENABLED | OBXEntityFlags.SHARED_GLOBAL_IDS),
    );
    expect(
      entity(jsonModel, 'E').flags,
      equals(OBXEntityFlags.SYNC_ENABLED | OBXEntityFlags.SHARED_GLOBAL_IDS),
    );
  });

  test('types', () {
    expect(property(model, 'T.tBool').type, OBXPropertyType.Bool);
    expect(property(model, 'T.tByte').type, OBXPropertyType.Byte);
    expect(property(model, 'T.tShort').type, OBXPropertyType.Short);
    expect(property(model, 'T.tChar').type, OBXPropertyType.Char);
    expect(property(model, 'T.tInt').type, OBXPropertyType.Int);
    expect(property(model, 'T.tLong').type, OBXPropertyType.Long);
    expect(property(model, 'T.tFloat').type, OBXPropertyType.Float);
    expect(property(model, 'T.tDouble').type, OBXPropertyType.Double);
    expect(property(model, 'T.tString').type, OBXPropertyType.String);
    expect(property(model, 'T.tDate').type, OBXPropertyType.Date);
    expect(property(model, 'T.tDateNano').type, OBXPropertyType.DateNano);

    expect(property(model, 'T.tListInt').type, OBXPropertyType.ByteVector);
    expect(property(model, 'T.tInt8List').type, OBXPropertyType.ByteVector);
    expect(property(model, 'T.tUint8List').type, OBXPropertyType.ByteVector);

    expect(property(model, 'T.tCharList').type, OBXPropertyType.CharVector);

    expect(property(model, 'T.tShortList').type, OBXPropertyType.ShortVector);
    expect(property(model, 'T.tInt16List').type, OBXPropertyType.ShortVector);
    expect(property(model, 'T.tUint16List').type, OBXPropertyType.ShortVector);

    expect(property(model, 'T.tIntList').type, OBXPropertyType.IntVector);
    expect(property(model, 'T.tInt32List').type, OBXPropertyType.IntVector);
    expect(property(model, 'T.tUint32List').type, OBXPropertyType.IntVector);

    expect(property(model, 'T.tLongList').type, OBXPropertyType.LongVector);
    expect(property(model, 'T.tInt64List').type, OBXPropertyType.LongVector);
    expect(property(model, 'T.tUint64List').type, OBXPropertyType.LongVector);

    expect(property(model, 'T.tFloatList').type, OBXPropertyType.FloatVector);
    expect(property(model, 'T.tFloat32List').type, OBXPropertyType.FloatVector);

    expect(property(model, 'T.tDoubleList').type, OBXPropertyType.DoubleVector);
    expect(
      property(model, 'T.tFloat64List').type,
      OBXPropertyType.DoubleVector,
    );

    expect(property(model, 'T.tListString').type, OBXPropertyType.StringVector);

    expect(property(model, 'T.id').isSigned, isTrue);
    expect(property(model, 'T.tByte').isSigned, isTrue);
    expect(property(model, 'T.tShort').isSigned, isTrue);
    expect(property(model, 'T.tChar').isSigned, isTrue);
    expect(property(model, 'T.tInt').isSigned, isTrue);
    expect(property(model, 'T.tLong').isSigned, isTrue);

    expect(property(model, 'Unsigned.id').isSigned, isTrue);
    expect(property(model, 'Unsigned.tByte').isSigned, isFalse);
    expect(property(model, 'Unsigned.tShort').isSigned, isFalse);
    expect(property(model, 'Unsigned.tChar').isSigned, isFalse);
    expect(property(model, 'Unsigned.tInt').isSigned, isFalse);
    expect(property(model, 'Unsigned.tLong').isSigned, isFalse);
  });
}
