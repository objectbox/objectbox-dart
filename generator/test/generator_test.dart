import "dart:io";
import "package:test/test.dart";
import 'package:glob/glob.dart' show Glob;
import 'package:path/path.dart';

import "helpers.dart";

void main() async {
  group("generator", () {
    tearDown(() {
      File("objectbox-model.json").deleteSync();
    });

    final updateExpected = Platform.environment['GENERATOR'] == "update-expected";

    for (var testCase in Glob("test/cases/*").listSync()) {
      testGeneratorOutput(basename(testCase.path), updateExpected);
    }
  });
}
