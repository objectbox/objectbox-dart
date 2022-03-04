import 'package:collection/collection.dart';
import 'package:test/test.dart';

import 'entity_immutable.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

// We want to have types explicit - verifying the return types of functions.
// ignore_for_file: omit_local_variable_types

void main() {
  late TestEnv env;
  late Box<TestEntityImmutable> box;

  setUp(() {
    env = TestEnv('entity_immutable');
    box = env.store.box();
  });
  tearDown(() => env.closeAndDelete());

  test('Query with no conditions, and order as desc ints', () {
    box.putMany(<TestEntityImmutable>[
      TestEntityImmutable(unique: 1, payload: 1),
      TestEntityImmutable(unique: 10, payload: 10),
      TestEntityImmutable(unique: 2, payload: 2),
      TestEntityImmutable(unique: 100, payload: 100),
      TestEntityImmutable(unique: 0, payload: 0),
      TestEntityImmutable(unique: 50, payload: 0),
    ]);

    final query = (box.query()
          ..order(TestEntityImmutable_.payload, flags: Order.descending))
        .build();
    var listDesc = query.find();

    expect(listDesc.map((t) => t.payload).toList(), [100, 10, 2, 1, 0, 0]);

    box.put(TestEntityImmutable(unique: 50, payload: 50));

    listDesc = query.find();
    expect(listDesc.map((t) => t.payload).toList(), [100, 50, 10, 2, 1, 0]);
    query.close();
  });
}
