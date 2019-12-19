import 'package:test/test.dart';
import 'lib/objectbox.g.dart';
import '../common.dart';

void main() {
  ModelDefinition defs = getObjectBoxModel();
  ModelInfo jsonModel = readModelJson("lib");
  commonModelTests(defs, jsonModel);

  test("ensure current model looks like expected", () {
    final model = defs.model;

    expect(model.entities.length, 1);

    expect(model.entities[0].name, "A");
    expect(model.entities[0].properties.length, 1);
    expect(model.entities[0].properties[0].name, "id");
    expect(model.entities[0].lastPropertyId.toString(), "3:1003");

    expect(model.lastEntityId.toString(), "2:2000");

    expect(jsonModel.retiredEntityUids.length, 1);
    expect(jsonModel.retiredPropertyUids.length, 4);
    expect(jsonModel.retiredIndexUids.length, 0);
  });
}
