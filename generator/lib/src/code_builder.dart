import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:objectbox/internal.dart';
import 'package:objectbox_generator/src/analysis/analysis.dart';
import 'package:objectbox_generator/src/builder_dirs.dart';
import 'package:path/path.dart' as path;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:source_gen/source_gen.dart';

import 'code_chunks.dart';
import 'config.dart';
import 'entity_resolver.dart';

/// CodeBuilder collects all '.objectbox.info' files created by EntityResolver and generates objectbox-model.json and
/// objectbox_model.dart
class CodeBuilder extends Builder {
  final Config _config;

  /// Model exposed for testing.
  ModelInfo? model;

  CodeBuilder(this._config);

  @override
  late final buildExtensions = {
    r'$lib$': [path.join(_config.outDirLib, _config.codeFile)],
    r'$test$': [path.join(_config.outDirTest, _config.codeFile)]
  };

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final builderDirs = BuilderDirs(buildStep, _config);

    // build() will be called only twice, once for the `lib` directory and once for the `test` directory
    // map from file name to a 'json' representation of entities
    final files = <String, List<dynamic>>{};
    final glob = Glob('${builderDirs.root}/**${EntityResolver.suffix}');
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
    final model = await updateModel(entities, buildStep, builderDirs);
    this.model = model;

    Pubspec? pubspec;
    try {
      final pubspecFile = File(path.join(builderDirs.root, '../pubspec.yaml'));
      pubspec = Pubspec.parse(pubspecFile.readAsStringSync());
    } catch (e) {
      log.info("Couldn't load pubspec.yaml: $e");
    }

    // generate binding code
    updateCode(model, files.keys.toList(growable: false), buildStep,
        builderDirs, pubspec);

