import 'package:test/test.dart';
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
    expect(model.entities[0].properties.length, 1);
    expect(model.entities[0].properties[0].name, 'id');
    expect(model.entities[0].lastPropertyId.toString(), '4:1004');

    expect(model.entities[0].relations.length, 0);

    expect(model.lastEntityId.toString(), '2:2000');
    // lastRelationId is kept even if the relation itself is removed.
    expect(model.lastRelationId.toString(), '1:1005');

    expect(jsonModel.retiredEntityUids.length, 1);
    expect(jsonModel.retiredPropertyUids.length, 5);
    expect(jsonModel.retiredIndexUids.length, 1);
  });
}
