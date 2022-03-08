import 'dart:io';

import 'package:test/test.dart';

import '../common.dart';
import '../test_env.dart';
import 'lib/lib.dart';
import 'lib/objectbox.g.dart';

void main() {
  late TestEnv<AnnotatedGetters> env;
  final jsonModel = readModelJson('lib');
  final defs = getObjectBoxModel();
  final model = defs.model;

  setUp(() {
    env = TestEnv<AnnotatedGetters>(defs);
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

  test('annotations from getters are read', () {
    // @Property on getter changes type, @Index adds index flag
    var prop = property(model, 'AnnotatedGetters.prop');
    expect(prop.type, OBXPropertyType.Int);
    expect(prop.flags, OBXPropertyFlags.INDEXED);
    // @Transient on getter ignores property
    expect(() => property(model, 'AnnotatedGetters.ignored'),
        throwsA(isStateError));
  });
}
