import 'dart:io';
import 'lib/lib.dart';
import 'lib/objectbox.g.dart';
import 'package:test/test.dart';
import '../test_env.dart';
import '../common.dart';
import 'package:objectbox/src/bindings/bindings.dart';

void main() {
  TestEnv<A> env;
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
  });
}