    await ObjectBoxAnalysis().sendBuildEvent(pubspec);
  }

  Future<ModelInfo> updateModel(List<ModelEntity> entities, BuildStep buildStep,
      BuilderDirs builderDirs) async {
    // load an existing model or initialize a new one
    ModelInfo model;
    final jsonId = AssetId(
        buildStep.inputId.package, '${builderDirs.out}/${_config.jsonFile}');
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
    _resolveRelations(model);
    model.validate();

    // write model info
    // Can't use output, it's removed before each build, though writing to FS is explicitly forbidden by package:build.
    // await buildStep.writeAsString(jsonId, JsonEncoder.withIndent('  ').convert(model.toMap()));
    await File(jsonId.path)
        .writeAsString(JsonEncoder.withIndent('  ').convert(model.toMap()));

    return model;
  }

  /// Returns a prefix for imports if the output directory is not the
  /// package root directory.
  ///
  /// Returns the empty string if the output directory is the root directory,
  /// otherwise adds as many '../' as necessary to be relative from root.
  ///
  /// Returns null if the root directory was not found by walking up from the
  /// output directory.
  static String? getPrefixFor(BuilderDirs builderDirs) {
    // Note: comparing path strings below so paths should be normalized (they
    // are by BuilderDirs).
    final rootDir = Directory(builderDirs.root).absolute;
    var outDir = Directory(builderDirs.out).absolute;

    if (!outDir.path.startsWith(rootDir.path)) {
      throw InvalidGenerationSourceError(
          'configured output_dir ${outDir.path} is not a '
          'subdirectory of the source directory ${rootDir.path}');
    }

    var prefix = '';
    while (outDir.path != rootDir.path) {
      final parent = outDir.parent;
      if (parent.path == outDir.path) {
        return null; // Reached top-most directory, stop searching.
      }
      outDir = parent;
      prefix += '../';
    }
    return prefix;
  }

  void updateCode(ModelInfo model, List<String> infoFiles, BuildStep buildStep,
      BuilderDirs builderDirs, Pubspec? pubspec) async {
    var prefix = getPrefixFor(builderDirs);
    if (prefix == null) {
      log.warning(
          'Failed to find package root from output directory, generated imports might be incorrect (rootDir="${builderDirs.root}", outDir="${builderDirs.out}")');
    } else if (prefix.isNotEmpty) {
      log.info(
          'Output directory not in package root, adding prefix to imports: $prefix');
    }

    // transform '/lib/path/entity.objectbox.info' to 'path/entity.dart'
    final imports = infoFiles
        .map((file) => file
            .replaceFirst(EntityResolver.suffix, '.dart')
            .replaceFirst('${builderDirs.root}/', prefix ?? ''))
        .toList();

    var code = CodeChunks.objectboxDart(model, imports, pubspec);

    try {
      code = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
          .format(code);
    } finally {
      // Write the code even after a formatter error so it's easier to debug.
      final codeId = AssetId(
          buildStep.inputId.package, '${builderDirs.out}/${_config.codeFile}');
      log.info('Generating code: ${codeId.path}');
      await buildStep.writeAsString(codeId, code);
    }
  }

  void merge(ModelInfo model, List<ModelEntity> entities) {
    // update existing and add new, while collecting all entity IDs at the end
    final currentEntityIds = <int>{};
    for (var entity in entities) {
      final id = mergeEntity(model, entity);
      currentEntityIds.add(id.id);
    }

    // remove ('retire') missing entities
    model.entities
        .where((entity) => !currentEntityIds.contains(entity.id.id))
        .forEach((entity) {
      log.warning(
          'Entity ${entity.name}(${entity.id}) not found in the code, removing from the model');
      model.removeEntity(entity);
    });
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
    propInModel.hnswParams = prop.hnswParams;
    propInModel.externalType = prop.externalType;
    propInModel.externalName = prop.externalName;

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
    relInModel.externalType = rel.externalType;
    relInModel.externalName = rel.externalName;
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
    entityInModel.externalName = entity.externalName;
    entityInModel.constructorParams = entity.constructorParams;

    // here, the entity was found already and entityInModel and entity might differ, i.e. conflicts need to be resolved, so merge all properties first
    for (var p in entity.properties) {
      mergeProperty(entityInModel, p);
    }
    for (var r in entity.relations) {
      mergeRelation(entityInModel, r);
    }

    // then remove all properties not present anymore in entity
    final missingProps = entityInModel.properties
        .where((p) => entity.findSameProperty(p) == null)
        .toList(growable: false);

    for (var p in missingProps) {
      log.warning(
          'Property ${entity.name}.${p.name}(${p.id}) not found in the code, removing from the model');
      entityInModel.removeProperty(p);
    }

    // then remove all relations not present anymore in entity
    final missingRels = entityInModel.relations
        .where((p) => entity.findSameRelation(p) == null)
        .toList(growable: false);

    for (var p in missingRels) {
      log.warning(
          'Relation ${entity.name}.${p.name}(${p.id}) not found in the code, removing from the model');
      entityInModel.removeRelation(p);
    }

    // Only for code generator, backlinks are not actually in model JSON.
    entityInModel.backlinks.addAll(entity.backlinks);

    return entityInModel.id;
  }

  /// For standalone to-many relations, verifies and sets the target entity ID.
  /// For to-many relations based on a backlink, verifies and sets the source
  /// relation.
  void _resolveRelations(ModelInfo model) {
    for (var entity in model.entities) {
      for (var rel in entity.relations) {
        final targetEntity = model.findEntityByName(rel.targetName);
        if (targetEntity == null) {
          throw InvalidGenerationSourceError(
              "entity ${entity.name} relation ${rel.name}: cannot find target entity '${rel.targetName}");
        }
        rel.targetId = targetEntity.id;
      }

      for (var backlink in entity.backlinks) {
        backlink.source = _findBacklinkSource(model, entity, backlink);
      }
    }
  }

  /// For a backlink, finds the (to-one) property or the (to-many) relation
  /// the backlink is from. If given, uses the 'srcField' name to find it.
  /// Otherwise, tries to find a match by type (to-one) or entity ID (to-many).
  /// Throws if there are multiple matches or no match.
  BacklinkSource _findBacklinkSource(
      ModelInfo model, ModelEntity entity, ModelBacklink bl) {
    final srcEntity = model.findEntityByName(bl.srcEntity);
    if (srcEntity == null) {
      throw InvalidGenerationSourceError(
          "Invalid relation backlink '${entity.name}.${bl.name}': cannot find source entity '${bl.srcEntity}'");
    }

    // either of these will be set, based on the source field that matches
    ModelRelation? srcRel;
    ModelProperty? srcProp;

    throwAmbiguousError(String prop, String rel) =>
        throw InvalidGenerationSourceError(
            "Ambiguous relation backlink source for '${entity.name}.${bl.name}':"
            " Found matching property '$prop' and to-many relation '$rel'."
            " Maybe specify source name in @Backlink() annotation.");

    if (bl.srcField.isEmpty) {
      final matchingProps = srcEntity.properties
          .where((p) => p.isRelation && p.relationTarget == entity.name);
      final matchingRels =
          srcEntity.relations.where((r) => r.targetId == entity.id);
      final candidatesCount = matchingProps.length + matchingRels.length;
      if (candidatesCount > 1) {
        throwAmbiguousError(matchingProps.toString(), matchingRels.toString());
      } else if (matchingProps.isNotEmpty) {
        srcProp = matchingProps.first;
      } else if (matchingRels.isNotEmpty) {
        srcRel = matchingRels.first;
      }
    } else {
      srcProp = srcEntity.findPropertyByName('${bl.srcField}Id');
      srcRel =
          srcEntity.relations.firstWhereOrNull((r) => r.name == bl.srcField);

      if (srcProp != null && srcRel != null) {
        throwAmbiguousError(srcProp.toString(), srcRel.toString());
      }
    }

    if (srcRel != null) {
      return BacklinkSourceRelation(srcRel);
    } else if (srcProp != null) {
      return BacklinkSourceProperty(srcProp);
    } else {
      throw InvalidGenerationSourceError(
          "Unknown relation backlink source for '${entity.name}.${bl.name}'");
    }
  }
}

Never handleUidRequest(
        String annotationName, String name, IdUid currentId, ModelInfo model) =>
    throw InvalidGenerationSourceError('''
    @$annotationName(uid: 0) found on "$name" - you can choose one of the following actions:
      [Rename] apply the current UID using @$annotationName(uid: ${currentId.uid})
      [Change/reset] apply a new UID using @$annotationName(uid: ${model.generateUid()})
''');
