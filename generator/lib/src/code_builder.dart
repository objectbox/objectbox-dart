import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:objectbox/objectbox.dart';
import 'entity_resolver.dart';
import 'merge.dart';
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
    final glob = Glob(path.join(dir(buildStep), '**' + EntityResolver.suffix));
    await for (final input in buildStep.findAssets(glob)) {
      files[input.path] = json.decode(await buildStep.readAsString(input));
    }
    if (files.isEmpty) return;

    // collect all entities and sort them by name
    final entities = List<ModelEntity>();
    for (final entitiesList in files.values) {
      for (final entityMap in entitiesList) {
        entities.add(ModelEntity.fromMap(entityMap));
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
    // load an existing model or initialize a new one
    ModelInfo model;
    final jsonId = AssetId(buildStep.inputId.package, path.join(dir(buildStep), jsonFile));
    if (await buildStep.canRead(jsonId)) {
      log.info("Reading model: ${jsonId.path}");
      model = ModelInfo.fromMap(json.decode(await buildStep.readAsString(jsonId)));
    } else {
      log.warning("Creating new model: ${jsonId.path}");
      model = ModelInfo.createDefault();
    }

    // merge existing model and annotated model that was just read, then write new final model to file
    entities.forEach((entity) => mergeEntity(model, entity));

    // TODO remove ("retire") missing entities

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

    final codeId = AssetId(buildStep.inputId.package, path.join(dir(buildStep), codeFile));
    log.info("Generating code to: ${codeId.path}");
    await buildStep.writeAsString(codeId, code);
  }
}
