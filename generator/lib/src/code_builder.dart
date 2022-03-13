import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:objectbox/internal.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/source_gen.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import 'config.dart';
import 'entity_resolver.dart';
import 'code_chunks.dart';

/// CodeBuilder collects all '.objectbox.info' files created by EntityResolver and generates objectbox-model.json and
/// objectbox_model.dart
class CodeBuilder extends Builder {
  final Config _config;

  CodeBuilder(this._config);

  @override
  late final buildExtensions = {
    r'$lib$': [path.join(_config.outDirLib, _config.codeFile)],
    r'$test$': [path.join(_config.outDirTest, _config.codeFile)]
  };

  String _dir(BuildStep buildStep) => path.dirname(buildStep.inputId.path);

  String _outDir(BuildStep buildStep) {
    var dir = _dir(buildStep);
    if (dir.endsWith('test')) {
      return dir + '/' + _config.outDirTest;
    } else if (dir.endsWith('lib')) {
      return dir + '/' + _config.outDirLib;
    } else {
      throw Exception('Unrecognized path being generated: $dir');
    }
  }

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    // build() will be called only twice, once for the `lib` directory and once for the `test` directory
    // map from file name to a 'json' representation of entities
    final files = <String, List<dynamic>>{};
    final glob = Glob(_dir(buildStep) + '/**' + EntityResolver.suffix);
    await for (final input in buildStep.findAssets(glob)) {
      files[input.path] = json.decode(await buildStep.readAsString(input))!;
    }
    if (files.isEmpty) return;

    // collect all entities and sort them by name
    final entities = <ModelEntity>[];
    for (final entitiesList in files.values) {
      for (final entityMap in entitiesList) {
        entities.add(ModelEntity.fromMap(entityMap, check: false));
      }
    }
    entities.sort((a, b) => a.name.compareTo(b.name));

    log.info('Package: ${buildStep.inputId.package}');
    log.info('Found ${entities.length} entities in: ${files.keys}');

    // update the model JSON with the read entities
    final model = await updateModel(entities, buildStep);

    Pubspec? pubspec;
    try {
      final pubspecFile = File(path.join(_dir(buildStep), '../pubspec.yaml'));
      pubspec = Pubspec.parse(pubspecFile.readAsStringSync());
    } catch (e) {
      log.info("Couldn't load pubspec.yaml: $e");
    }

