import 'dart:io';
import 'package:test/test.dart';
import '../test_env.dart';

void main() {
  test("project must be clean before running the test", () {
    expect(TestEnv.dir.existsSync(), false);
    expect(new File("lib/objectbox.g.dart").existsSync(), false);
    expect(new File("lib/objectbox-model.json").existsSync(), false);
  });
}
