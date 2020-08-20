import 'dart:io';
import 'package:test/test.dart';
import 'lib/lib.dart';
import 'lib/objectbox.g.dart';
import '../common.dart';

void main() {
  final defs = getObjectBoxModel();
  final jsonModel = readModelJson('lib');
  commonModelTests(defs, jsonModel);

  test('ensure current model looks like expected', () {
    final model = defs.model;

    expect(model.entities.length, 1);
    expect(model.entities[0].name, 'A');
    expect(model.entities[0].properties.length, 2);
    expect(model.entities[0].properties[0].name, 'id');
    expect(model.entities[0].properties[1].name, 'text1');

    expect(model.lastEntityId.toString(), model.entities[0].id.toString());

    expect(jsonModel.retiredEntityUids.length, 0);
    expect(jsonModel.retiredPropertyUids.length, 0);
    expect(jsonModel.retiredIndexUids.length, 0);
  });

  /// this test doesn't really test anything, it just prepares the contents of the database for the next phase
  test('data', () {
    // this is the first test so let's delete the database directory beforehand
    final dir = Directory('objectbox.1');
    if (dir.existsSync()) dir.deleteSync(recursive: true);

    final store = Store(defs, directory: dir.path);
    final box = Box<A>(store);

    final object = A()..text1 = 'foo';
    box.put(object);
    store.close();
  });
}