    // generate binding code
    updateCode(model, files.keys.toList(growable: false), buildStep, pubspec);
  }

  Future<ModelInfo> updateModel(
      List<ModelEntity> entities, BuildStep buildStep) async {
    // load an existing model or initialize a new one
    ModelInfo model;
    final jsonId = AssetId(
        buildStep.inputId.package, _outDir(buildStep) + '/' + _config.jsonFile);
    if (await buildStep.canRead(jsonId)) {
      log.info('Using model: ${jsonId.path}');
      model =
          ModelInfo.fromMap(json.decode(await buildStep.readAsString(jsonId)));
    } else {
      log.warning('Creating model: ${jsonId.path}');
      model = ModelInfo.empty();
    }

    // merge existing model and annotated model that was just read, then write new final model to file
    merge(model, entities);
    model.validate();

    // write model info
    // Can't use output, it's removed before each build, though writing to FS is explicitly forbidden by package:build.
    // await buildStep.writeAsString(jsonId, JsonEncoder.withIndent('  ').convert(model.toMap()));
    await File(jsonId.path).writeAsString(
        JsonEncoder.withIndent('  ').convert(model.toMap(forModelJson: true)));

    return model;
  }

  void updateCode(ModelInfo model, List<String> infoFiles, BuildStep buildStep,
      Pubspec? pubspec) async {
    // If output directory is not package root directory,
    // need to prefix imports with as many '../' to be relative from root.
    final rootPath = _dir(buildStep);
    final outPath = _outDir(buildStep);
    final rootDir = Directory(rootPath).absolute;
    var outDir = Directory(outPath).absolute;
    var prefix = '';

    if (!outDir.path.startsWith(rootDir.path)) {
      throw InvalidGenerationSourceError(
          'configured output_dir ${outDir.path} is not a '
          'subdirectory of the source directory ${rootDir.path}');
    }

    while (outDir.path != rootDir.path) {
      final parent = outDir.parent;
      if (parent.path == outDir.path) {
        log.warning(
            'Failed to find package root from output directory, generated imports might be incorrect.');
        prefix = '';
        break; // Reached top-most directory, stop searching.
      }
      outDir = parent;
      prefix += '../';
    }
    if (prefix.isNotEmpty) {
      log.info(
          'Output directory not in package root, adding prefix to imports: ' +
              prefix);
    }

    // transform '/lib/path/entity.objectbox.info' to 'path/entity.dart'
    final imports = infoFiles
        .map((file) => file
            .replaceFirst(EntityResolver.suffix, '.dart')
            .replaceFirst(rootPath + '/', prefix))
        .toList();

    var code = CodeChunks.objectboxDart(model, imports, pubspec);

    try {
      code = DartFormatter().format(code);
    } finally {
      // Write the code even after a formatter error so it's easier to debug.
      final codeId =
          AssetId(buildStep.inputId.package, outPath + '/' + _config.codeFile);
      log.info('Generating code: ${codeId.path}');
      await buildStep.writeAsString(codeId, code);
    }
  }

  void merge(ModelInfo model, List<ModelEntity> entities) {
    // update existing and add new, while collecting all entity IDs at the end
    final currentEntityIds = <int>{};
    entities.forEach((entity) {
      final id = mergeEntity(model, entity);
      currentEntityIds.add(id.id);
    });

    // remove ('retire') missing entities
    model.entities
        .where((entity) => !currentEntityIds.contains(entity.id.id))
        .forEach((entity) {
      log.warning(
          'Entity ${entity.name}(${entity.id}) not found in the code, removing from the model');
      model.removeEntity(entity);
    });

    // finally, update relation targets, now that all entities are resolved
    model.entities.forEach((entity) => entity.relations.forEach((rel) {
          final targetEntity = model.findEntityByName(rel.targetName);
          if (targetEntity == null) {
            throw InvalidGenerationSourceError(
                "entity ${entity.name} relation ${rel.name}: cannot find target entity '${rel.targetName}");
          }
          rel.targetId = targetEntity.id;
        }));
  }

  void mergeProperty(ModelEntity entityInModel, ModelProperty prop) {
    var propInModel = entityInModel.findSameProperty(prop);

    if (propInModel == null) {
      log.info('Found new property ${entityInModel.name}.${prop.name}');
      if (prop.uidRequest) {
        throw ArgumentError(
            'Property ${prop.name} UID is specified explicitly with a zero value on a new property.'
            "If you're adding a new property, remove the `uid` argument");
      }
      propInModel = entityInModel.createProperty(prop.name, prop.id.uid);
    } else if (prop.uidRequest) {
      handleUidRequest(
          'Property', prop.name, propInModel.id, entityInModel.model);
    }

    // update the source object so we don't get removed as a missing property
    prop.id = propInModel.id;

    propInModel.name = prop.name;
    propInModel.type = prop.type;
    propInModel.flags = prop.flags;
    propInModel.dartFieldType = prop.dartFieldType;
    propInModel.relationTarget = prop.relationTarget;

    if (!prop.hasIndexFlag()) {
      propInModel.removeIndex();
    } else {
      propInModel.indexId ??= entityInModel.model.createIndexId();
    }
  }

  void mergeRelation(ModelEntity entityInModel, ModelRelation rel) {
    var relInModel = entityInModel.findSameRelation(rel);

    if (relInModel == null) {
      log.info('Found new relation ${entityInModel.name}.${rel.name}');
      if (rel.uidRequest) {
        throw ArgumentError(
            'Relation ${rel.name} UID is specified explicitly with a zero value on a new relation.'
            "If you're adding a new rel, remove the `uid` argument");
      }
      relInModel = entityInModel.createRelation(rel.name, rel.id.uid);
    } else if (rel.uidRequest) {
      handleUidRequest(
          'Property', rel.name, relInModel.id, entityInModel.model);
    }

    // update the source object so we don't get removed as a missing property
    rel.id = relInModel.id;

    relInModel.name = rel.name;
    relInModel.targetName = rel.targetName;
  }

  IdUid mergeEntity(ModelInfo modelInfo, ModelEntity entity) {
    // 'entity' only contains the entity info directly read from the annotations and Dart source (i.e. with missing ID, lastPropertyId etc.)
    // 'entityInModel' is the entity from the model with all correct id/uid, lastPropertyId etc.
    var entityInModel = modelInfo.findSameEntity(entity);

    if (entityInModel == null) {
      log.info('Found new entity ${entity.name}');
      if (entity.uidRequest) {
        throw ArgumentError(
            'Entity ${entity.name} UID is specified explicitly with a zero value on a new entity.'
            "If you're adding a new entity, remove the `uid` argument");
      }
      // in case the entity is created (i.e. when its given UID or name that does not yet exist), we are done, as nothing needs to be merged
      entityInModel = modelInfo.createEntity(entity.name, entity.id.uid);
    } else if (entity.uidRequest) {
      handleUidRequest('Entity', entity.name, entityInModel.id, modelInfo);
    }

    // update the source object so we don't get removed as a missing entity
    entity.id = entityInModel.id;

    entityInModel.name = entity.name;
    entityInModel.flags = entity.flags;
    entityInModel.nullSafetyEnabled = entity.nullSafetyEnabled;
    entityInModel.constructorParams = entity.constructorParams;

    // here, the entity was found already and entityInModel and entity might differ, i.e. conflicts need to be resolved, so merge all properties first
    entity.properties.forEach((p) => mergeProperty(entityInModel!, p));
    entity.relations.forEach((r) => mergeRelation(entityInModel!, r));

    // then remove all properties not present anymore in entity
    final missingProps = entityInModel.properties
        .where((p) => entity.findSameProperty(p) == null)
        .toList(growable: false);

    missingProps.forEach((p) {
      log.warning(
          'Property ${entity.name}.${p.name}(${p.id}) not found in the code, removing from the model');
      entityInModel!.removeProperty(p);
    });

    // then remove all relations not present anymore in entity
    final missingRels = entityInModel.relations
        .where((p) => entity.findSameRelation(p) == null)
        .toList(growable: false);

    missingRels.forEach((p) {
      log.warning(
          'Relation ${entity.name}.${p.name}(${p.id}) not found in the code, removing from the model');
      entityInModel!.removeRelation(p);
    });

    // Only for code generator, backlinks are not actually in model JSON.
    entityInModel.backlinks.addAll(entity.backlinks);

    return entityInModel.id;
  }
}

Never handleUidRequest(
        String annotationName, String name, IdUid currentId, ModelInfo model) =>
    throw InvalidGenerationSourceError('''
    @$annotationName(uid: 0) found on "$name" - you can choose one of the following actions:
      [Rename] apply the current UID using @$annotationName(uid: ${currentId.uid})
      [Change/reset] apply a new UID using @$annotationName(uid: ${model.generateUid()})
''');
