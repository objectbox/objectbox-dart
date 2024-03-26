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
}
