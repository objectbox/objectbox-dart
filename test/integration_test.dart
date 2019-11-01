import "package:test/test.dart";
import "package:objectbox/integration_test.dart";

void main() {
  test("int64", IntegrationTest.int64);
  test("model", IntegrationTest.model);
}
