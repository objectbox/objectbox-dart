import 'dart:io';
import 'dart:math' show Random;

import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

/// This mirrors HNSW object tests in the core library with a focus on Dart API.
void main() {
  late TestEnv env;
  late Box<HnswObject> box;

  setUp(() {
    env = TestEnv('hnsw');
    box = env.store.box<HnswObject>();
  });
  tearDown(() => env.closeAndDelete());

  test('query', () async {
    box.putMany(
      List.generate(10, (index) {
        final i = index + 1; // start at 1
        final value = i.toDouble();
        return HnswObject()
          ..name = "node$i"
          ..floatVector = [value, value];
      }),
    );

    final searchVector = [5.0, 4.5];
    final query =
        box
            .query(HnswObject_.floatVector.nearestNeighborsF32(searchVector, 2))
            .build();
    addTearDown(() => query.close());

    // Standard search
    final regularQuery = await query.findAsync();
    expect(regularQuery.length, 2);
    // For regular queries, the results are ordered by their ID (not distance)
    final object4 = regularQuery[0];
    final object5 = regularQuery[1];
    expect(object4.name, "node4");
    expect(object5.name, "node5");

    // Find nearest 3 nodes (IDs) with score
    query.param(HnswObject_.floatVector).nearestNeighborsF32(searchVector, 3);
    final withIds = await query.findIdsWithScoresAsync();
    expect(withIds.length, 3);
    expect(withIds[0].id, object5.id);
    expect(withIds[0].score, 0.25);
    expect(withIds[1].id, object4.id);
    expect(withIds[1].score, 1.25);
    expect(withIds[2].id, object5.id + 1);
    expect(withIds[2].score, 3.25);

    // Find nearest 3 nodes (objects) with score
    final withObjects = await query.findWithScoresAsync();
    expect(withObjects.length, 3);
    expect(withObjects[0].object.name, "node5");
    expect(withObjects[0].score, 0.25);
    expect(withObjects[1].object.name, "node4");
    expect(withObjects[1].score, 1.25);
    expect(withObjects[2].object.name, "node6");
    expect(withObjects[2].score, 3.25);

    // Find the closest node only
    query.param(HnswObject_.floatVector).nearestNeighborsF32(searchVector, 1);
    final closest = query.findUnique()!;
    expect(closest.name, "node5");

    // Set another vector and find the closest node to it
    final searchVector2 = [7.7, 7.7];
    query.param(HnswObject_.floatVector).nearestNeighborsF32(searchVector2, 1);
    final closest2 = query.findUnique()!;
    expect(closest2.name, "node8");
  });

  test('vectorSearchCitiesGeo', () {
    // capital cities across Europe
    List<String> cities = ["Berlin", "Paris", "Rome", "Madrid", "London"];
    List<List<double>> coordinates = [
      [52.5200, 13.4050],
      [48.8566, 2.3522],
      [41.9028, 12.4964],
      [40.4168, -3.7038],
      [51.5074, -0.1278],
    ];

    box.putMany(
      List.generate(cities.length, (i) {
        return HnswObject()
          ..name = cities[i]
          ..floatVectorGeoCoordinates = coordinates[i];
      }),
    );

    // lat/lng for Munich
    final List<double> searchVector = [48.1371, 11.5754];

    final query =
        box
            .query(
              HnswObject_.floatVectorGeoCoordinates.nearestNeighborsF32(
                searchVector,
                5,
              ),
            )
            .build();
    addTearDown(() => query.close());

    final nearestCities = query.find();
    expect(nearestCities.length, 5);
    expect(nearestCities[0].name, "Berlin");
    expect(nearestCities[1].name, "Paris");
    expect(nearestCities[2].name, "Rome");
    expect(nearestCities[3].name, "Madrid");
    expect(nearestCities[4].name, "London");
  });

  test('find offset limit', () {
    box.putMany(
      List.generate(15, (index) {
        final i = index + 1; // start at 1
        final value = i.toDouble();
        return HnswObject()
          ..name = "node_$i"
          ..floatVector = [value, value];
      }),
    );

    final searchVector = [3.1, 3.1];
    final maxResultCount = 4;
    final query =
        box
            .query(
              HnswObject_.floatVector.nearestNeighborsF32(
                searchVector,
                maxResultCount,
              ),
            )
            .build();
    addTearDown(() => query.close());

    // No offset
    // Note: score-based find defaults to score-based result ordering
    final expectedNoOffset = [3, 4, 2, 5];
    expect(query.findWithScores().map((e) => e.object.id), expectedNoOffset);
    expect(query.findIdsWithScores().map((e) => e.id), expectedNoOffset);
    expect(query.findIds(), [2, 3, 4, 5]);

    // Offset 1
    query.offset = 1;
    final expectedOffset1 = [4, 2, 5];
    expect(query.findWithScores().map((e) => e.object.id), expectedOffset1);
    expect(query.findIdsWithScores().map((e) => e.id), expectedOffset1);
    expect(query.findIds(), [3, 4, 5]);

    // Offset = nearest-neighbour max search count
    query.offset = maxResultCount;
    final empty = [];
    expect(query.findWithScores().map((e) => e.object.id), empty);
    expect(query.findIdsWithScores().map((e) => e.id), empty);
    expect(query.findIds(), empty);

    // Offset out of bounds
    query.offset = 100;
    expect(query.findWithScores().map((e) => e.object.id), empty);
    expect(query.findIdsWithScores().map((e) => e.id), empty);
    expect(query.findIds(), empty);

    // Check limit 5 to 1
    query.offset = 0;
    query.param(HnswObject_.floatVector).nearestNeighborsF32([8.9, 8.8], 5);
    final expectedLimit = [9, 8, 10, 7, 11];
    for (int limit = 5; limit > 0; --limit) {
      query.limit = limit;
      expect(query.findWithScores().map((e) => e.object.id), expectedLimit);
      expect(query.findIdsWithScores().map((e) => e.id), expectedLimit);

      expectedLimit.removeLast(); // for next iteration
    }

    // Check offset & limit together
    query
      ..offset = 1
      ..limit = 5;
    final expectedSkip1 = [8, 10, 7, 11];
    expect(query.findWithScores().map((e) => e.object.id), expectedSkip1);
    expect(query.findIdsWithScores().map((e) => e.id), expectedSkip1);

    query.limit = 3;
    final expectedSkip1Limit3 = [8, 10, 7];
    expect(query.findWithScores().map((e) => e.object.id), expectedSkip1Limit3);
    expect(query.findIdsWithScores().map((e) => e.id), expectedSkip1Limit3);

    query
      ..offset = 2
      ..limit = 2;
    final expectedSkip2Limit2 = [10, 7];
    expect(query.findWithScores().map((e) => e.object.id), expectedSkip2Limit2);
    expect(query.findIdsWithScores().map((e) => e.id), expectedSkip2Limit2);
  });

  test('filtered search name', () {
    final ids = env.store.box<RelatedNamedEntity>().putMany([
      RelatedNamedEntity()..name = "Apple",
      RelatedNamedEntity()..name = "Banana",
      RelatedNamedEntity()..name = "Misc",
    ]);
    final appleGroupId = ids[0];
    final bananaGroupId = ids[1];
    final miscGroupId = ids[2];

    box.putMany([
      HnswObject()
        ..name = "Banana tree"
        ..floatVector = [-1.5, -1.5]
        ..rel.targetId = bananaGroupId,
      HnswObject()
        ..name = "Bunch of banana"
        ..floatVector = [-0.5, -0.5]
        ..rel.targetId = bananaGroupId,
      HnswObject()
        ..name = "Apple seed"
        ..floatVector = [0.5, 0.5]
        ..rel.targetId = appleGroupId,
      HnswObject()
        ..name = "Banana"
        ..floatVector = [1.5, 1.5]
        ..rel.targetId = bananaGroupId,
      HnswObject()
        ..name = "Apple"
        ..floatVector = [2.5, 2.5]
        ..rel.targetId = appleGroupId,
      HnswObject()
        ..name = "Apple juice"
        ..floatVector = [3.5, 3.5]
        ..rel.targetId = appleGroupId,
      HnswObject()
        ..name = "Peach"
        ..floatVector = [4.5, 4.5]
        ..rel.targetId = miscGroupId,
      HnswObject()
        ..name = "appleication"
        ..floatVector = [5.5, 5.5]
        ..rel.targetId = miscGroupId,
      HnswObject()
        ..name = "One banana"
        ..floatVector = [6.5, 6.5]
        ..rel.targetId = miscGroupId,
    ]);

    // Search nearest starting with "Apple"
    final queryApple =
        box
            .query(
              HnswObject_.floatVector
                  .nearestNeighborsF32([2.7, 2.5], 9)
                  .and(HnswObject_.name.startsWith("Apple")),
            )
            .build();
    addTearDown(() => queryApple.close());
    final apples = queryApple.findWithScores();
    expect(apples.length, 3);
    expect(apples[0].object.id, 5);
    expect(apples[0].object.name, "Apple");
    expect(apples[1].object.id, 6);
    expect(apples[1].object.name, "Apple juice");
    expect(apples[2].object.id, 3);
    expect(apples[2].object.name, "Apple seed");

    // Search nearest ending with "banana" (ignore case)
    final queryBanana =
        box
            .query(
              HnswObject_.floatVector
                  .nearestNeighborsF32([2.7, 2.5], 9)
                  .and(
                    HnswObject_.name.endsWith("Banana", caseSensitive: false),
                  ),
            )
            .build();
    addTearDown(() => queryBanana.close());
    final bananas = queryBanana.findWithScores();
    expect(bananas.length, 3);
    expect(bananas[0].object.id, 4);
    expect(bananas[0].object.name, "Banana");
    expect(bananas[1].object.id, 2);
    expect(bananas[1].object.name, "Bunch of banana");
    expect(bananas[2].object.id, 9);
    expect(bananas[2].object.name, "One banana");

    // Search nearest equals to "Peach"
    final queryPeach =
        box
            .query(
              HnswObject_.floatVector
                  .nearestNeighborsF32([2.7, 2.5], 9)
                  .and(HnswObject_.name.equals("Peach")),
            )
            .build();
    addTearDown(() => queryPeach.close());
    final peaches = queryPeach.findWithScores();
    expect(peaches.length, 1);
    expect(peaches[0].object.id, 7);
    expect(peaches[0].object.name, "Peach");

    // Get nearest items that either ends with "juice" or "banana"
    final queryEnds =
        box
            .query(
              HnswObject_.floatVector
                  .nearestNeighborsF32([2.7, 2.5], 9)
                  .and(
                    HnswObject_.name
                        .endsWith("juice")
                        .or(
                          HnswObject_.name.endsWith(
                            "banana",
                            caseSensitive: false,
                          ),
                        ),
                  ),
            )
            .build();
    addTearDown(() => queryEnds.close());
    final ends = queryEnds.findWithScores();
    expect(ends.length, 4);
    expect(ends[0].object.name, "Apple juice");
    expect(ends[1].object.name, "Banana");
    expect(ends[2].object.name, "Bunch of banana");
    expect(ends[3].object.name, "One banana");

    // Get "Apple" group elements and among those, take the one that ends with "juice"
    final builder = box.query(
      HnswObject_.floatVector
          .nearestNeighborsF32([2.7, 2.5], 9)
          .and(HnswObject_.name.endsWith("juice")),
    );
    builder.link(HnswObject_.rel, RelatedNamedEntity_.name.equals("Apple"));
    final queryRel = builder.build();
    addTearDown(() => queryRel.close());
    final juice = queryRel.findWithScores();
    expect(juice.length, 1);
    expect(juice[0].object.id, 6);
    expect(juice[0].object.name, "Apple juice");
  });

  test('VectorDistances distance', () {
    expect(VectorDistances.isAvailable(), isTrue);

    // Euclidean distance is squared: (3-0)^2 + (4-0)^2 = 25
    expect(
      VectorDistances.distance(
        VectorDistanceType.euclidean,
        [0.0, 0.0],
        [3.0, 4.0],
      ),
      25.0,
    );

    // Cosine: orthogonal vectors have distance 1.0.
    expect(
      VectorDistances.distance(
        VectorDistanceType.cosine,
        [1.0, 0.0],
        [0.0, 1.0],
      ),
      1.0,
    );
    // Same direction: distance 0.0.
    expect(
      VectorDistances.distance(
        VectorDistanceType.cosine,
        [1.0, 0.0],
        [2.0, 0.0],
      ),
      0.0,
    );

    // Dot product (normalized vectors): same direction is nearest (0.0).
    expect(
      VectorDistances.distance(
        VectorDistanceType.dotProduct,
        [1.0, 0.0],
        [1.0, 0.0],
      ),
      0.0,
    );

    // Different number of elements throws.
    expect(
      () => VectorDistances.distance(
        VectorDistanceType.euclidean,
        [1.0],
        [1.0, 2.0],
      ),
      throwsA(
        isArgumentError.having(
          (e) => e.message,
          'message',
          contains('same number of elements'),
        ),
      ),
    );
  });

  test('VectorDistances distanceToRelevance', () {
    // Nearest distance is most relevant.
    expect(
      VectorDistances.distanceToRelevance(VectorDistanceType.euclidean, 0.0),
      1.0,
    );
    // Relevance is always within 0.0 to 1.0.
    for (final type in VectorDistanceType.values) {
      // Not supported for geo (returns NaN, see below).
      if (type == VectorDistanceType.geo) continue;
      for (final distance in [0.0, 0.5, 1.0, 2.0, 100.0]) {
        final relevance = VectorDistances.distanceToRelevance(type, distance);
        expect(relevance, greaterThanOrEqualTo(0.0), reason: '$type $distance');
        expect(relevance, lessThanOrEqualTo(1.0), reason: '$type $distance');
      }
    }
    // Unsupported conversion returns NaN.
    expect(
      VectorDistances.distanceToRelevance(VectorDistanceType.geo, 0.0),
      isNaN,
    );
  });

  group('index options', () {
    late Box<HnswTunedObject> tunedBox;

    /// A vector with all elements set to [value]; the (squared Euclidean)
    /// distance of two such vectors is 32 * (a - b)^2.
    List<double> vectorOf(double value) =>
        List.filled(hnswTunedDimensions, value);

    setUp(() {
      tunedBox = env.store.box<HnswTunedObject>();
      tunedBox.putMany(
        List.generate(50, (index) {
          final i = index + 1; // start at 1
          return HnswTunedObject()
            ..group = i % 2
            ..vector = vectorOf(i.toDouble())
            ..vectorDefault = vectorOf(i.toDouble());
        }),
      );
    });

    // Expects the given results are objects 5, 6 and 4 with exact distances.
    void expectNearestTo5_25(List<ObjectWithScore<HnswTunedObject>> results) {
      expect(results.map((r) => r.object.id).toList(), [5, 6, 4]);
      expect(results.map((r) => r.score).toList(), [2.0, 18.0, 50.0]);
    }

    test('store with all options set supports search', () {
      // The index of `vector` sets a search level that rescores, so the
      // results have the exact distances.
      final query =
          tunedBox
              .query(
                HnswTunedObject_.vector.nearestNeighborsF32(vectorOf(5.25), 3),
              )
              .build();
      addTearDown(query.close);
      expectNearestTo5_25(query.findWithScores());
    });

    test('default quantization supports search', () {
      // TurboQuant4 at the default search level rescores, so the results
      // have the exact distances.
      final query =
          tunedBox
              .query(
                HnswTunedObject_.vectorDefault.nearestNeighborsF32(
                  vectorOf(5.25),
                  3,
                ),
              )
              .build();
      addTearDown(query.close);
      expectNearestTo5_25(query.findWithScores());
    });

    test('filtered search returns nearest matching objects', () {
      // Only even objects match, 25 candidates are below the brute force
      // limit of the index (100).
      final query =
          tunedBox
              .query(
                HnswTunedObject_.vector.nearestNeighborsF32(vectorOf(5.25), 2) &
                    HnswTunedObject_.group.equals(0),
              )
              .build();
      addTearDown(query.close);
      final results = query.findWithScores();
      expect(results.map((r) => r.object.id).toList(), [6, 4]);
      expect(results.map((r) => r.score).toList(), [18.0, 50.0]);
    });

    // TurboQuant4 (the default for vectorDefault) does not rescore at search
    // levels 1-3, so the result distances are estimates.
    const exactScores = [2.0, 18.0, 50.0];
    List<double> scoresOf(Query<HnswTunedObject> query) =>
        query.findWithScores().map((r) => r.score).toList();
    Query<HnswTunedObject> buildQuery(QueryBuilder<HnswTunedObject> builder) {
      final query = builder.build();
      addTearDown(query.close);
      return query;
    }

    test('search level and factors of condition', () {
      final v = vectorOf(5.25);
      final atLevel1 = buildQuery(
        tunedBox.query(
          HnswTunedObject_.vectorDefault.nearestNeighborsF32(
            v,
            3,
            searchLevel: VectorSearchLevel.l1Fastest,
          ),
        ),
      );
      expect(scoresOf(atLevel1), isNot(exactScores));

      final atLevel4 = buildQuery(
        tunedBox.query(
          HnswTunedObject_.vectorDefault.nearestNeighborsF32(
            v,
            3,
            searchLevel: VectorSearchLevel.l4Balanced,
          ),
        ),
      );
      expect(scoresOf(atLevel4), exactScores);

      // A rescore factor also turns on rescoring at level 1
      final rescored = buildQuery(
        tunedBox.query(
          HnswTunedObject_.vectorDefault.nearestNeighborsF32(
            v,
            3,
            searchLevel: VectorSearchLevel.l1Fastest,
            oversampleFactor: 2.0,
            rescoreFactor: 1.0,
          ),
        ),
      );
      expect(scoresOf(rescored), exactScores);
    });

    test('filtered search limits of condition', () {
      final v = vectorOf(5.25);
      // Brute force (default: up to 10,000 candidates) has exact distances
      final bruteForce = buildQuery(
        tunedBox.query(
          HnswTunedObject_.vectorDefault.nearestNeighborsF32(
                v,
                2,
                searchLevel: VectorSearchLevel.l1Fastest,
              ) &
              HnswTunedObject_.group.equals(0),
        ),
      );
      expect(scoresOf(bruteForce), [18.0, 50.0]);

      // With a lower limit than the 25 candidates, a graph search is used
      final graphSearch = buildQuery(
        tunedBox.query(
          HnswTunedObject_.group.equals(0) &
              HnswTunedObject_.vectorDefault.nearestNeighborsF32(
                v,
                2,
                searchLevel: VectorSearchLevel.l1Fastest,
                bruteForceMaxCandidates: 1,
                filteredSearchMaxNodes: 1000,
              ),
        ),
      );
      final results = graphSearch.findWithScores();
      expect(results.map((r) => r.object.id), [6, 4]);
      expect(results.map((r) => r.score), isNot([18.0, 50.0]));
    });

    test('search parameters of built query', () {
      for (final alias in [null, 'nn']) {
        final query = buildQuery(
          tunedBox.query(
            HnswTunedObject_.vectorDefault.nearestNeighborsF32(
              vectorOf(5.25),
              3,
              alias: alias,
            ),
          ),
        );
        param() => query.param(HnswTunedObject_.vectorDefault, alias: alias);
        expect(scoresOf(query), exactScores);

        param().searchLevel = VectorSearchLevel.l1Fastest;
        expect(scoresOf(query), isNot(exactScores));

        param().rescore = true;
        expect(scoresOf(query), exactScores);

        param().searchLevel = VectorSearchLevel.l4Balanced;
        expect(scoresOf(query), exactScores);
        param().rescore = false;
        expect(scoresOf(query), isNot(exactScores));

        // Like the condition modifier, a rescore factor turns on rescoring
        param()
          ..searchLevel = VectorSearchLevel.l1Fastest
          ..oversampleFactor = 2.0
          ..quantizationOversample = 1.5
          ..rescoreFactor = 1.0;
        expect(scoresOf(query), exactScores);
        // The last one set wins
        param().rescore = false;
        expect(scoresOf(query), isNot(exactScores));

        // 0 resets factors to the ones of the index, the rescore factor keeps
        // the rescore setting
        param()
          ..quantizationOversample = 0
          ..rescoreFactor = 0;
        expect(scoresOf(query), isNot(exactScores));
      }
    });

    test('filtered search parameters of built query', () {
      for (final alias in [null, 'nn']) {
        final query = buildQuery(
          tunedBox.query(
            HnswTunedObject_.vectorDefault.nearestNeighborsF32(
                  vectorOf(5.25),
                  2,
                  alias: alias,
                  searchLevel: VectorSearchLevel.l1Fastest,
                ) &
                HnswTunedObject_.group.equals(0),
          ),
        );
        param() => query.param(HnswTunedObject_.vectorDefault, alias: alias);
        expect(scoresOf(query), [18.0, 50.0]);

        param()
          ..bruteForceMaxCandidates = 1
          ..filteredSearchMaxNodes = 1000;
        expect(scoresOf(query), isNot([18.0, 50.0]));

        // 0 uses the values of the index again
        param()
          ..bruteForceMaxCandidates = 0
          ..filteredSearchMaxNodes = 0;
        expect(scoresOf(query), [18.0, 50.0]);
      }
    });

    test('illegal search parameters throw', () {
      final v = vectorOf(5.25);
      // Checked by the C API
      expect(
        () =>
            tunedBox
                .query(
                  HnswTunedObject_.vectorDefault.nearestNeighborsF32(
                    v,
                    3,
                    oversampleFactor: 0.5,
                  ),
                )
                .build(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('oversample factor'),
          ),
        ),
      );
      // Would be truncated
      expect(
        () => HnswTunedObject_.vectorDefault.nearestNeighborsF32(
          v,
          3,
          bruteForceMaxCandidates: -1,
        ),
        throwsRangeError,
      );
      expect(
        () => HnswTunedObject_.vectorDefault.nearestNeighborsF32(
          v,
          3,
          filteredSearchMaxNodes: 0x100000000,
        ),
        throwsRangeError,
      );

      final query = buildQuery(
        tunedBox.query(
          HnswTunedObject_.vectorDefault.nearestNeighborsF32(v, 3),
        ),
      );
      final param = query.param(HnswTunedObject_.vectorDefault);
      expect(() => param.rescoreFactor = 0.5, throwsArgumentError);
      expect(() => param.quantizationOversample = 0.5, throwsArgumentError);
      expect(() => param.oversampleFactor = 0.0, throwsArgumentError);
      expect(() => param.bruteForceMaxCandidates = -1, throwsRangeError);
      expect(
        () => param.filteredSearchMaxNodes = 0x100000000,
        throwsRangeError,
      );
      // Not a nearest neighbor condition of this query
      expect(
        () =>
            query.param(HnswTunedObject_.vector).searchLevel =
                VectorSearchLevel.l1Fastest,
        throwsArgumentError,
      );
    });
  });

  test('random seed builds reproducible graphs', () {
    // A new store with the same seed and objects builds the same graph:
    // approximate results (here: random vectors and the fastest search level)
    // are the same.
    List<(int, double)> putRandomVectorsAndSearch() {
      final seedEnv = TestEnv('hnsw-seed');
      try {
        final random = Random(1);
        List<double> randomVector() =>
            List.generate(hnswTunedDimensions, (_) => random.nextDouble());
        final seedBox = seedEnv.store.box<HnswTunedObject>();
        seedBox.putMany(
          List.generate(
            1000,
            (_) => HnswTunedObject()..vector = randomVector(),
          ),
        );
        final query =
            seedBox
                .query(
                  HnswTunedObject_.vector.nearestNeighborsF32(
                    randomVector(),
                    10,
                    searchLevel: VectorSearchLevel.l1Fastest,
                  ),
                )
                .build();
        try {
          final results = query.findWithScores();
          expect(results, hasLength(10));
          return results.map((r) => (r.object.id, r.score)).toList();
        } finally {
          query.close();
        }
      } finally {
        seedEnv.closeAndDelete();
      }
    }

    expect(putRandomVectorsAndSearch(), putRandomVectorsAndSearch());
  });

  group('late init', () {
    // Replaces env.store when reopened
    late Store store;

    setUp(() => store = env.store);
    tearDown(() => store.close());

    Box<HnswLateInitObject> lateBox() => store.box<HnswLateInitObject>();

    /// Like a new session: closes and opens the store again.
    void reopenStore() {
      store.close();
      store = Store(getObjectBoxModel(), directory: env.dbDirPath);
    }

    HnswInitResult init(
      HnswIndexParams params, [
      HnswInitMode mode = HnswInitMode.keepObjects,
    ]) => store.initHnswIndex(HnswLateInitObject_.vector, params, mode: mode);

    HnswIndexParams paramsInEffect() =>
        store.hnswIndexParams(HnswLateInitObject_.vector);

    void putObjects(int count, {int dimensions = hnswTunedDimensions}) =>
        lateBox().putMany(
          List.generate(count, (index) {
            final i = index + 1;
            return HnswLateInitObject()
              ..name = '$i'
              ..vector = List.filled(dimensions, i.toDouble());
          }),
        );

    List<String?> findNearest3Names() {
      final query =
          lateBox()
              .query(
                HnswLateInitObject_.vector.nearestNeighborsF32(
                  List.filled(hnswTunedDimensions, 42.2),
                  3,
                ),
              )
              .build();
      try {
        return query.findWithScores().map((r) => r.object.name).toList();
      } finally {
        query.close();
      }
    }

    test('without init has no dimensions, put and search throw', () {
      final params = paramsInEffect();
      expect(params.dimensions, 0);
      expect(params.flags?.lateInit, isTrue);
      expect(() => putObjects(1), throwsStateError);
      // Building a nearest neighbor query throws
      expect(() => findNearest3Names(), throwsStateError);
      // Reading and other queries work
      expect(lateBox().count(), 0);
      final query =
          lateBox().query(HnswLateInitObject_.name.equals('1')).build();
      expect(query.count(), 0);
      query.close();
    });

    test('first init sets and persists parameters', () {
      final result = init(HnswIndexParams(dimensions: hnswTunedDimensions));
      expect(result.paramsChanged, isTrue);
      expect(result.objectsIndexed, isFalse); // No objects yet
      expect(result.objectsRemoved, isFalse);
      expect(result.objectCount, 0);

      final params = paramsInEffect();
      expect(params.dimensions, hnswTunedDimensions);
      expect(params.flags?.lateInit, isTrue);
      // The default for 32 dimensions
      expect(params.quantization, VectorQuantization.turboQuant4);
      expect(params.randomSeed, isNull); // A random seed

      putObjects(100);
      expect(findNearest3Names(), ['42', '43', '41']);

      // The parameters in effect: nothing to do, also after the index was used
      expect(
        init(HnswIndexParams(dimensions: hnswTunedDimensions)).unchanged,
        isTrue,
      );

      if (env.isInMemory) return; // Can not reopen
      // A later session uses the persisted parameters without init
      reopenStore();
      expect(paramsInEffect().dimensions, hnswTunedDimensions);
      expect(findNearest3Names(), ['42', '43', '41']);
    });

    test(
      'init with other parameters indexes or removes objects',
      () {
        init(HnswIndexParams(dimensions: hnswTunedDimensions));
        putObjects(100);

        // Re-indexes for another indexing search count
        reopenStore();
        final params = HnswIndexParams(
          dimensions: hnswTunedDimensions,
          indexingSearchCount: 64,
        );
        var result = init(params);
        expect(result.paramsChanged, isTrue);
        expect(result.objectsIndexed, isTrue);
        expect(result.objectCount, 100);
        expect(paramsInEffect().indexingSearchCount, 64);
        expect(findNearest3Names(), ['42', '43', '41']);

        // Another search level does not require re-indexing: keeps the objects
        reopenStore();
        result = init(
          HnswIndexParams(
            dimensions: hnswTunedDimensions,
            indexingSearchCount: 64,
            searchLevel: VectorSearchLevel.l6Quality,
          ),
          HnswInitMode.removeAllObjectsOnReindex,
        );
        expect(result.paramsChanged, isTrue);
        expect(result.objectsIndexed, isFalse);
        expect(result.objectsRemoved, isFalse);
        expect(lateBox().count(), 100);
        expect(paramsInEffect().searchLevel, VectorSearchLevel.l6Quality);

        // Other dimensions require re-indexing: removes the objects
        reopenStore();
        result = init(
          HnswIndexParams(dimensions: 16),
          HnswInitMode.removeAllObjectsOnReindex,
        );
        expect(result.paramsChanged, isTrue);
        expect(result.objectsRemoved, isTrue);
        expect(result.objectCount, 100);
        expect(lateBox().count(), 0);

        // Always removes, also with the parameters in effect and after the
        // index was used
        putObjects(10, dimensions: 16);
        result = init(
          HnswIndexParams(dimensions: 16),
          HnswInitMode.removeAllObjectsAlways,
        );
        expect(result.paramsChanged, isFalse);
        expect(result.objectsRemoved, isTrue);
        expect(result.objectCount, 10);
        expect(lateBox().count(), 0);
      },
      skip:
          Platform.environment['OBX_IN_MEMORY'] == 'true'
              ? 'Can not reopen an in-memory database'
              : null,
    );

    test(
      'init keeps objects with vectors not fitting the dimensions',
      () {
        List<String?> findNearestNames(int dimensions) {
          final query =
              lateBox()
                  .query(
                    HnswLateInitObject_.vector.nearestNeighborsF32(
                      List.filled(dimensions, 5.0),
                      100,
                    ),
                  )
                  .build();
          try {
            return query.find().map((o) => o.name).toList();
          } finally {
            query.close();
          }
        }

        // Vectors with more dimensions than the index fit (the index uses the
        // first ones), vectors with fewer dimensions do not
        init(HnswIndexParams(dimensions: 16));
        lateBox().putMany([
          for (var i = 1; i <= 10; i++)
            HnswLateInitObject()
              ..name = 'short $i'
              ..vector = List.filled(16, i.toDouble()),
          for (var i = 1; i <= 10; i++)
            HnswLateInitObject()
              ..name = 'long $i'
              ..vector = List.filled(hnswTunedDimensions, i.toDouble()),
        ]);
        expect(findNearestNames(16), hasLength(20));

        reopenStore();
        final result = init(HnswIndexParams(dimensions: hnswTunedDimensions));
        expect(result.paramsChanged, isTrue);
        expect(result.objectsIndexed, isTrue);
        // Only the fitting objects are indexed and counted, all are kept
        expect(result.objectCount, 10);
        expect(lateBox().count(), 20);
        final names = findNearestNames(hnswTunedDimensions);
        expect(names, hasLength(10));
        expect(names, everyElement(startsWith('long ')));
      },
      skip:
          Platform.environment['OBX_IN_MEMORY'] == 'true'
              ? 'Can not reopen an in-memory database'
              : null,
    );

    test('init with all parameters returns them in effect', () {
      final result = init(
        HnswIndexParams(
          dimensions: hnswTunedDimensions,
          flags: HnswFlags(vectorCacheSimdPaddingOff: true),
          distanceType: VectorDistanceType.cosine,
          reparationBacklinkProbability: 0.5,
          vectorCacheHintSizeKB: 1048576,
          quantization: VectorQuantization.scalarQuant8,
          quantizationOversample: 2.0,
          quantizationRescoreFactor: 1.5,
          searchLevel: VectorSearchLevel.l7QualityHigh,
          buildLevel: VectorBuildLevel.l3Fast,
          bruteForceMaxCandidates: 500,
          filteredSearchMaxNodes: 5000,
          randomSeed: 0x123456789ABCDEF0, // More than 32 bits
        ),
      );
      expect(result.paramsChanged, isTrue);

      final params = paramsInEffect();
      expect(params.dimensions, hnswTunedDimensions);
      // The late init flag of the model is kept
      expect(params.flags?.lateInit, isTrue);
      expect(params.flags?.vectorCacheSimdPaddingOff, isTrue);
      expect(params.flags?.debugLogs, isFalse);
      expect(params.distanceType, VectorDistanceType.cosine);
      expect(params.reparationBacklinkProbability, 0.5);
      expect(params.vectorCacheHintSizeKB, 1048576);
      expect(params.quantization, VectorQuantization.scalarQuant8);
      expect(params.quantizationOversample, 2.0);
      expect(params.quantizationRescoreFactor, 1.5);
      expect(params.searchLevel, VectorSearchLevel.l7QualityHigh);
      // The build level resolved to its parameters
      expect(params.buildLevel, isNull);
      expect(params.neighborsPerNode, 20);
      expect(params.indexingSearchCount, 128);
      expect(params.bruteForceMaxCandidates, 500);
      expect(params.filteredSearchMaxNodes, 5000);
      expect(params.randomSeed, 0x123456789ABCDEF0);
      expect(params.toString(), contains('dimensions: $hnswTunedDimensions'));

      putObjects(100);
      expect(findNearest3Names(), hasLength(3));
    });

    test('init with other parameters after index was used throws', () {
      init(HnswIndexParams(dimensions: hnswTunedDimensions));
      putObjects(1);
      expect(() => init(HnswIndexParams(dimensions: 16)), throwsStateError);
    });

    test('init with invalid arguments throws', () {
      expect(
        () => init(HnswIndexParams(dimensions: 0)),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'dimensions'),
        ),
      );
      expect(
        () => init(
          HnswIndexParams(
            dimensions: hnswTunedDimensions,
            quantizationOversample: 0.5,
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.name,
            'name',
            'quantizationOversample',
          ),
        ),
      );
      // No late init
      expect(
        () => store.initHnswIndex(
          HnswObject_.floatVector,
          HnswIndexParams(dimensions: 2),
        ),
        throwsArgumentError,
      );
      // The index was not initialized
      expect(paramsInEffect().dimensions, 0);
    });

    test('index parameters of model', () {
      final tuned = store.hnswIndexParams(HnswTunedObject_.vector);
      expect(tuned.dimensions, hnswTunedDimensions);
      expect(tuned.quantization, VectorQuantization.scalarQuant8);
      expect(tuned.quantizationOversample, 2.0);
      expect(tuned.quantizationRescoreFactor, 1.5);
      expect(tuned.searchLevel, VectorSearchLevel.l6Quality);
      // The build level resolved to its parameters
      expect(tuned.buildLevel, isNull);
      expect(tuned.neighborsPerNode, 20);
      expect(tuned.indexingSearchCount, 64);
      expect(tuned.bruteForceMaxCandidates, 100);
      expect(tuned.filteredSearchMaxNodes, 1000);
      expect(tuned.randomSeed, 42);
      expect(tuned.flags?.lateInit ?? false, isFalse);

      final geo = store.hnswIndexParams(HnswObject_.floatVectorGeoCoordinates);
      expect(geo.dimensions, 2);
      expect(geo.distanceType, VectorDistanceType.geo);
    });
  });
}
