import 'dart:io';
import 'package:test/test.dart';
import '../test_env.dart';

void main() {
  // this is actually a meta test - that `git clean -fX` is run
  test('project must be clean before generating the code', () {
    expect(TestEnv.dir.existsSync(), false);
    expect(File('lib/objectbox.g.dart').existsSync(), false);
    expect(File('lib/objectbox-model.json').existsSync(), false);
  });
}
