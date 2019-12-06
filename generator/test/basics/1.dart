import 'dart:io';
import 'lib/lib.dart';
import 'lib/objectbox.g.dart';
import 'package:test/test.dart';
import '../test_env.dart';
import '../common.dart';

void main() {
  TestEnv<A> env;
  ModelDefinition defs = getObjectBoxModel();

  setUp(() {
    env = TestEnv<A>(defs);
  });

  tearDown(() {
    env.close();
  });

  commonModelTests(defs, readModelJson("lib"));

  test("project must be generated properly", () {
    expect(TestEnv.dir.existsSync(), true);
    expect(File("lib/objectbox.g.dart").existsSync(), true);
    expect(File("lib/objectbox-model.json").existsSync(), true);
  });
}
