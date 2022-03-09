import 'package:collection/collection.dart';
import 'package:test/test.dart';

import 'entity_immutable.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

// We want to have types explicit - verifying the return types of functions.
// ignore_for_file: omit_local_variable_types

void main() {
  test('Test putImmutable*', () async {
    final env = TestEnv('entity_immutable');
    final Box<TestEntityImmutable> box = env.store.box();

    final result = box.putImmutableMany(const <TestEntityImmutable>[
      TestEntityImmutable(unique: 1, payload: 1),
      TestEntityImmutable(unique: 10, payload: 10),
      TestEntityImmutable(unique: 2, payload: 2),
      TestEntityImmutable(unique: 100, payload: 100),
      TestEntityImmutable(unique: 0, payload: 0),
      TestEntityImmutable(unique: 50, payload: 0),
    ]);

    expect(result.length, 6);
    expect(result.map((e) => e.unique).toList(), [1, 10, 2, 100, 0, 50]);

    final query = (box.query()
          ..order(TestEntityImmutable_.payload, flags: Order.descending))
        .build();
    var listDesc = query.find();

    expect(listDesc.map((t) => t.payload).toList(), [100, 10, 2, 1, 0, 0]);

    final obj = box.putImmutable(const TestEntityImmutable(
      unique: 50,
      payload: 50,
    ));
    expect([obj.unique, obj.payload], [50, 50]);

    listDesc = query.find();
    expect(listDesc.map((t) => t.payload).toList(), [100, 50, 10, 2, 1, 0]);
    query.close();

    final objAsync = await box.putImmutableAsync(const TestEntityImmutable(
      unique: 60,
      payload: 60,
    ));

    expect(
      [objAsync.id, objAsync.unique, objAsync.payload],
      [obj.id! + 1, 60, 60],
    );

    env.closeAndDelete();
  });
}
