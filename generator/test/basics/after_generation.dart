import 'dart:io';
import 'lib/lib.dart';
import 'lib/objectbox.g.dart';
import 'package:test/test.dart';
import '../test_env.dart';

void main() {
  TestEnv<Note> env;

  setUp(() {
    env = TestEnv<Note>(getObjectBoxModel());
  });

  tearDown(() {
    env.close();
  });

  test("project must be generated properly", () {
    expect(TestEnv.dir.existsSync(), true);
    expect(new File("lib/objectbox.g.dart").existsSync(), true);
    expect(new File("lib/objectbox-model.json").existsSync(), true);
  });

  test("model bindings", () {
    expect(env.model.bindings.length, equals(1));
  });
}
