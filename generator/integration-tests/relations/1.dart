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

  setUp(() {
    env = TestEnv<A>(defs);
  });

  tearDown(() => env.close());

  commonModelTests(defs, jsonModel);

  test('project must be generated properly', () {
    expect(TestEnv.dir.existsSync(), true);
    expect(File('lib/objectbox.g.dart').existsSync(), true);
    expect(File('lib/objectbox-model.json').existsSync(), true);
  });
}
