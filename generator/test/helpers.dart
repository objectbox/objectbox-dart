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
  String output;

  _InMemoryAssetWriter();

  @override
  Future writeAsBytes(AssetId id, List<int> bytes) async {
    throw UnimplementedError();
  }

  @override
  Future writeAsString(AssetId id, String contents, {Encoding encoding = utf8}) async {
    if (output != null) throw Exception("output was set already");
    output = contents;
  }
}

class _SingleFileAssetReader extends AssetReader {
  AssetId id;

  _SingleFileAssetReader(this.id) {
    if (id.package != "objectbox_generator") {
      throw Exception("asset package needs to be 'objectbox_generator', but got '${id.package}'");
    }
  }

  Future<bool> canRead(AssetId id) async => true; //this.id == id;

  Stream<AssetId> findAssets(Glob glob, {String package}) => Stream.fromIterable([id]);

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

Future<String> _buildGeneratorOutput(String caseName) async {
  AssetId assetId = AssetId("objectbox_generator", "test/cases/$caseName/$caseName.dart");
  var writer = _InMemoryAssetWriter();
  var reader = _SingleFileAssetReader(assetId);
  Resolvers resolvers = AnalyzerResolvers();

  await runBuilder(objectboxModelFactory(BuilderOptions.empty), [assetId], reader, writer, resolvers);
  return writer.output;
}

void testGeneratorOutput(String caseName) {
  test(caseName, () async {
    String built = await _buildGeneratorOutput(caseName);
    String expected = await File("test/cases/$caseName/$caseName.g.dart_expected").readAsString();
    expect(built, equals(expected));

    String jsonBuilt = await File("objectbox-model.json").readAsString();
    String jsonExpected = await File("test/cases/$caseName/objectbox-model.json_expected").readAsString();
    expect(jsonBuilt, equals(jsonExpected));
  });
}
