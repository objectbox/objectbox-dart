import 'dart:io';
import 'package:objectbox/objectbox.dart';

import 'lib/lib.dart';
import 'lib/objectbox.g.dart';
import 'package:test/test.dart';
import '../test_env.dart';
import '../common.dart';

void main() {
  late TestEnv<A> env;
  final jsonModel = readModelJson('lib');
  final defs = getObjectBoxModel();

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

  test('property flags', () {
    expect(property(jsonModel, 'A.id').flags, equals(OBXPropertyFlags.ID));
    expect(property(jsonModel, 'A.indexed').flags,
        equals(OBXPropertyFlags.INDEXED));
    expect(property(jsonModel, 'A.unique').flags,
        equals(OBXPropertyFlags.INDEX_HASH | OBXPropertyFlags.UNIQUE));
    expect(property(jsonModel, 'A.uniqueValue').flags,
        equals(OBXPropertyFlags.INDEXED | OBXPropertyFlags.UNIQUE));
    expect(property(jsonModel, 'A.uniqueHash').flags,
        equals(OBXPropertyFlags.INDEX_HASH | OBXPropertyFlags.UNIQUE));
    expect(property(jsonModel, 'A.uniqueHash64').flags,
        equals(OBXPropertyFlags.INDEX_HASH64 | OBXPropertyFlags.UNIQUE));
    expect(property(jsonModel, 'A.uid').flags,
        equals(OBXPropertyFlags.INDEXED | OBXPropertyFlags.UNIQUE));
  });
}
