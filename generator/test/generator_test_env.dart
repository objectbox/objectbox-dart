import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:objectbox/internal.dart';
import 'package:objectbox_generator/src/code_builder.dart';
import 'package:objectbox_generator/src/config.dart';
import 'package:objectbox_generator/src/entity_resolver.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Helps testing the generator by running [EntityResolver] on the given
/// [source] file and feeding the output directly into [CodeBuilder] and running
/// it.
class GeneratorTestEnv {
  final EntityResolver resolver;
  final Config config;
  late final CodeBuilder codeBuilder;

  GeneratorTestEnv()
      : resolver = EntityResolver(),
        config = Config() {
    codeBuilder = CodeBuilder(config);
  }

  /// This is safe to call after [run] succeeded.
  ModelInfo get model {
    return codeBuilder.model!;
  }

  Future<void> run(String source) async {
    final library = "example";
    // Enable resolving imports, must be a dependency of this package
    final reader =
        await PackageAssetReader.currentIsolate(rootPackage: library);

    final sourceAssets = {'$library|lib/entity.dart': source};
    final entityInfoPath = '$library|lib/entity.objectbox.info';
    final entityInfo = AssetId.parse(entityInfoPath);

    final writer = InMemoryAssetWriter();
    final outputReader = WrittenAssetReader(writer);

    // Run EntityResolver
    await testBuilder(resolver, sourceAssets, reader: reader, writer: writer);

    // Check entity info file was created
    expect(await outputReader.canRead(entityInfo), isTrue);

    // If entity info model ever needs to be asserted, do it like:
    // final entitiesList =
    //     json.decode(await outputReader.readAsString(entityInfo));
    // var modelEntity = ModelEntity.fromMap(entitiesList[0], check: false);
    // expect(modelEntity.name, "Example");
    // expect(modelEntity.flags, 0);

    // Run CodeBuilder
    await testBuilder(
      codeBuilder,
      {entityInfo.toString(): outputReader.readAsString(entityInfo)},
      reader: outputReader,
      // Future improvement: assert generated code? Needs existing model JSON for stable IDs
      // outputs: {
      //   '$library|lib/objectbox.g.dart': '<file-content>',
      // },
    );

    // Assert generator model
    final modelFile = File(path.join("lib", config.jsonFile));
    final jsonModel = await _readModelFile(modelFile);
    _commonModelTests(model, jsonModel);

    // The model file is not written using Builder API, so it is actually
    // written to the file system: remove it once done with the test.
    addTearDown(() async => {await modelFile.delete()});
  }

  Future<ModelInfo> _readModelFile(File modelFile) async {
    return ModelInfo.fromMap(json.decode(await modelFile.readAsString()));
  }

  /// Check that the model is specified and written to JSON correctly.
  /// Note: there are tests asserting the generated model code in integration-tests/common.dart
  _commonModelTests(ModelInfo generatorModel, ModelInfo jsonModel) {
    // collect UIDs on all entities and properties
    final allUIDs = generatorModel.entities
        .map((entity) => <int>[]
          ..add(entity.id.uid)
          ..addAll(entity.properties.map((prop) => prop.id.uid))
          ..addAll(entity.properties
              .where((prop) => prop.hasIndexFlag())
              .map((prop) => prop.indexId!.uid))
          ..addAll(entity.relations.map((rel) => rel.id.uid)))
        .reduce((List<int> a, List<int> b) => a + b);

    expect(allUIDs.toSet().length, allUIDs.length,
        reason: 'UIDs are not unique');

    // lastPropertyId
    for (final entity in generatorModel.entities) {
      _testLastId(entity.lastPropertyId, entity.properties.map((el) => el.id),
          generatorModel.retiredPropertyUids);
    }

    // lastEntityId
    _testLastId(
        generatorModel.lastEntityId,
        generatorModel.entities.map((el) => el.id),
        generatorModel.retiredEntityUids);

    // lastIndexId
    _testLastId(
        generatorModel.lastIndexId,
        generatorModel.entities
            .map((ModelEntity e) => e.properties
                .where((p) => p.hasIndexFlag())
                .map((p) => p.indexId!)
                .toList())
            .reduce((List<IdUid> a, List<IdUid> b) => a + b),
        generatorModel.retiredIndexUids);

    // lastRelationId
    _testLastId(
        generatorModel.lastRelationId,
        generatorModel.entities
            .map((ModelEntity e) => e.relations.map((r) => r.id).toList())
            .reduce((List<IdUid> a, List<IdUid> b) => a + b),
        generatorModel.retiredRelationUids);

    // Written JSON model same as generator model
    // This basically tests that toMap and fromMap do what they should
    expect(jsonModel.entities.length, generatorModel.entities.length);
    _expectIdUid(jsonModel.lastEntityId, generatorModel.lastEntityId);
    _expectIdUid(jsonModel.lastIndexId, generatorModel.lastIndexId);
    _expectIdUid(jsonModel.lastRelationId, generatorModel.lastRelationId);
    _expectIdUid(jsonModel.lastSequenceId, generatorModel.lastSequenceId);
    expect(jsonModel.retiredEntityUids, generatorModel.retiredEntityUids);
    expect(jsonModel.retiredIndexUids, generatorModel.retiredIndexUids);
    expect(jsonModel.retiredPropertyUids, generatorModel.retiredPropertyUids);
    expect(jsonModel.retiredRelationUids, generatorModel.retiredRelationUids);
    expect(jsonModel.modelVersion, generatorModel.modelVersion);
    expect(jsonModel.modelVersionParserMinimum,
        generatorModel.modelVersionParserMinimum);
    expect(jsonModel.version, generatorModel.version);
  }

  _expectIdUid(IdUid actual, IdUid expected) {
    expect(actual.toString(), expected.toString());
  }

  _testLastId(IdUid last, Iterable<IdUid> all, Iterable<int> retired) {
    if (last.isEmpty) return;

    // If among used IDs, UID should match; ID and UID not re-used elsewhere
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

    // Should be in retired IDs if not used and vice versa
    if (!amongAll) {
      expect(retired, contains(last.uid));
    } else {
      expect(retired, isNot(contains(last.uid)));
    }
  }
}
