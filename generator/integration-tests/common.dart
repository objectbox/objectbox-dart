import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:objectbox/internal.dart';
import 'package:test/test.dart';

/// it's necessary to read json model because the generated one doesn't contain all the information
ModelInfo readModelJson(String dir) {
  return ModelInfo.fromMap(json
      .decode(File(path.join(dir, 'objectbox-model.json')).readAsStringSync()));
}

/// Configures test cases to check that the model is specified correctly
/// Note: there are tests asserting the generator model in test/generator_test_env.dart
commonModelTests(ModelDefinition defs, ModelInfo jsonModel) {
  test('model bindings', () {
    expect(defs.bindings.length, defs.model.entities.length);
  });

  test('unique UIDs', () {
    // collect UIDs on all entities and properties
    final allUIDs = defs.model.entities
        .map((entity) => <int>[]
          ..add(entity.id.uid)
          ..addAll(entity.properties.map((prop) => prop.id.uid))
          ..addAll(entity.properties
              .where((prop) => prop.hasIndexFlag())
              .map((prop) => prop.indexId!.uid))
          ..addAll(entity.relations.map((rel) => rel.id.uid)))
        .reduce((List<int> a, List<int> b) => a + b);

    expect(allUIDs.toSet().length, allUIDs.length);
  });

  final testLastId = (IdUid last, Iterable<IdUid> all, Iterable<int> retired) {
    if (last.isEmpty) return;
    var amongAll = false;
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

  test('lastPropertyId', () {
    for (final entity in defs.model.entities) {
      testLastId(entity.lastPropertyId, entity.properties.map((el) => el.id),
          jsonModel.retiredPropertyUids);
    }
  });

  test('lastEntityId', () {
    testLastId(defs.model.lastEntityId, defs.model.entities.map((el) => el.id),
        jsonModel.retiredEntityUids);
  });

  test('lastIndexId', () {
    testLastId(
        defs.model.lastIndexId,
        defs.model.entities
            .map((ModelEntity e) => e.properties
                .where((p) => p.hasIndexFlag())
                .map((p) => p.indexId!)
                .toList())
            .reduce((List<IdUid> a, List<IdUid> b) => a + b),
        jsonModel.retiredIndexUids);
  });

  test('lastRelationId', () {
    testLastId(
        defs.model.lastRelationId,
        defs.model.entities
            .map((ModelEntity e) => e.relations.map((r) => r.id).toList())
            .reduce((List<IdUid> a, List<IdUid> b) => a + b),
        jsonModel.retiredRelationUids);
  });
}

ModelEntity entity(ModelInfo model, String name) {
  return model.entities.firstWhere((ModelEntity e) => e.name == name);
}

ModelProperty property(ModelInfo model, String path) {
  final components = path.split('.');
  return entity(model, components[0])
      .properties
      .firstWhere((ModelProperty p) => p.name == components[1]);
}
