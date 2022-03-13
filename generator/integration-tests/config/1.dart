import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'lib/lib.dart';
import 'lib/custom/objectbox.g.dart';
import '../test_env.dart';
import '../common.dart';

void main() {
  late TestEnv<A> env;
  final jsonModel = readModelJson('lib/custom');
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
    expect(File('lib/custom/objectbox.g.dart').existsSync(), true);
    expect(File('lib/custom/objectbox-model.json').existsSync(), true);
  });

  // Very simple tests to ensure imports and generated code is correct.

  test('types', () {
    expect(property(model, 'A.text').type, OBXPropertyType.String);
  });

  test('db-ops-A', () {
    final box = env.store.box<A>();
    expect(box.count(), 0);

    final inserted = A();
    box.put(inserted);
    expect(inserted.id, 1);
    box.get(inserted.id!)!;
  });
}
