import 'dart:io';

import 'package:io/io.dart';
import 'package:test/test.dart';

import '../common.dart';
import 'lib/lib.dart';
import 'lib/objectbox.g.dart';

void main() {
  final defs = getObjectBoxModel();
  final jsonModel = readModelJson('lib');
  commonModelTests(defs, jsonModel);

  test('ensure current model looks like expected', () {
    final model = defs.model;

    expect(model.entities.length, 3);

    expect(model.entities[0].name, 'A');
    expect(model.entities[0].properties.length, 4);
    expect(model.entities[0].properties[0].name, 'id');
    expect(model.entities[0].properties[1].name, 'text1');
    expect(model.entities[0].properties[2].name, 'renamed');
    expect(model.entities[0].properties[3].name, 'renamedRelOneId');
    expect(model.entities[0].properties[3].relationTarget, 'Renamed');

    expect(model.entities[0].relations.length, 1);
    expect(model.entities[0].relations[0].name, 'renamedRelMany');
    expect(model.entities[0].relations[0].targetId.toString(), '2:2000');

    expect(model.entities[1].name, 'Renamed');
    expect(model.entities[1].properties.length, 2);
    expect(model.entities[1].properties[0].name, 'id');
    expect(model.entities[1].properties[1].name, 'value');

    expect(model.entities[2].name, 'A1');
    expect(model.entities[2].properties.length, 1);
    expect(model.entities[2].properties[0].name, 'id');

    expect(model.lastEntityId.toString(), model.entities[2].id.toString());

    expect(jsonModel.retiredEntityUids.length, 0);
    expect(jsonModel.retiredPropertyUids.length, 0);
    expect(jsonModel.retiredIndexUids.length, 0);
  });

  /// test the data has been migrated from the previous version and prepare new data for the next step
  test('data', () {
    final srcDir = Directory('objectbox.3');
    final tarDir = Directory('objectbox.4');

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
      expect(objects[0].text1, 'foo');
      expect(objects[0].renamed, isNull);
      expect(objects[1].text1, isNull);
      expect(objects[1].renamed, 'bar');
      expect(objects[2].text1, 'lorem');
      expect(objects[2].renamed, 'ipsum');
    }

    {
      final objects = boxB.getAll();
      expect(objects[0].value, true);
    }

    store.close();
  });
}
