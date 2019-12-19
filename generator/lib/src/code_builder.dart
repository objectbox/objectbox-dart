import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:objectbox/objectbox.dart';
import 'package:dart_style/dart_style.dart';
import 'entity_resolver.dart';
import 'code_chunks.dart';

/// CodeBuilder collects all ".objectbox.info" files created by EntityResolver and generates objectbox-model.json and
/// objectbox_model.dart
class CodeBuilder extends Builder {
  static final jsonFile = 'objectbox-model.json';
  static final codeFile = 'objectbox.g.dart';

  @override
  final buildExtensions = {r'$lib$': _outputs, r'$test$': _outputs};

  // we can't write `jsonFile` as part of the output because we want it persisted, not removed before each generation
  static final _outputs = [codeFile];

  String dir(BuildStep buildStep) => path.dirname(buildStep.inputId.path);

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    // build() will be called only twice, once for the `lib` directory and once for the `test` directory

    // map from file name to a "json" representation of entities
    final files = Map<String, List<dynamic>>();
    final glob = Glob(dir(buildStep) + '/**' + EntityResolver.suffix);
    await for (final input in buildStep.findAssets(glob)) {
      files[input.path] = json.decode(await buildStep.readAsString(input));
    }
    if (files.isEmpty) return;

    // collect all entities and sort them by name
    final entities = List<ModelEntity>();
    for (final entitiesList in files.values) {
      for (final entityMap in entitiesList) {
        entities.add(ModelEntity.fromMap(entityMap, check: false));
      }
    }
    entities.sort((a, b) => a.name.compareTo(b.name));

    log.info("Package: ${buildStep.inputId.package}");
    log.info("Found ${entities.length} entities in: ${files.keys}");

    // update the model JSON with the read entities
    final model = await updateModel(entities, buildStep);

    // generate binding code
    updateCode(model, files.keys.toList(growable: false), buildStep);
  }

  Future<ModelInfo> updateModel(List<ModelEntity> entities, BuildStep buildStep) async {
    {
      // TODO temporary v0.5 -> v0.6 update - check if the model file exists in the old location
      final oldJson = AssetId(buildStep.inputId.package, "objectbox-model.json");
      if (File(oldJson.path).existsSync()) {
        throw StateError(""
            "Found objectbox-model.json in the package root. This is the old behaviour before ObjectBox v0.6\n"
            "Please move objectbox-model.json to lib/objectbox-model.json and run the build_runner again.\n");
      }
    }

    // load an existing model or initialize a new one
    ModelInfo model;
    final jsonId = AssetId(buildStep.inputId.package, dir(buildStep) + "/" + jsonFile);
    if (await buildStep.canRead(jsonId)) {
      log.info("Using model: ${jsonId.path}");
      model = ModelInfo.fromMap(json.decode(await buildStep.readAsString(jsonId)));
    } else {
      log.warning("Creating model: ${jsonId.path}");
      model = ModelInfo.createDefault();
    }

    // merge existing model and annotated model that was just read, then write new final model to file
    merge(model, entities);
    model.validate();

    // write model info
    // Can't use output, it's removed before each build, though writing to FS is explicitly forbidden by package:build.
    // await buildStep.writeAsString(jsonId, JsonEncoder.withIndent("  ").convert(model.toMap()));
    await File(jsonId.path).writeAsString(JsonEncoder.withIndent("  ").convert(model.toMap()));

    return model;
  }

  void updateCode(ModelInfo model, List<String> infoFiles, BuildStep buildStep) async {
    // transform "/lib/path/entity.objectbox.info" to "path/entity.dart"
    final imports = infoFiles
        .map((file) => file.replaceFirst(EntityResolver.suffix, ".dart").replaceFirst(dir(buildStep) + "/", ""))
        .toList();

    var code = CodeChunks.objectboxDart(model, imports);
    code = DartFormatter().format(code);

    final codeId = AssetId(buildStep.inputId.package, dir(buildStep) + "/" + codeFile);
    log.info("Generating code: ${codeId.path}");
    await buildStep.writeAsString(codeId, code);
  }

  void merge(ModelInfo model, List<ModelEntity> entities) {
    // update existing and add new, while collecting all entity IDs at the end
    final currentEntityIds = Map<int, bool>();
    entities.forEach((entity) {
      final id = mergeEntity(model, entity);
      currentEntityIds[id.id] = true;
    });

    // remove ("retire") missing entities
    model.entities.where((entity) => !currentEntityIds.containsKey(entity.id.id)).forEach((entity) {
      log.warning("Entity ${entity.name}(${entity.id.toString()}) not found in the code, removing from the model");
      model.removeEntity(entity);
    });

    entities.forEach((entity) => mergeEntity(model, entity));
  }

  void mergeProperty(ModelEntity entity, ModelProperty prop) {
    ModelProperty propInModel = entity.findSameProperty(prop);
    if (propInModel == null) {
      log.info("Found new property ${entity.name}.${prop.name}");
      entity.addProperty(prop);
    } else {
      propInModel.name = prop.name;
      propInModel.type = prop.type;
      propInModel.flags = prop.flags;
    }
  }

  IdUid mergeEntity(ModelInfo modelInfo, ModelEntity entity) {
    // "readEntity" only contains the entity info directly read from the annotations and Dart source (i.e. with missing ID, lastPropertyId etc.)
    // "entityInModel" is the entity from the model with all correct id/uid, lastPropertyId etc.
    ModelEntity entityInModel = modelInfo.findSameEntity(entity);

    if (entityInModel == null) {
      log.info("Found new entity ${entity.name}");
      // in case the entity is created (i.e. when its given UID or name that does not yet exist), we are done, as nothing needs to be merged
      final createdEntity = modelInfo.addEntity(entity);
      return createdEntity.id;
    }

    entityInModel.name = entity.name;

    // here, the entity was found already and entityInModel and readEntity might differ, i.e. conflicts need to be resolved, so merge all properties first
    entity.properties.forEach((p) => mergeProperty(entityInModel, p));

    // then remove all properties not present anymore in readEntity
    entityInModel.properties.where((p) => entity.findSameProperty(p) == null).forEach((p) {
      log.warning(
          "Property ${entity.name}.${p.name}(${p.id.toString()}) not found in the code, removing from the model");
      entityInModel.removeProperty(p);
    });

    return entityInModel.id;
  }
}
