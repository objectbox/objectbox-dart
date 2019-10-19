import "dart:io";
import "package:test/test.dart";

import "helpers.dart";

void main() async {
  group("generator", () {
    tearDown(() {
      File("objectbox-model.json").deleteSync();
    });

    testGeneratorOutput("single_entity");
  });
}
