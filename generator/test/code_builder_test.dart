import 'dart:async';
import 'dart:convert';

import 'package:objectbox_generator/src/builder_dirs.dart';
import 'package:path/path.dart' as path;
import 'package:build/build.dart';
import 'package:build/src/builder/build_step_impl.dart';
import 'package:crypto/src/digest.dart';
import 'package:glob/glob.dart';
import 'package:objectbox_generator/src/code_builder.dart';
import 'package:objectbox_generator/src/config.dart';
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
      resourceManager);

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
          resourceManager);
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
          resourceManager);
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

/// A no-op implementation of [AssetReader].
class StubAssetReader extends AssetReader implements MultiPackageAssetReader {
  StubAssetReader();

  @override
  Future<bool> canRead(AssetId id) => Future.value(false);

  @override
  Future<List<int>> readAsBytes(AssetId id) => Future.value([]);

  @override
  Future<String> readAsString(AssetId id, {Encoding encoding = utf8}) =>
      Future.value('');

  @override
  Stream<AssetId> findAssets(Glob glob, {String? package}) =>
      const Stream<Never>.empty();

  @override
  Future<Digest> digest(AssetId id) => Future.value(Digest([1, 2, 3]));
}

/// A no-op implementation of [AssetWriter].
class StubAssetWriter implements AssetWriter {
  const StubAssetWriter();

  @override
  Future writeAsBytes(_, __) => Future.value(null);

  @override
  Future writeAsString(_, __, {Encoding encoding = utf8}) => Future.value(null);
}
