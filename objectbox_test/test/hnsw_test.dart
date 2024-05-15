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
    box.putMany(List.generate(10, (index) {
      final i = index + 1; // start at 1
      final value = i.toDouble();
      return HnswObject()
        ..name = "node$i"
        ..floatVector = [value, value];
    }));

    final searchVector = [5.0, 4.5];
    final query = box
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

  test('find offset limit', () {
    box.putMany(List.generate(15, (index) {
      final i = index + 1; // start at 1
      final value = i.toDouble();
      return HnswObject()
        ..name = "node_$i"
        ..floatVector = [value, value];
    }));

    final searchVector = [3.1, 3.1];
    final maxResultCount = 4;
    final query = box
        .query(HnswObject_.floatVector
            .nearestNeighborsF32(searchVector, maxResultCount))
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
      RelatedNamedEntity()..name = "Misc"
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
        ..rel.targetId = miscGroupId
    ]);

    // Search nearest starting with "Apple"
    final queryApple = box
        .query(HnswObject_.floatVector.nearestNeighborsF32(
            [2.7, 2.5], 9).and(HnswObject_.name.startsWith("Apple")))
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
    final queryBanana = box
        .query(HnswObject_.floatVector.nearestNeighborsF32([2.7, 2.5], 9).and(
            HnswObject_.name.endsWith("Banana", caseSensitive: false)))
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
    final queryPeach = box
        .query(HnswObject_.floatVector.nearestNeighborsF32(
            [2.7, 2.5], 9).and(HnswObject_.name.equals("Peach")))
        .build();
    addTearDown(() => queryPeach.close());
    final peaches = queryPeach.findWithScores();
    expect(peaches.length, 1);
    expect(peaches[0].object.id, 7);
    expect(peaches[0].object.name, "Peach");

    // Get nearest items that either ends with "juice" or "banana"
    final queryEnds = box
        .query(HnswObject_.floatVector.nearestNeighborsF32([2.7, 2.5], 9).and(
            HnswObject_.name
                .endsWith("juice")
                .or(HnswObject_.name.endsWith("banana", caseSensitive: false))))
        .build();
    addTearDown(() => queryEnds.close());
    final ends = queryEnds.findWithScores();
    expect(ends.length, 4);
    expect(ends[0].object.name, "Apple juice");
    expect(ends[1].object.name, "Banana");
    expect(ends[2].object.name, "Bunch of banana");
    expect(ends[3].object.name, "One banana");

    // Get "Apple" group elements and among those, take the one that ends with "juice"
    final builder = box.query(HnswObject_.floatVector.nearestNeighborsF32(
        [2.7, 2.5], 9).and(HnswObject_.name.endsWith("juice")));
    builder.link(HnswObject_.rel, RelatedNamedEntity_.name.equals("Apple"));
    final queryRel = builder.build();
    addTearDown(() => queryRel.close());
    final juice = queryRel.findWithScores();
    expect(juice.length, 1);
    expect(juice[0].object.id, 6);
    expect(juice[0].object.name, "Apple juice");
  });
}
