import 'package:objectbox/objectbox.dart';
import 'package:test/test.dart';

/// Configures test cases to check that the model is specified correctly
commonModelTests(ModelDefinition defs) {
  test("model bindings", () {
    expect(defs.bindings.length, defs.model.entities.length);
  });

  test("unique UIDs", () {
    // collect UIDs on all entities and properties
    // TODO relations, indexes
    final allUIDs = defs.model.entities
        .map((entity) => List<int>()
          ..add(entity.id.uid)
          ..addAll(entity.properties.map((prop) => prop.id.uid)))
        .reduce((List<int> a, List<int> b) => a + b);

    expect(allUIDs.toSet().length, allUIDs.length);
  });

  final testLastId = (IdUid last, Iterable<IdUid> all, Iterable<int> retired) {
    bool amongAll = false;
    for (final current in all) {
      if (current.id == last.id) {
        expect(last.uid, current.uid);
        amongAll = true;
      } else {
        expect(current.id, lessThan(last.id));
        expect(current.uid, isNot(equals(last.uid)));
      }
    }

    if (!amongAll) {
      expect(retired, contains(last.uid));
    } else {
      expect(retired, isNot(contains(last.uid)));
    }
  };

  test("lastPropertyId", () {
    for (final entity in defs.model.entities) {
      testLastId(entity.lastPropertyId, entity.properties.map((el) => el.id), defs.model.retiredPropertyUids);
    }
  });

  test("lastEntityId", () {
    testLastId(defs.model.lastEntityId, defs.model.entities.map((el) => el.id), defs.model.retiredEntityUids);
  });

  // TODO when indexes are available
//  test("lastIndexId", () {
//    testLastId(defs.model.lastIndexId, defs.model.entities.map((el) => ...), defs.model.retiredIndexUids);
//  });

  // TODO when relations are available
//  test("lastRelationId", () {
//    testLastId(defs.model.lastRelationId, defs.model.entities.map((el) => ...), defs.model.retiredRelationUids);
//  });
}
