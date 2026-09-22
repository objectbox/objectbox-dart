import 'package:objectbox/internal.dart';
import 'package:test/test.dart';

void main() {
  test('model create prevents duplicates of existing UIDs', () {
    final model = ModelInfo.empty();
    final entity = model.createEntity('A');
    final prop = entity.createProperty('indexedProp');
    prop.indexId = model.createIndexId();
    final rel = entity.createRelation('rel');

    // The UIDs of the older items must be known to the model so
    // duplicate-UID guards and generateUid() can not collide with them.
    expect(model.containsUid(entity.id.uid), isTrue);
    expect(model.containsUid(prop.id.uid), isTrue);
    expect(model.containsUid(prop.indexId!.uid), isTrue);
    expect(model.containsUid(rel.id.uid), isTrue);

    // Add more of each kind to make sure containsUid checks the UIDs in
    // entities and not just lastEntityId/lastPropertyId/lastIndexId/
    // lastRelationId.uid.
    model.createEntity('B');
    entity.createProperty('otherProp');
    final prop2 = entity.createProperty('otherIndexedProp');
    prop2.indexId = model.createIndexId();
    entity.createRelation('otherRel');

    // containsUid should still find the (no longer "last") duplicate UIDs
    // within entities.
    expect(model.containsUid(entity.id.uid), isTrue);
    expect(model.containsUid(prop.id.uid), isTrue);
    expect(model.containsUid(prop.indexId!.uid), isTrue);
    expect(model.containsUid(rel.id.uid), isTrue);

    final uidExists = throwsA(
      isA<StateError>().having(
        (e) => e.message,
        'message',
        startsWith('uid already exists'),
      ),
    );
    expect(() => model.createEntity('C', entity.id.uid), uidExists);
    expect(() => entity.createProperty('newProp', prop.id.uid), uidExists);
    expect(
      () => entity.createProperty('newProp2', prop.indexId!.uid),
      uidExists,
    );
    expect(() => entity.createRelation('newRel', rel.id.uid), uidExists);
  });

  test('model removeEntity retires all UIDs', () {
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

    // Retired UIDs must not be allowed for re-use
    expect(model.containsUid(entity.id.uid), isTrue);
    expect(model.containsUid(prop.id.uid), isTrue);
    expect(model.containsUid(prop.indexId!.uid), isTrue);
    expect(model.containsUid(rel.id.uid), isTrue);
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
