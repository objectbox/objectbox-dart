import 'package:objectbox/internal.dart';
import 'package:test/test.dart';

void main() {
  test('model removeEntity retires relation and index UIDs', () {
    final model = ModelInfo.empty();
    final entity = model.createEntity('A');
    final prop = entity.createProperty('indexedProp');
    prop.indexId = model.createIndexId();
    final rel = entity.createRelation('rel');
    model.createEntity('B');

    model.removeEntity(entity);

    // Must still validate: lastRelationId and lastIndexId now only match
    // retired UIDs. Missing relation UID retirement previously threw
    // "lastRelationId ... does not match any standalone relation", breaking
    // every generator run after deleting such an entity.
    model.validate();
    expect(model.retiredEntityUids, contains(entity.id.uid));
    expect(model.retiredPropertyUids, contains(prop.id.uid));
    expect(model.retiredIndexUids, contains(prop.indexId!.uid));
    expect(model.retiredRelationUids, contains(rel.id.uid));
  });

  test('model UID generation', () {
    final model = ModelInfo.empty();
    final uid1 = model.generateUid();
    final uid2 = model.generateUid();
    expect(uid1, isNot(equals(uid2)));
    expect(uid1, isNot(equals(0)));
    expect(uid2, isNot(equals(0)));

    var foundLargeUid = false;
    for (var i = 0; i < 1000 && !foundLargeUid; i++) {
      foundLargeUid = model.generateUid() > (1 << 32);
    }
    expect(foundLargeUid, isTrue);
  });
}
