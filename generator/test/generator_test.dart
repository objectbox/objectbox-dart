import "dart:io";
import "package:test/test.dart";

import "helpers.dart";

void main() async {
  group("generator", () {
    tearDown(() {
      File("objectbox-model.json").deleteSync();
    });

    Map<String, String> envVars = Platform.environment;
    testGeneratorOutput("single_entity", envVars['GENERATOR'] == "update-expected");
  });
}
