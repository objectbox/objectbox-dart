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
        OBXHnswFlags.DebugLogs | OBXHnswFlags.VectorCacheSimdPaddingOff);
  });

  test("HnswDistanceType mapped as expected", () {
    expect(
        HnswDistanceType.euclidean.toConstant(), OBXHnswDistanceType.Euclidean);
  });

  test("ModelHnswParams maps values", () {
    final flags = HnswFlags(debugLogs: true);
    final original = HnswIndex(
        dimensions: 2,
        neighborsPerNode: 30,
        indexingSearchCount: 100,
        flags: flags,
        distanceType: HnswDistanceType.euclidean,
        reparationBacklinkProbability: 0.95,
        vectorCacheHintSizeKB: 2097152);

    // From annotation to model class
    final modelParams = ModelHnswParams.fromAnnotation(original);
    // From model class to (JSON) map and back
    final converted = ModelHnswParams.fromMap(modelParams.toMap())!;
    expect(converted.dimensions, 2);
    expect(converted.neighborsPerNode, 30);
    expect(converted.indexingSearchCount, 100);
    expect(converted.flags, flags.toFlags());
    expect(converted.distanceType, OBXHnswDistanceType.Euclidean);
    expect(converted.reparationBacklinkProbability, 0.95);
    expect(converted.vectorCacheHintSizeKB, 2097152);
  });

  test("ModelHnswParams rejects illegal values", () {
    expect(
        () => ModelHnswParams.fromAnnotation(HnswIndex(dimensions: 0)),
        throwsA(
            isA<ArgumentError>().having((e) => e.name, "name", "dimensions")));
    expect(
        () => ModelHnswParams.fromAnnotation(
            HnswIndex(dimensions: 1, neighborsPerNode: 0)),
        throwsA(isA<ArgumentError>()
            .having((e) => e.name, "name", "neighborsPerNode")));
    expect(
        () => ModelHnswParams.fromAnnotation(
            HnswIndex(dimensions: 1, indexingSearchCount: 0)),
        throwsA(isA<ArgumentError>()
            .having((e) => e.name, "name", "indexingSearchCount")));
    expect(
        () => ModelHnswParams.fromAnnotation(
            HnswIndex(dimensions: 1, reparationBacklinkProbability: -1.0)),
        throwsA(isA<ArgumentError>()
            .having((e) => e.name, "name", "reparationBacklinkProbability")));
    expect(
        () => ModelHnswParams.fromAnnotation(
            HnswIndex(dimensions: 1, vectorCacheHintSizeKB: 0)),
        throwsA(isA<ArgumentError>()
            .having((e) => e.name, "name", "vectorCacheHintSizeKB")));
  });
}
