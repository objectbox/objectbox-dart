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
}
