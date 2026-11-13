import 'package:objectbox/internal.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'objectbox.g.dart';

void main() {
  test("HnswFlags combined as expected", () {
    expect(HnswFlags().toFlags(), 0);
    expect(HnswFlags(debugLogs: true).toFlags(), OBXHnswFlags.DebugLogs);
    expect(
      HnswFlags(debugLogs: true, vectorCacheSimdPaddingOff: true).toFlags(),
      OBXHnswFlags.DebugLogs | OBXHnswFlags.VectorCacheSimdPaddingOff,
    );
    expect(HnswFlags(lateInit: true).toFlags(), OBXHnswFlags.LateInit);
  });

  test("Distance type mapped as expected", () {
    expect(
      VectorDistanceType.euclidean.toConstant(),
      OBXVectorDistanceType.Euclidean,
    );
    expect(
      VectorDistanceType.cosine.toConstant(),
      OBXVectorDistanceType.Cosine,
    );
    expect(
      VectorDistanceType.dotProduct.toConstant(),
      OBXVectorDistanceType.DotProduct,
    );
    expect(
      VectorDistanceType.dotProductNonNormalized.toConstant(),
      OBXVectorDistanceType.DotProductNonNormalized,
    );
    expect(VectorDistanceType.geo.toConstant(), OBXVectorDistanceType.Geo);
  });

  test("Vector quantization mapped as expected", () {
    expect(VectorQuantization.none.toConstant(), OBXHnswQuantType.None);
    expect(
      VectorQuantization.turboQuant1.toConstant(),
      OBXHnswQuantType.TurboQuant1,
    );
    expect(
      VectorQuantization.turboQuant1_5.toConstant(),
      OBXHnswQuantType.TurboQuant1_5,
    );
    expect(
      VectorQuantization.turboQuant2.toConstant(),
      OBXHnswQuantType.TurboQuant2,
    );
    expect(
      VectorQuantization.turboQuant3.toConstant(),
      OBXHnswQuantType.TurboQuant3,
    );
    expect(
      VectorQuantization.turboQuant4.toConstant(),
      OBXHnswQuantType.TurboQuant4,
    );
    expect(
      VectorQuantization.scalarQuant8.toConstant(),
      OBXHnswQuantType.ScalarQuant8,
    );
  });

  test("Vector search and build levels mapped as expected", () {
    // The C API levels are numbered from 1 (fastest) to 10 (highest quality).
    for (final level in VectorSearchLevel.values) {
      expect(level.toConstant(), level.index + 1);
    }
    expect(VectorSearchLevel.values.length, 10);
    expect(
      VectorSearchLevel.l1Fastest.toConstant(),
      OBXHnswSearchLevel.L1_Fastest,
    );
    expect(
      VectorSearchLevel.l4Balanced.toConstant(),
      OBXHnswSearchLevel.L4_Balanced,
    );
    expect(
      VectorSearchLevel.l10QualityMax.toConstant(),
      OBXHnswSearchLevel.L10_QualityMax,
    );

    for (final level in VectorBuildLevel.values) {
      expect(level.toConstant(), level.index + 1);
    }
    expect(VectorBuildLevel.values.length, 10);
    expect(
      VectorBuildLevel.l1Fastest.toConstant(),
      OBXHnswBuildLevel.L1_Fastest,
    );
    expect(
      VectorBuildLevel.l4Balanced.toConstant(),
      OBXHnswBuildLevel.L4_Balanced,
    );
    expect(
      VectorBuildLevel.l10QualityMax.toConstant(),
      OBXHnswBuildLevel.L10_QualityMax,
    );
  });

  test("ModelHnswParams maps values", () {
    final flags = HnswFlags(debugLogs: true);
    final original = HnswIndex(
      dimensions: 2,
      neighborsPerNode: 30,
      indexingSearchCount: 100,
      flags: flags,
      distanceType: VectorDistanceType.euclidean,
      reparationBacklinkProbability: 0.95,
      vectorCacheHintSizeKB: 2097152,
      quantization: VectorQuantization.scalarQuant8,
      quantizationOversample: 2.0,
      quantizationRescoreFactor: 1.5,
      searchLevel: VectorSearchLevel.l6Quality,
      buildLevel: VectorBuildLevel.l2VeryFast,
      bruteForceMaxCandidates: 100,
      filteredSearchMaxNodes: 1000,
      randomSeed: 0x123456789ABCDEF0,
    );

    // From annotation to model class
    final modelParams = ModelHnswParams.fromAnnotation(original);
    // From model class to (JSON) map and back
    final converted = ModelHnswParams.fromMap(modelParams.toMap())!;
    expect(converted.dimensions, 2);
    expect(converted.neighborsPerNode, 30);
    expect(converted.indexingSearchCount, 100);
    expect(converted.flags, flags.toFlags());
    expect(converted.distanceType, OBXVectorDistanceType.Euclidean);
    expect(converted.reparationBacklinkProbability, 0.95);
    expect(converted.vectorCacheHintSizeKB, 2097152);
    expect(converted.quantization, OBXHnswQuantType.ScalarQuant8);
    expect(converted.quantizationOversample, 2.0);
    expect(converted.quantizationRescoreFactor, 1.5);
    expect(converted.searchLevel, OBXHnswSearchLevel.L6_Quality);
    expect(converted.buildLevel, OBXHnswBuildLevel.L2_VeryFast);
    expect(converted.bruteForceMaxCandidates, 100);
    expect(converted.filteredSearchMaxNodes, 1000);
    expect(converted.randomSeed, 0x123456789ABCDEF0);

    // Not set values stay not set
    final defaults =
        ModelHnswParams.fromMap(
          ModelHnswParams.fromAnnotation(HnswIndex(dimensions: 2)).toMap(),
        )!;
    expect(defaults.quantization, isNull);
    expect(defaults.quantizationOversample, isNull);
    expect(defaults.quantizationRescoreFactor, isNull);
    expect(defaults.searchLevel, isNull);
    expect(defaults.buildLevel, isNull);
    expect(defaults.bruteForceMaxCandidates, isNull);
    expect(defaults.filteredSearchMaxNodes, isNull);
    expect(defaults.randomSeed, isNull);
  });

  test("ModelHnswParams dimensions optional with late init", () {
    final lateInit = ModelHnswParams.fromAnnotation(
      HnswIndex(flags: HnswFlags(lateInit: true)),
    );
    expect(lateInit.dimensions, isNull);
    expect(lateInit.flags, OBXHnswFlags.LateInit);
    expect(lateInit.toCodeString('obx'), isNot(contains('dimensions')));
    expect(ModelHnswParams.fromMap(lateInit.toMap())!.dimensions, isNull);
    // Dimensions may be given with late init
    expect(
      ModelHnswParams.fromAnnotation(
        HnswIndex(dimensions: 3, flags: HnswFlags(lateInit: true)),
      ).dimensions,
      3,
    );
  });

  test("ModelHnswParams rejects illegal values", () {
    expect(
      () => ModelHnswParams.fromAnnotation(HnswIndex(dimensions: 0)),
      throwsA(isA<ArgumentError>().having((e) => e.name, "name", "dimensions")),
    );
    // Required without late init
    expect(
      () => ModelHnswParams.fromAnnotation(HnswIndex()),
      throwsA(isA<ArgumentError>().having((e) => e.name, "name", "dimensions")),
    );
    expect(
      () => ModelHnswParams.fromAnnotation(
        HnswIndex(dimensions: 1, neighborsPerNode: 0x100000000),
      ),
      throwsA(
        isA<ArgumentError>().having((e) => e.name, "name", "neighborsPerNode"),
      ),
    );
    expect(
      () => ModelHnswParams.fromAnnotation(
        HnswIndex(dimensions: 1, neighborsPerNode: 0),
      ),
      throwsA(
        isA<ArgumentError>().having((e) => e.name, "name", "neighborsPerNode"),
      ),
    );
    expect(
      () => ModelHnswParams.fromAnnotation(
        HnswIndex(dimensions: 1, indexingSearchCount: 0),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.name,
          "name",
          "indexingSearchCount",
        ),
      ),
    );
    expect(
      () => ModelHnswParams.fromAnnotation(
        HnswIndex(dimensions: 1, reparationBacklinkProbability: -1.0),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.name,
          "name",
          "reparationBacklinkProbability",
        ),
      ),
    );
    expect(
      () => ModelHnswParams.fromAnnotation(
        HnswIndex(dimensions: 1, vectorCacheHintSizeKB: 0),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.name,
          "name",
          "vectorCacheHintSizeKB",
        ),
      ),
    );
    void expectRejected(HnswIndex index, String name) => expect(
      () => ModelHnswParams.fromAnnotation(index),
      throwsA(isA<ArgumentError>().having((e) => e.name, "name", name)),
    );
    expectRejected(
      HnswIndex(dimensions: 1, quantizationOversample: 0.99),
      "quantizationOversample",
    );
    expectRejected(
      HnswIndex(dimensions: 1, quantizationRescoreFactor: 0.0),
      "quantizationRescoreFactor",
    );
    expectRejected(
      HnswIndex(dimensions: 1, bruteForceMaxCandidates: 0),
      "bruteForceMaxCandidates",
    );
    expectRejected(
      HnswIndex(dimensions: 1, bruteForceMaxCandidates: 0x100000000),
      "bruteForceMaxCandidates",
    );
    expectRejected(
      HnswIndex(dimensions: 1, filteredSearchMaxNodes: 0),
      "filteredSearchMaxNodes",
    );
    expectRejected(
      HnswIndex(dimensions: 1, filteredSearchMaxNodes: 0x100000000),
      "filteredSearchMaxNodes",
    );
    expectRejected(HnswIndex(dimensions: 1, randomSeed: -1), "randomSeed");
    // Lowest legal values are accepted
    final lowest = ModelHnswParams.fromAnnotation(
      HnswIndex(
        dimensions: 1,
        quantizationOversample: 1.0,
        quantizationRescoreFactor: 1.0,
        bruteForceMaxCandidates: 1,
        filteredSearchMaxNodes: 1,
        randomSeed: 0,
      ),
    );
    expect(lowest.quantizationOversample, 1.0);
    expect(lowest.filteredSearchMaxNodes, 1);
    expect(lowest.randomSeed, 0);
  });
}
