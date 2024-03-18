import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:objectbox/internal.dart';
import 'package:objectbox_generator/src/code_builder.dart';
import 'package:objectbox_generator/src/config.dart';
import 'package:objectbox_generator/src/entity_resolver.dart';
import 'package:path/path.dart';
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

    // Asserting entity info model not really worth?
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
      // TODO Assert generated code?
      // outputs: {
      //   '$library|lib/objectbox.g.dart': '',
      // },
    );

    final modelFile = File(join("lib", config.jsonFile));
    // TODO Assert JSON model file
    // TODO Add common model asserts (see integration-tests/common.dart)

    // The model file is not written using Builder API, so it is actually
    // written to the file system: remove it once done with the test.
    addTearDown(() async => {await modelFile.delete()});
  }
}
