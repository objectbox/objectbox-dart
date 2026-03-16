import 'dart:io';

import 'package:build_test/build_test.dart';
import 'package:logging/logging.dart';
import 'package:objectbox/internal.dart';
import 'package:objectbox_generator/src/builder_dirs.dart';
import 'package:objectbox_generator/src/code_builder.dart';
import 'package:objectbox_generator/src/config.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import 'generator_test_env.dart';

String sourceFile(String withContent) => '''
      library example;
      import 'package:objectbox/objectbox.dart';

      $withContent
      ''';

String entity({
  String withName = 'Example',
  bool sync = false,
  String withBody = '',
}) => '''
      @Entity()
      ${sync ? '@Sync()' : ''}
      class $withName {
        @Id()
        int id = 0;

        $withBody
      }
      ''';

Future<void> expectGeneratorThrows(
  String source,
  String expectedMessagePart,
) async {
  final testEnv = GeneratorTestEnv();
  final result = await testEnv.run(source, ignoreOutput: true);

  expect(result.builderResult.succeeded, false);
  expect(
    result.logs,
    contains(
      isA<LogRecord>()
          .having((r) => r.level, 'level', Level.SEVERE)
          .having((r) => r.message, 'message', contains(expectedMessagePart)),
    ),
  );
}

void main() {
  // lib/$lib$ is a placeholder file of build_runner, it's one of the two
  // input files used by CodeBuilder.
  final inputPathLib = 'lib/\$lib\$';

  group('getRootDir and getOutDir', () {
    test('lib', () async {
      final builderDirs = BuilderDirs(inputPathLib, Config());
      expect(builderDirs.root, equals('lib'));
      expect(builderDirs.out, equals('lib'));
    });

    test('test', () async {
      // test/$test$ is a placeholder file of build_runner, it's the other one
      // of the two input files used by CodeBuilder.
      final inputPathTest = 'test/\$test\$';
      final builderDirs = BuilderDirs(inputPathTest, Config());
      expect(builderDirs.root, equals('test'));
      expect(builderDirs.out, equals('test'));
    });

    test('not supported', () {
      // For completeness, test an unsupported input file path.
      // Currently, CodeBuilder (and therefore BuilderDirs) never gets called
      // with one as its buildExtensions restricts it to the special placeholder
      // files $lib$ and $test$ (see tests above).
      final customPath = 'lib/custom/custom.dart';
      expect(
        () => BuilderDirs(customPath, Config()),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Is not lib or test directory: "lib${Platform.pathSeparator}custom"',
          ),
        ),
      );
    });

    test('out dir with redundant slash', () {
      final builderDirs = BuilderDirs(inputPathLib, Config(outDirLib: '/'));
      expect(builderDirs.root, equals('lib'));
      expect(builderDirs.out, equals(path.normalize('lib')));
    });

    test('out dir not in root dir', () {
      final builderDirs = BuilderDirs(
        inputPathLib,
        Config(outDirLib: '../sibling'),
      );
      expect(builderDirs.root, equals('lib'));
      expect(builderDirs.out, equals(path.normalize('sibling')));
    });

    test('out dir below root dir', () {
      final builderDirs = BuilderDirs(
        inputPathLib,
        Config(outDirLib: 'below/root'),
      );
      expect(builderDirs.root, equals('lib'));
      expect(builderDirs.out, equals(path.normalize('lib/below/root')));
    });
  });

  group('getPrefixFor', () {
    test('out dir is root dir', () {
      expect(
        CodeBuilder.getPrefixFor(BuilderDirs(inputPathLib, Config())),
        equals(''),
      );
    });

    test('out dir redundant slash', () {
      expect(
        CodeBuilder.getPrefixFor(
          BuilderDirs(inputPathLib, Config(outDirLib: '/')),
        ),
        equals(''),
      );
      expect(
        CodeBuilder.getPrefixFor(
          BuilderDirs(inputPathLib, Config(outDirLib: '//below/')),
        ),
        equals('../'),
      );
    });

    test('out dir not in root dir', () {
      expect(
        () => CodeBuilder.getPrefixFor(
          BuilderDirs(inputPathLib, Config(outDirLib: '../sibling')),
        ),
        throwsA(
          predicate(
            (e) =>
                e is InvalidGenerationSourceError &&
                e.message.contains(
                  "is not a subdirectory of the source directory",
                ),
          ),
        ),
      );

      expect(
        () => CodeBuilder.getPrefixFor(
          BuilderDirs(inputPathLib, Config(outDirLib: '../../above')),
        ),
        throwsA(
          predicate(
            (e) =>
                e is InvalidGenerationSourceError &&
                e.message.contains(
                  "is not a subdirectory of the source directory",
                ),
          ),
        ),
      );
    });

    test('out dir below root dir', () {
      expect(
        CodeBuilder.getPrefixFor(
          BuilderDirs(inputPathLib, Config(outDirLib: 'below')),
        ),
        equals('../'),
      );
      expect(
        CodeBuilder.getPrefixFor(
          BuilderDirs(inputPathLib, Config(outDirLib: 'below/lower')),
        ),
        equals('../../'),
      );
    });
  });

  /// Major testing is still done with the code in generator/integration-tests,
  /// but using testBuilder from build_test is a replacement which allows
  /// debugging. Future code generator tests should probably use it.
  group('code generator', () {
    test('simple entity', () async {
      final source = sourceFile(
        entity(
          withBody: r'''
          // implicit PropertyType.bool
          bool? tBool;
          
          // implicitly determined types
          String? tString;
          ''',
        ),
      );

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      // Assert final model created by generator
      expect(testEnv.model.entities.length, 1);
      final exampleEntity = testEnv.model.entities[0];
      expect(exampleEntity.name, "Example");
      expect(exampleEntity.flags, 0);
      expect(
        exampleEntity.findPropertyByName("tBool")!.type,
        OBXPropertyType.Bool,
      );
      expect(
        exampleEntity.findPropertyByName("tString")!.type,
        OBXPropertyType.String,
      );
    });

    test('index on unsupported type errors', () async {
      testUnsupportedIndex(String unsupportedField) async {
        final source = sourceFile(entity(withBody: unsupportedField));

        await expectGeneratorThrows(source, '@Index/@Unique is not supported');
      }

      // floating point types
      await testUnsupportedIndex('''
      @Property(type: PropertyType.float)
      @Index()
      double? tFloat;
      ''');
      await testUnsupportedIndex('''
      @Index()
      double? tDouble;
      ''');

      // vector types
      await testUnsupportedIndex('''
      @Property(type: PropertyType.byteVector)
      @Index()
      List<int>? tByteList;
      ''');
      await testUnsupportedIndex('''
      @Property(type: PropertyType.charVector)
      @Index()
      List<int>? tCharList;
      ''');
      await testUnsupportedIndex('''
      @Property(type: PropertyType.shortVector)
      @Index()
      List<int>? tShortList;
      ''');
      await testUnsupportedIndex('''
      @Property(type: PropertyType.intVector)
      @Index()
      List<int>? tIntList;
      ''');
      await testUnsupportedIndex('''
      @Index()
      List<int>? tLongList;
      ''');
      await testUnsupportedIndex('''
      @Property(type: PropertyType.floatVector)
      @Index()
      List<double>? tFloatList;
      ''');
      await testUnsupportedIndex('''
      @Index()
      List<double>? tDoubleList;
      ''');
      await testUnsupportedIndex('''
      @Index()
      List<String>? tStrings;
      ''');
    });

    test('Plain DateTime warning', () async {
      // Using default type for DateTime (not recommended, but supported)
      final source = sourceFile(
        entity(
          withBody: r'''
          DateTime? warnsForThis;
          ''',
        ),
      );

      final testEnv = GeneratorTestEnv();
      final result = await testEnv.run(source);

      expect(
        result.logs,
        contains(
          isA<LogRecord>()
              .having((r) => r.level, 'level', Level.WARNING)
              .having(
                (r) => r.message,
                'message',
                contains(
                  "DateTime property 'warnsForThis' in entity 'Example' is stored in UTC using millisecond precision",
                ),
              ),
        ),
      );

      // Assert the entity was still successfully created with the DateTime field
      expect(testEnv.model.entities.length, 1);
      final exampleEntity = testEnv.model.entities[0];
      expect(
        exampleEntity.findPropertyByName('warnsForThis')!.type,
        OBXPropertyType.Date,
      );
    });

    test('Finds backlink source if type is unique', () async {
      // Name related classes to be lexically before Example so they are
      // processed first.
      final source = sourceFile('''
        ${entity(withBody: r'''
          final relA = ToMany<A>();
          final relB = ToOne<B>();
        ''')}
        
        ${entity(withName: 'A', withBody: r'''
          @Backlink()
          final backRel = ToMany<Example>();
        ''')}
        
        ${entity(withName: 'B', withBody: r'''
          @Backlink()
          final backRel = ToMany<Example>();
        ''')}
      ''');

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      final entityA = testEnv.model.entities.firstWhere((e) => e.name == 'A');
      var backlinkSourceA = entityA.backlinks.first.source;
      expect(backlinkSourceA, isA<BacklinkSourceRelation>());
      expect((backlinkSourceA as BacklinkSourceRelation).srcRel.name, 'relA');

      final entityB = testEnv.model.entities.firstWhere((e) => e.name == 'B');
      var backlinkSourceB = entityB.backlinks.first.source;
      expect(backlinkSourceB, isA<BacklinkSourceProperty>());
      expect(
        (backlinkSourceB as BacklinkSourceProperty).srcProp.relationField,
        'relB',
      );
    });

    test('Errors if backlink source is not unique', () async {
      final source = sourceFile('''
        ${entity(withBody: r'''
          final relA1 = ToOne<A>();
          final relA2 = ToOne<A>();
          final relA3 = ToMany<A>();
        ''')}
        
        ${entity(withName: 'A', withBody: r'''
          @Backlink()
          final backRel = ToMany<Example>();
        ''')}
      ''');

      await expectGeneratorThrows(
        source,
        'Can\'t determine backlink source for "A.backRel"',
      );
    });

    test('Errors if backlink source does not exist', () async {
      final source = sourceFile('''
        ${entity()}
        
        ${entity(withName: 'A', withBody: r'''
          @Backlink()
          final backRel = ToMany<Example>();
        ''')}
      ''');

      await expectGeneratorThrows(
        source,
        'Failed to find backlink source for "A.backRel" in "Example"',
      );
    });

    test(
      'Does not pick implicit backlink source if explicit one does not exist',
      () async {
        final source = sourceFile('''
          ${entity(withBody: r'''
            final relA1 = ToOne<A>();
            final relA2 = ToMany<A>();
          ''')}
          
          ${entity(withName: 'A', withBody: r'''
            @Backlink('doesnotexist')
            final backRel = ToMany<Example>();
          ''')}
        ''');

        await expectGeneratorThrows(
          source,
          'Failed to find backlink source for "A.backRel" in "Example"',
        );
      },
    );

    test('@TargetIdProperty ToOne annotation', () async {
      final source = sourceFile(
        entity(
          withBody: r'''
          @TargetIdProperty('customerRef')
          final customer = ToOne<Example>();
          ''',
        ),
      );

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      final exampleEntity = testEnv.model.entities[0];
      expect(exampleEntity.findPropertyByName('customerId'), isNull);
      final renamedRelationProperty = exampleEntity.findPropertyByName(
        'customerRef',
      );
      expect(renamedRelationProperty, isNotNull);
      expect(renamedRelationProperty!.type, OBXPropertyType.Relation);
    });

    test('Explicit backlink to renamed ToOne target ID property', () async {
      final source = sourceFile('''
        ${entity(withBody: r'''
          @TargetIdProperty('customerRef')
          final customer = ToOne<Customer>();
        ''')}
        
        ${entity(withName: 'Customer', withBody: r'''
          @Backlink('customer')
          final backRel = ToMany<Example>();
        ''')}
      ''');

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      final customerEntity = testEnv.model.entities.firstWhere(
        (e) => e.name == 'Customer',
      );
      var backlinkSource = customerEntity.backlinks.first.source;
      expect(backlinkSource, isA<BacklinkSourceProperty>());
      expect(
        (backlinkSource as BacklinkSourceProperty).srcProp.relationField,
        'customer',
      );
    });

    test('ToOne target ID property name conflict', () async {
      // Note: unlike in Java, for Dart it's also not supported to "expose" the
      // target ID (relation) property.
      final source = sourceFile(
        entity(
          withBody: r'''
          int? customerId; // conflicts
          final customer = ToOne<Example>();
          ''',
        ),
      );

      await expectGeneratorThrows(
        source,
        'Property name conflicts with the target ID property "customerId"',
      );
    });

    test('HNSW annotation on unsupported type errors', () async {
      final source = sourceFile(
        entity(
          withBody: r'''
          @HnswIndex(dimensions: 3)
          List<double>? coordinates;
          ''',
        ),
      );

      await expectGeneratorThrows(
        source,
        '@HnswIndex is only supported for float vector properties.',
      );
    });

    test('HNSW annotation default', () async {
      final source = sourceFile(
        entity(
          withBody: r'''
          @Property(type: PropertyType.floatVector)
          @HnswIndex(dimensions: 3)
          List<double>? coordinates;
          ''',
        ),
      );

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      // Assert final model created by generator
      final vectorProperty = testEnv.model.entities[0].properties.firstWhere(
        (element) => element.name == "coordinates",
      );
      expect(vectorProperty.flags & OBXPropertyFlags.INDEXED != 0, true);
      expect(vectorProperty.indexId, isNotNull);
      expect(vectorProperty.hnswParams, isNotNull);
      expect(vectorProperty.hnswParams!.dimensions, 3);
      expect(vectorProperty.hnswParams!.neighborsPerNode, isNull);
      expect(vectorProperty.hnswParams!.indexingSearchCount, isNull);
      expect(vectorProperty.hnswParams!.flags, isNull);
      expect(vectorProperty.hnswParams!.distanceType, isNull);
      expect(vectorProperty.hnswParams!.reparationBacklinkProbability, isNull);
      expect(vectorProperty.hnswParams!.vectorCacheHintSizeKB, isNull);
    });

    test('HNSW annotation with all properties', () async {
      final source = sourceFile(
        entity(
          withBody: r'''
          @Property(type: PropertyType.floatVector)
          @HnswIndex(
              dimensions: 3,
              neighborsPerNode: 30,
              indexingSearchCount: 100,
              flags: HnswFlags(
                  debugLogs: true,
                  debugLogsDetailed: true,
                  vectorCacheSimdPaddingOff: true,
                  reparationLimitCandidates: true),
              distanceType: VectorDistanceType.euclidean,
              reparationBacklinkProbability: 0.95,
              vectorCacheHintSizeKB: 2097152)
          List<double>? coordinates;
          ''',
        ),
      );

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      // Assert final model created by generator
      final vectorProperty = testEnv.model.entities[0].properties.firstWhere(
        (element) => element.name == "coordinates",
      );
      expect(vectorProperty.flags & OBXPropertyFlags.INDEXED != 0, true);
      expect(vectorProperty.indexId, isNotNull);
      expect(vectorProperty.hnswParams, isNotNull);
      expect(vectorProperty.hnswParams!.dimensions, 3);
      expect(vectorProperty.hnswParams!.neighborsPerNode, 30);
      expect(vectorProperty.hnswParams!.indexingSearchCount, 100);
      final flags = vectorProperty.hnswParams!.flags;
      expect(flags, isNotNull);
      expect(flags! & OBXHnswFlags.DebugLogs != 0, true);
      expect(flags & OBXHnswFlags.DebugLogsDetailed != 0, true);
      expect(flags & OBXHnswFlags.VectorCacheSimdPaddingOff != 0, true);
      expect(flags & OBXHnswFlags.ReparationLimitCandidates != 0, true);
      expect(
        vectorProperty.hnswParams!.distanceType,
        OBXVectorDistanceType.Euclidean,
      );
      expect(vectorProperty.hnswParams!.reparationBacklinkProbability, 0.95);
      expect(vectorProperty.hnswParams!.vectorCacheHintSizeKB, 2097152);
    });

    test('Sync annotation with shared global IDs', () async {
      final source = sourceFile(r'''
      @Entity()
      @Sync(sharedGlobalIds: true)
      class Example {
        @Id(assignable: true)
        int id = 0;
      }
      ''');

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      // Assert final model created by generator
      var entity = testEnv.model.entities[0];
      expect(entity.flags & OBXEntityFlags.SYNC_ENABLED != 0, true);
      expect(entity.flags & OBXEntityFlags.SHARED_GLOBAL_IDS != 0, true);
      // Only a single property
      final idProperty = testEnv.model.entities[0].properties[0];
      expect(idProperty.flags & OBXPropertyFlags.ID_SELF_ASSIGNABLE != 0, true);
    });
  });

  group('SyncClock and SyncPrecedence annotations', () {
    test(
      '@SyncClock sets SYNC_CLOCK and @SyncPrecedence sets SYNC_PRECEDENCE property flags',
      () async {
        final source = sourceFile(
          entity(
            sync: true,
            withBody: r'''
              @SyncClock()
              int? clock;

              @SyncPrecedence()
              int? precedence;
              ''',
          ),
        );

        final testEnv = GeneratorTestEnv();
        await testEnv.run(source);

        final exampleEntity = testEnv.model.entities[0];
        expect(
          exampleEntity
              .findPropertyByName('clock')!
              .hasFlag(OBXPropertyFlags.SYNC_CLOCK),
          isTrue,
        );
        expect(
          exampleEntity
              .findPropertyByName('precedence')!
              .hasFlag(OBXPropertyFlags.SYNC_PRECEDENCE),
          isTrue,
        );
      },
    );

    Future<void> testAnnotationOnEntityWithoutSync(String annotation) async {
      final source = sourceFile(
        entity(
          withBody: '''
              $annotation()
              int? field;
              ''',
        ),
      );
      await expectGeneratorThrows(source, 'TODO');
    }

    test('@SyncClock on entity without @Sync errors', () async {
      await testAnnotationOnEntityWithoutSync('@SyncClock');
    });

    test('@SyncPrecedence on entity without @Sync errors', () async {
      await testAnnotationOnEntityWithoutSync('@SyncPrecedence');
    });

    Future<void> testDuplicateAnnotationOnEntity(String annotation) async {
      final source = sourceFile(
        entity(
          sync: true,
          withBody: '''
              $annotation()
              int? field1;

              $annotation()
              int? field2;
              ''',
        ),
      );
      await expectGeneratorThrows(source, 'TODO');
    }

    test('Two @SyncClock annotations on the same entity errors', () async {
      await testDuplicateAnnotationOnEntity('@SyncClock');
    });

    test('Two @SyncPrecedence annotations on the same entity errors', () async {
      await testDuplicateAnnotationOnEntity('@SyncPrecedence');
    });

    test(
      'Both @SyncClock and @SyncPrecedence on the same property errors',
      () async {
        final source = sourceFile(
          entity(
            sync: true,
            withBody: r'''
              @SyncClock()
              @SyncPrecedence()
              int? clockAndPrecedence;
              ''',
          ),
        );

        await expectGeneratorThrows(source, 'TODO');
      },
    );

    Future<void> testAnnotationOnNonIntProperty(String annotation) async {
      final source = sourceFile(
        entity(
          sync: true,
          withBody: '''
            $annotation()
            String? field;
            ''',
        ),
      );
      await expectGeneratorThrows(source, 'TODO');
    }

    test('@SyncClock on a non-int property errors', () async {
      await testAnnotationOnNonIntProperty('@SyncClock');
    });

    test('@SyncPrecedence on a non-int property errors', () async {
      await testAnnotationOnNonIntProperty('@SyncPrecedence');
    });
  });

  group("ExternalType and ExternalName annotations", () {
    test('annotations work on @Entity', () async {
      final source = sourceFile(r'''
      @Entity()
      @ExternalName(name: 'my-mongo-entity')     
      class Example {
        @Id()
        int id = 0;
      }
      ''');

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      final entity = testEnv.model.entities[0];
      expect(entity.externalName, "my-mongo-entity");
    });

    test('annotations work on properties', () async {
      final source = sourceFile(
        entity(
          withBody: r'''
          @Property(type: PropertyType.byteVector)
          @ExternalType(type: ExternalPropertyType.mongoId)
          List<int>? mongoId;
          
          @ExternalType(type: ExternalPropertyType.uuid)
          @ExternalName(name: 'my-mongo-uuid')
          List<int>? mongoUuid;
          ''',
        ),
      );

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      final property1 = testEnv.model.entities[0].properties.firstWhere(
        (element) => element.name == "mongoId",
      );
      expect(property1.externalType, OBXExternalPropertyType.MongoId);

      final property2 = testEnv.model.entities[0].properties.firstWhere(
        (element) => element.name == "mongoUuid",
      );
      expect(property2.externalType, OBXExternalPropertyType.Uuid);
      expect(property2.externalName, "my-mongo-uuid");
    });

    test('annotations work on ToMany (standalone) relations', () async {
      final source = sourceFile(
        entity(
          withName: 'Student',
          withBody: r'''
          @ExternalType(type: ExternalPropertyType.mongoId)
          final rel1 = ToMany<Student>();
          
          @ExternalType(type: ExternalPropertyType.uuid)
          @ExternalName(name: 'my-courses-rel')
          final rel2 = ToMany<Student>();
          ''',
        ),
      );

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      final relation1 = testEnv.model.entities[0].relations.firstWhere(
        (element) => element.name == "rel1",
      );
      expect(relation1.externalType, OBXExternalPropertyType.MongoId);

      final relation2 = testEnv.model.entities[0].relations.firstWhere(
        (element) => element.name == "rel2",
      );
      expect(relation2.externalType, OBXExternalPropertyType.Uuid);
      expect(relation2.externalName, "my-courses-rel");
    });
  });

  group("Flex properties", () {
    expectFlexProperties(List<ModelProperty> properties, int number) {
      expect(properties.length, number);
      for (var property in properties) {
        if (property.name != 'id') {
          expect(
            property.type,
            OBXPropertyType.Flex,
            reason: 'Property "${property.name}" should be of Flex type',
          );
        }
      }
    }

    test('Flex Map type detection', () async {
      final source = sourceFile(
        entity(
          withName: 'FlexEntity',
          withBody: r'''
          // Auto-detected Map<String, dynamic> - nullable
          Map<String, dynamic>? flexDynamic;
        
          // Auto-detected Map<String, Object?> - nullable
          Map<String, Object?>? flexObject;
          
          // Auto-detected Map<String, Object> (non-nullable values) - nullable
          Map<String, Object>? flexObjectNonNull;
        
          // Non-nullable with default empty map
          Map<String, dynamic> flexNonNull = {};
        
          // Explicit annotation
          @Property(type: PropertyType.flex)
          Map<String, dynamic>? flexExplicit;
          ''',
        ),
      );

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      var properties = testEnv.model.entities[0].properties;
      expectFlexProperties(properties, 6);
    });

    test('Flex List type detection', () async {
      final source = sourceFile(
        entity(
          withName: 'FlexEntity',
          withBody: r'''
          // Auto-detected List<dynamic> - nullable
          List<dynamic>? flexDynamic;
        
          // Auto-detected List<Object?> - nullable
          List<Object?>? flexObject;
        
          // Auto-detected List<Object> (non-nullable elements) - nullable
          List<Object>? flexObjectNonNull;
        
          // Non-nullable with default empty list
          List<dynamic> flexNonNull = [];
        
          // Auto-detected List<Map<String, dynamic>> - nullable
          List<Map<String, dynamic>>? flexListOfMaps;
        
          // Auto-detected List<Map<String, Object?>> - nullable
          List<Map<String, Object?>>? flexListOfMapsObject;
        
          // Explicit annotation
          @Property(type: PropertyType.flex)
          List<dynamic>? flexExplicit;
          ''',
        ),
      );

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      var properties = testEnv.model.entities[0].properties;
      expectFlexProperties(properties, 8);
    });

    test('Flex Value type detection', () async {
      final source = sourceFile(
        entity(
          withName: 'FlexEntity',
          withBody: r'''
          // Auto-detected dynamic
          dynamic flexDynamic;
        
          // Auto-detected Object?
          Object? flexObject;
          
          // Explicit annotation still works
          @Property(type: PropertyType.flex)
          dynamic flexDynamicExplicit;
          
          @Property(type: PropertyType.flex)
          Object? flexObjectExplicit;
          ''',
        ),
      );

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      var properties = testEnv.model.entities[0].properties;
      expectFlexProperties(properties, 5);
    });

    test('Flex unsupported type errors', () async {
      final source = sourceFile(
        entity(
          withName: 'FlexEntity',
          withBody: r'''
          @Property(type: PropertyType.flex)
          Object unsupported;  
          ''',
        ),
      );

      await expectGeneratorThrows(
        source,
        "'FlexEntity.unsupported': PropertyType.flex can only be used with",
      );
    });
  });

  group('GeneratorVersion', () {
    test('generated code includes GeneratorVersion parameter', () async {
      final source = sourceFile(entity());

      final testEnv = GeneratorTestEnv();
      // Verify the generated code contains the GeneratorVersion parameter.
      final expectedVersion =
          'generatorVersion: obx_int.GeneratorVersion.${generatorVersionLatest.name}';
      await testEnv.run(
        source,
        generatedCodeMatcher: decodedMatches(
          predicate<String>(
            (content) => content.contains(expectedVersion),
            'contains "$expectedVersion"',
          ),
        ),
      );
    });
  });
}
