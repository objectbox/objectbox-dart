import 'dart:io';

import 'package:logging/logging.dart';
import 'package:objectbox/internal.dart';
import 'package:objectbox_generator/src/builder_dirs.dart';
import 'package:objectbox_generator/src/code_builder.dart';
import 'package:objectbox_generator/src/config.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import 'generator_test_env.dart';

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
      final source = r'''
      library example;     
      import 'package:objectbox/objectbox.dart';
      
      @Entity()
      class Example {
        @Id()
        int id = 0;
        
        // implicit PropertyType.bool
        bool? tBool;
        
        // implicitly determined types
        String? tString;
      }
      ''';

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
      final testEnv = GeneratorTestEnv();

      testUnsupportedIndex(String unsupportedField) async {
        final source = '''
        library example;     
        import 'package:objectbox/objectbox.dart';
        
        @Entity()
        class Example {
          @Id()
          int id = 0;
        
          $unsupportedField
        }
        ''';

        final result = await testEnv.run(source, ignoreOutput: true);

        expect(result.builderResult.succeeded, false);
        expect(
          result.logs,
          contains(
            isA<LogRecord>()
                .having((r) => r.level, 'level', Level.SEVERE)
                .having(
                  (r) => r.message,
                  'message',
                  contains('@Index/@Unique is not supported'),
                ),
          ),
        );
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

    test('Finds backlink source if type is unique', () async {
      final source = r'''
      library example;     
      import 'package:objectbox/objectbox.dart';
      
      @Entity()
      class Example {
        @Id()
        int id = 0;
        
        final relA = ToMany<A>();
        final relB = ToOne<B>();
      }
      
      // Name related classes to be lexically before Example so they are
      // processed first.
       
      @Entity()
      class A {
        @Id()
        int id = 0;
        
        @Backlink()
        final backRel = ToMany<Example>();
      }
      
      @Entity()
      class B {
        @Id()
        int id = 0;
        
        @Backlink()
        final backRel = ToMany<Example>();
      }
      ''';

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
      final source = r'''
      library example;     
      import 'package:objectbox/objectbox.dart';
      
      @Entity()
      class Example {
        @Id()
        int id = 0;
        
        final relA1 = ToOne<A>();
        final relA2 = ToOne<A>();
        final relA3 = ToMany<A>();
      }
       
      @Entity()
      class A {
        @Id()
        int id = 0;
        
        @Backlink()
        final backRel = ToMany<Example>();
      }
      ''';

      final testEnv = GeneratorTestEnv();
      final result = await testEnv.run(source, ignoreOutput: true);

      expect(result.builderResult.succeeded, false);
      expect(
        result.logs,
        contains(
          isA<LogRecord>()
              .having((r) => r.level, 'level', Level.SEVERE)
              .having(
                (r) => r.message,
                'message',
                contains('Can\'t determine backlink source for "A.backRel"'),
              ),
        ),
      );
    });

    test('@TargetIdProperty ToOne annotation', () async {
      final source = r'''
      library example;     
      import 'package:objectbox/objectbox.dart';
      
      @Entity()
      class Example {
        @Id()
        int id = 0;
        
        @TargetIdProperty('customerRef')
        final customer = ToOne<Example>();
      }
      ''';

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

    test('ToOne target ID property name conflict', () async {
      // Note: unlike in Java, for Dart it's also not supported to "expose" the
      // target ID (relation) property.
      final source = r'''
      library example;     
      import 'package:objectbox/objectbox.dart';
      
      @Entity()
      class Example {
        @Id()
        int id = 0;
        int? customerId; // conflicts
        final customer = ToOne<Example>();
      }
      ''';

      final testEnv = GeneratorTestEnv();
      final result = await testEnv.run(source, ignoreOutput: true);

      expect(result.builderResult.succeeded, false);
      expect(
        result.logs,
        contains(
          isA<LogRecord>()
              .having((r) => r.level, 'level', Level.SEVERE)
              .having(
                (r) => r.message,
                'message',
                contains(
                  'Property name conflicts with the target ID property "customerId"',
                ),
              ),
        ),
      );
    });

    test('HNSW annotation on unsupported type errors', () async {
      final source = r'''
      library example;     
      import 'package:objectbox/objectbox.dart';
      
      @Entity()
      class Example {
        @Id()
        int id = 0;
        
        @HnswIndex(dimensions: 3)
        List<double>? coordinates;
      }
      ''';

      final testEnv = GeneratorTestEnv();
      final result = await testEnv.run(source, ignoreOutput: true);

      expect(result.builderResult.succeeded, false);
      expect(
        result.logs,
        contains(
          isA<LogRecord>()
              .having((r) => r.level, 'level', Level.SEVERE)
              .having(
                (r) => r.message,
                'message',
                contains(
                  '@HnswIndex is only supported for float vector properties.',
                ),
              ),
        ),
      );
    });

    test('HNSW annotation default', () async {
      final source = r'''
      library example;     
      import 'package:objectbox/objectbox.dart';
      
      @Entity()
      class Example {
        @Id()
        int id = 0;
        
        @Property(type: PropertyType.floatVector)
        @HnswIndex(dimensions: 3)
        List<double>? coordinates;
      }
      ''';

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
      final source = r'''
      library example;     
      import 'package:objectbox/objectbox.dart';
      
      @Entity()
      class Example {
        @Id()
        int id = 0;
        
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
      }
      ''';

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
      final source = r'''
      library example;     
      import 'package:objectbox/objectbox.dart';
      
      @Entity()
      @Sync(sharedGlobalIds: true)
      class Example {
        @Id(assignable: true)
        int id = 0;
      }
      ''';

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

  group("ExternalType and ExternalName annotations", () {
    test('annotations work on @Entity', () async {
      final source = r'''
      library example;     
      import 'package:objectbox/objectbox.dart';
      
      @Entity()
      @ExternalName(name: 'my-mongo-entity')     
      class Example {
        @Id()
        int id = 0;
      }
      ''';

      final testEnv = GeneratorTestEnv();
      await testEnv.run(source);

      final entity = testEnv.model.entities[0];
      expect(entity.externalName, "my-mongo-entity");
    });

    test('annotations work on properties', () async {
      final source = r'''
      library example;     
      import 'package:objectbox/objectbox.dart';
      
      @Entity()
      class Example {
        @Id()
        int id = 0;
        
        @Property(type: PropertyType.byteVector)
        @ExternalType(type: ExternalPropertyType.mongoId)
        List<int>? mongoId;
        
        @ExternalType(type: ExternalPropertyType.uuid)
        @ExternalName(name: 'my-mongo-uuid')
        List<int>? mongoUuid;
      }
      ''';

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
      final source = r'''
      library example;     
      import 'package:objectbox/objectbox.dart';
      
      @Entity()
      class Student{
        int id;
        
        @ExternalType(type: ExternalPropertyType.mongoId)
        final rel1 = ToMany<Student>();
        
        @ExternalType(type: ExternalPropertyType.uuid)
        @ExternalName(name: 'my-courses-rel')
        final rel2 = ToMany<Student>();
      }
      ''';

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
}
