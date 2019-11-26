import "dart:convert";
import "dart:io";

import "package:test/test.dart";
import 'package:build/build.dart';
import 'package:glob/glob.dart' show Glob;
import "package:build/src/asset/id.dart";
import "package:objectbox_generator/objectbox_generator.dart";
import "package:build/src/asset/reader.dart";
import "package:build/src/asset/writer.dart";
import "package:build/src/analyzer/resolver.dart";
import "package:build_resolvers/src/resolver.dart";

class _InMemoryAssetWriter implements AssetWriter {
  Map<AssetId, String> output;

  _InMemoryAssetWriter() : output = Map<AssetId, String>();

  @override
  Future writeAsBytes(AssetId id, List<int> bytes) async {
    throw UnimplementedError();
  }

  @override
  Future writeAsString(AssetId id, String contents, {Encoding encoding = utf8}) async {
    if (output[id] != null) throw Exception("output was set already");
    output[id] = contents;
  }
}

class _SingleFileAssetReader extends AssetReader {
  Future<bool> canRead(AssetId id) async => true; //this.id == id;

  Stream<AssetId> findAssets(Glob glob, {String package}) => throw UnimplementedError();

  @override
  Future<List<int>> readAsBytes(AssetId id) async => utf8.encode(await readAsString(id));

  @override
  Future<String> readAsString(AssetId id, {Encoding encoding = utf8}) async {
    if (id.package != "objectbox" && id.package != "objectbox_generator") return "";
    if (id.path.endsWith(".g.dart")) return "";

    String path = id.path;
    if (id.package == "objectbox") path = "../" + path;
    if (id.package == "objectbox_generator" && id.path.startsWith("test/cases") && id.path.endsWith(".dart")) {
      path += "_testcase";
    }
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) throw AssetNotFoundException(id);
    return await (File(path).readAsString());
  }
}

Future<Map<AssetId, String>> _buildGeneratorOutput(String caseName) async {
  final entities = List<AssetId>();
  for (var entity in Glob("test/cases/$caseName/*.dart_testcase").listSync()) {
    final path = entity.path.substring(0, entity.path.length - "_testcase".length);
    entities.add(AssetId("objectbox_generator", path));
  }

  var writer = _InMemoryAssetWriter();
  var reader = _SingleFileAssetReader();
  Resolvers resolvers = AnalyzerResolvers();

  await runBuilder(entityBindingBuilder(BuilderOptions.empty), entities, reader, writer, resolvers);
  return writer.output;
}

void checkExpectedContents(String path, String contents, bool updateExpected) async {
  final expectedFile = File(path);
  final expectedContents = await expectedFile.readAsString();

  if (updateExpected) {
    if (expectedContents != contents) {
      print("Updating $path");
    }
    await expectedFile.writeAsString(contents);
  } else {
    expect(contents, equals(expectedContents));
  }
}

void testGeneratorOutput(String caseName, bool updateExpected) {
  test(caseName, () async {
    Map<AssetId, String> built = await _buildGeneratorOutput(caseName);

    built.forEach((assetId, generatedCode) async {
      final expectedPath = assetId.path.replaceAll(".objectbox_entity.g.part", ".g.dart_expected");
      checkExpectedContents(expectedPath, generatedCode, updateExpected);
    });

    String jsonBuilt = await File("objectbox-model.json").readAsString();
    checkExpectedContents("test/cases/$caseName/objectbox-model.json_expected", jsonBuilt, updateExpected);
  });
}
