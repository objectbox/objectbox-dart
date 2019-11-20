import 'dart:async';
import 'dart:convert';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:objectbox/objectbox.dart';
import 'entity_resolver.dart';
import 'merge.dart';

/// CodeBuilder collects all ".objectbox.info" files created by EntityResolver and generates objectbox-model.json and
/// objectbox_model.dart
class CodeBuilder extends Builder {
  static final jsonFile = 'objectbox-model.json';
  static final codeFile = 'objectbox_model.dart';

  @override
  final buildExtensions = {r'$lib$': _outputs, r'$test$': _outputs};
  static final _outputs = [jsonFile, codeFile];

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    // will be only called once, for the whole directory
    final dir = path.dirname(buildStep.inputId.path);

    // map from file name to a "json" representation of entities
    final files = Map<String, List<dynamic>>();
    final glob = Glob(path.join(dir, '**' + EntityResolver.suffix));
    await for (final input in buildStep.findAssets(glob)) {
      files[input.path] = json.decode(await buildStep.readAsString(input));
    }
    if (files.isEmpty) return;

    log.info("Package: ${buildStep.inputId.package}");
    log.info("Found entity files: ${files.keys}");

    // load an existing model or initialize a new one
    ModelInfo model;
    final jsonId = AssetId(buildStep.inputId.package, path.join(dir, jsonFile));
    if (await buildStep.canRead(jsonId)) {
      log.info("Reading model: ${jsonId.path}");
      model = ModelInfo.fromMap(json.decode(await buildStep.readAsString(jsonId)));
    } else {
      log.warning("Creating new model: ${jsonId.path}");
      model = ModelInfo.createDefault();
    }

    // collect all entities and sort them by name
    final entities = List<ModelEntity>();
    for (final entitiesList in files.values) {
      for (final entityMap in entitiesList) {
        entities.add(ModelEntity.fromMap(entityMap));
      }
    }
    entities.sort((a, b) => a.name.compareTo(b.name));

    // merge existing model and annotated model that was just read, then write new final model to file
    entities.forEach((entity) => mergeEntity(model, entity));

    // write model info
    await buildStep.writeAsString(jsonId, JsonEncoder.withIndent("  ").convert(model.toMap()));

    // TODO write code
  }

//
//      // load existing model from JSON file if possible
//      ModelInfo modelInfo = await _loadModelInfo();
//
//      var code = "";

//      // merge existing model and annotated model that was just read, then write new final model to file
//      mergeEntity(modelInfo, readEntity);
//      _writeModelInfo(modelInfo);
//
//      readEntity = modelInfo.findEntityByName(element.name);
//      if (readEntity == null) return code;
//
//      // main code for instance builders and readers
//      code += CodeChunks.instanceBuildersReaders(readEntity);
//
//      // for building queries
//      code += CodeChunks.queryConditionClasses(readEntity);
//
//      return code;
}
