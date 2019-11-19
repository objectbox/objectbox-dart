import "dart:io";
import "package:test/test.dart";
import 'package:glob/glob.dart' show Glob;
import 'package:path/path.dart';

import "helpers.dart";

Map<String, String> getArgs() {
  final result = Map<String, String>();

  // accept GENERATOR environment variable as a list of arguments, e.g. GENERATOR=update-expected,target:single_entity
  final env = Platform.environment['GENERATOR'] ?? "";

  env.split(",").forEach((part) {
    final kvPair = part.split(":");
    if (kvPair.length < 2) {
      result[part] = "";
    } else {
      result[kvPair[0]] = kvPair.sublist(1).join(":"); // join() just in case there were multiple ":"
    }
  });

  return result;
}

void main() async {
  group("generator", () {
    tearDown(() {
      File("objectbox-model.json").deleteSync();
    });

    final args = getArgs();
    final updateExpected = args["update-expected"] != null;

    for (var testCase in Glob("test/cases/*").listSync()) {
      final name = basename(testCase.path);
      if (args["target"] == null || args["target"] == name) {
        testGeneratorOutput(name, updateExpected);
      }
    }
  });
}
