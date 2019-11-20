import "dart:async";
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;

/// CodeBuilder collects all ".objectbox.info" files created by EntityResolver and generates objectbox-model.json and
/// objectbox_model.dart
class CodeBuilder extends Builder {
  @override
  final buildExtensions = {
    r'$lib$': ['objectbox_model.dart']
  };

  AssetId assetPath(BuildStep buildStep, String filename) {
    return AssetId(
      buildStep.inputId.package,
      path.join('lib', filename),
    );
  }

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    // will be only called once, for the whole directory

    final files = <String>[];
    await for (final input in buildStep.findAssets(Glob('lib/**'))) {
      files.add(input.path);
    }

    return buildStep.writeAsString(assetPath(buildStep, 'objectbox_model.dart'), "// TODO generated model code");
  }


//class EntityResolver extends GeneratorForAnnotation<obx.Entity> {
//  static const modelJSON = "objectbox-model.json";
//  static const modelDart = "objectbox_model.dart";

//  Future<ModelInfo> _loadModelInfo() async {
//    if ((await FileSystemEntity.type(modelJSON)) == FileSystemEntityType.notFound) {
//      return ModelInfo.createDefault();
//    }
//    return ModelInfo.fromMap(json.decode(await (File(modelJSON).readAsString())));
//  }
//
//  void _writeModelInfo(ModelInfo modelInfo) async {
//    final json = JsonEncoder.withIndent("  ").convert(modelInfo.toMap());
//    await File(modelJSON).writeAsString(json);
//
//    final code = CodeChunks.modelInfoDefinition(modelInfo);
//    await File(modelDart).writeAsString(code);
//  }

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
