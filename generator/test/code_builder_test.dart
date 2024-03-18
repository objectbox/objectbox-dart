import 'dart:async';

import 'package:build/build.dart';
import 'package:build/src/builder/build_step_impl.dart';
import 'package:build_test/build_test.dart';
import 'package:objectbox_generator/src/builder_dirs.dart';
import 'package:objectbox_generator/src/code_builder.dart';
import 'package:objectbox_generator/src/config.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  var reader = StubAssetReader();
  var writer = StubAssetWriter();
  final resourceManager = ResourceManager();
  // Default directory structure: sources inside lib folder.
  final testBuildStep = BuildStepImpl(
      AssetId("objectbox_generator_test", "lib/\$lib\$"),
      [],
      reader,
      writer,
      null,
      resourceManager,
      _unsupported);

  group('getRootDir and getOutDir', () {
    test('lib', () {
      final builderDirs = BuilderDirs(testBuildStep, Config());
      expect(builderDirs.root, equals('lib'));
      expect(builderDirs.out, equals('lib'));
    });

    test('test', () {
      final testBuildStepTest = BuildStepImpl(
          AssetId("objectbox_generator_test", "test/\$test\$"),
          [],
          reader,
          writer,
          null,
          resourceManager,
          _unsupported);
      final builderDirs = BuilderDirs(testBuildStepTest, Config());
      expect(builderDirs.root, equals('test'));
      expect(builderDirs.out, equals('test'));
    });

    test('not supported', () {
      final testBuildStepNotSupported = BuildStepImpl(
          AssetId("objectbox_generator_test", "custom/\$custom\$"),
          [],
          reader,
          writer,
          null,
          resourceManager,
          _unsupported);
      expect(
          () => BuilderDirs(testBuildStepNotSupported, Config()),
          throwsA(predicate((e) =>
              e is ArgumentError &&
              e.message == 'Is not lib or test directory: "custom"')));
    });

    test('out dir with redundant slash', () {
      final builderDirs = BuilderDirs(testBuildStep, Config(outDirLib: '/'));
      expect(builderDirs.root, equals('lib'));
      expect(builderDirs.out, equals(path.normalize('lib')));
    });

    test('out dir not in root dir', () {
      final builderDirs =
          BuilderDirs(testBuildStep, Config(outDirLib: '../sibling'));
      expect(builderDirs.root, equals('lib'));
      expect(builderDirs.out, equals(path.normalize('sibling')));
    });

    test('out dir below root dir', () {
      final builderDirs =
          BuilderDirs(testBuildStep, Config(outDirLib: 'below/root'));
      expect(builderDirs.root, equals('lib'));
      expect(builderDirs.out, equals(path.normalize('lib/below/root')));
    });
  });

  group('getPrefixFor', () {
    test('out dir is root dir', () {
      expect(CodeBuilder.getPrefixFor(BuilderDirs(testBuildStep, Config())),
          equals(''));
    });

    test('out dir redundant slash', () {
      expect(
          CodeBuilder.getPrefixFor(
              BuilderDirs(testBuildStep, Config(outDirLib: '/'))),
          equals(''));
      expect(
          CodeBuilder.getPrefixFor(
              BuilderDirs(testBuildStep, Config(outDirLib: '//below/'))),
          equals('../'));
    });

    test('out dir not in root dir', () {
      expect(
          () => CodeBuilder.getPrefixFor(
              BuilderDirs(testBuildStep, Config(outDirLib: '../sibling'))),
          throwsA(predicate((e) =>
              e is InvalidGenerationSourceError &&
              e.message
                  .contains("is not a subdirectory of the source directory"))));

      expect(
          () => CodeBuilder.getPrefixFor(
              BuilderDirs(testBuildStep, Config(outDirLib: '../../above'))),
          throwsA(predicate((e) =>
              e is InvalidGenerationSourceError &&
              e.message
                  .contains("is not a subdirectory of the source directory"))));
    });

    test('out dir below root dir', () {
      expect(
          CodeBuilder.getPrefixFor(
              BuilderDirs(testBuildStep, Config(outDirLib: 'below'))),
          equals('../'));
      expect(
          CodeBuilder.getPrefixFor(
              BuilderDirs(testBuildStep, Config(outDirLib: 'below/lower'))),
          equals('../../'));
    });
  });
}

Future<PackageConfig> _unsupported() {
  return Future.error(UnsupportedError('stub'));
}
