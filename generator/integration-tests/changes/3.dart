import 'dart:io';
import 'package:io/io.dart';
import 'package:test/test.dart';
import 'lib/lib.dart';
import 'lib/objectbox.g.dart';
import '../common.dart';

void main() {
  ModelDefinition defs = getObjectBoxModel();
  ModelInfo jsonModel = readModelJson("lib");
  commonModelTests(defs, jsonModel);

  test("ensure current model looks like expected", () {
    final model = defs.model;

    expect(model.entities.length, 2);

    expect(model.entities[0].name, "A");
    expect(model.entities[0].properties.length, 3);
    expect(model.entities[0].properties[0].name, "id");
    expect(model.entities[0].properties[1].name, "text1");
    expect(model.entities[0].properties[2].name, "renamed");

    expect(model.entities[1].name, "Renamed");
    expect(model.entities[1].properties.length, 2);
    expect(model.entities[1].properties[0].name, "id");
    expect(model.entities[1].properties[1].name, "value");

    expect(model.lastEntityId.toString(), model.entities[1].id.toString());

    expect(jsonModel.retiredEntityUids.length, 0);
    expect(jsonModel.retiredPropertyUids.length, 0);
    expect(jsonModel.retiredIndexUids.length, 0);
  });

  /// test the data has been migrated from the previous version and prepare new data for the next step
  test("data", () {
    final srcDir = Directory("objectbox.2");
    final tarDir = Directory("objectbox.3");

    expect(srcDir.existsSync(), isTrue);
    if (tarDir.existsSync()) tarDir.deleteSync(recursive: true);
    copyPathSync(srcDir.path, tarDir.path);

    final store = Store(defs, directory: tarDir.path);
    final boxA = Box<A>(store);
    final boxB = Box<Renamed>(store);

    expect(boxA.count(), 3);
    expect(boxB.count(), 1);

    {
      final objects = boxA.getAll();
      expect(objects[0].text1, "foo");
      expect(objects[0].renamed, isNull);
      expect(objects[1].text1, isNull);
      expect(objects[1].renamed, "bar");
      expect(objects[2].text1, "lorem");
      expect(objects[2].renamed, "ipsum");
    }

    {
      final objects = boxB.getAll();
      expect(objects[0].value, true);
    }

    store.close();
  });
}
