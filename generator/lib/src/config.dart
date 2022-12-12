import 'dart:io';

import 'package:yaml/yaml.dart';

const _pubspecFile = 'pubspec.yaml';
const _pubspecKey = 'objectbox';

/// Config reads and holds configuration for the code generator.
///
/// Expected format in pubspec.yaml:
/// ```
/// objectbox:
///   output_dir: custom
///   # Or optionally specify lib and test folder separately.
///   # output_dir:
///   #   lib: custom
///   #   test: other
/// ```
class Config {
  final String jsonFile;
  final String codeFile;
  final String outDirLib;
  final String outDirTest;

  Config(
      {String? jsonFile,
      String? codeFile,
      String? outDirLib,
      String? outDirTest})
      : jsonFile = jsonFile ?? 'objectbox-model.json',
        codeFile = codeFile ?? 'objectbox.g.dart',
        outDirLib = outDirLib ?? '',
        outDirTest = outDirTest ?? '';

  factory Config.readFromPubspec() {
    final file = File(_pubspecFile);
    if (file.existsSync()) {
      final yaml = loadYaml(file.readAsStringSync())[_pubspecKey] as YamlMap?;
      if (yaml != null) {
        late final String? outDirLib;
        late final String? outDirTest;
        final outDirYaml = yaml['output_dir'];

        if (outDirYaml is YamlMap) {
          outDirLib = outDirYaml['lib'];
          outDirTest = outDirYaml['test'];
        } else {
          outDirLib = outDirTest = outDirYaml as String?;
        }

        return Config(outDirLib: outDirLib, outDirTest: outDirTest);
      }
    }
    return Config();
  }
}
