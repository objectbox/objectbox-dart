import 'dart:io';

import 'package:test/test.dart';

import '../test_env.dart';
import '../common.dart';
import 'lib/json.dart';
import 'lib/frozen.dart';
import 'lib/objectbox.g.dart';

void main() {
  commonModelTests(getObjectBoxModel(), readModelJson('lib'));

  test('project must be generated properly', () {
    expect(File('lib/objectbox.g.dart').existsSync(), true);
    expect(File('lib/objectbox-model.json').existsSync(), true);
  });

  setupTestsFor(JsonEntity(id: 0, str: 'foo', date: DateTime.now()));
  setupTestsFor(FrozenEntity(id: 1, str: 'foo', date: DateTime.now()));
}

void setupTestsFor<EntityT>(EntityT newObject) {
  group('${EntityT}', () {
    late TestEnv<EntityT> env;
    setUp(() => env = TestEnv(getObjectBoxModel()));
    tearDown(() => env.close());

    test('read/write', () {
      env.box.put(newObject);
      env.box.get(1);
    });
  });
}
