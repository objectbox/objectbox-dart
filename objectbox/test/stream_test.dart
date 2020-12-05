import 'dart:async';

import 'package:test/test.dart';

import 'entity.dart';
import 'entity2.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

// ignore_for_file: non_constant_identifier_names

void main() {
  /*late final*/ TestEnv env;
  /*late final*/
  Box<TestEntity> box;

  setUp(() {
    env = TestEnv('streams');
    box = env.box;
  });

  // Yield execution to other isolates.
  //
  // We need to do this to receive an event in the stream before processing
  // the remainder of the test case.
  final yieldExecution = () async => await Future.delayed(Duration.zero);

  test('Subscribe to stream of entities', () async {
    final result = <String>[];
    final text = TestEntity_.tString;
    final condition = text.notNull();
    final query = box.query(condition).order(text).build();
    final queryStream = query.findStream();
    final subscription = queryStream.listen((list) {
      final str = list.map((t) => t.tString).toList().join(', ');
      result.add(str);
    });

    box.put(TestEntity(tString: 'Hello world'));

    await yieldExecution();

    box.putMany(<TestEntity>[
      TestEntity(tString: 'Goodbye'),
      TestEntity(tString: 'for now')
    ]);

    await yieldExecution();

    expect(result, ['Hello world', 'for now, Goodbye, Hello world']);

    await subscription.cancel();
    query.close();
  });

  test('Subscribe to stream of query', () async {
    final result = <int>[];
    final text = TestEntity_.tString;
    final condition = text.notNull();
    final query = box.query(condition).order(text).build();
    final queryStream = query.stream;
    final subscription = queryStream.listen((query) {
      result.add(query.count());
    });

    box.put(TestEntity(tString: 'Hello world'));

    await yieldExecution();

    // idem, see above
    box.putMany(<TestEntity>[
      TestEntity(tString: 'Goodbye'),
      TestEntity(tString: 'for now')
    ]);

    await yieldExecution();

    expect(result, [1, 3]);

    await subscription.cancel();
    query.close();
  });

  test(
      'Only observers of a single entity are notified, no cross-entity observer notification',
      () async {
    // setup listeners
    final box2 = Box<TestEntity2>(env.store);

    var counter1 = 0, counter2 = 0;

    final query2 = box2.query().build();
    final queryStream2 = query2.findStream();
    final subscription2 = queryStream2.listen((_) {
      counter2++;
    });

    final query1 = box.query().build();
    final queryStream1 = query1.findStream();
    final subscription1 = queryStream1.listen((_) {
      counter1++;
    });

    // counter2 test #.1
    final t2 = TestEntity2();
    box2.put(t2);

    await yieldExecution();
    expect(counter1, 0);
    expect(counter2, 1);

    // counter1 test #.1
    final t1 = TestEntity();
    box.put(t1);

    await yieldExecution();
    expect(counter1, 1);
    expect(counter2, 1);

    // counter1 many test #.2
    final ts1 = [1, 2, 3].map((i) => TestEntity(tInt: i)).toList();
    box.putMany(ts1);

    await yieldExecution();
    expect(counter1, 2);
    expect(counter2, 1);

    // counter2 many test #.2
    final ts2 = [1, 2, 3].map((i) => TestEntity2()).toList();
    box2.putMany(ts2);

    await yieldExecution();
    expect(counter1, 2);
    expect(counter2, 2);

    query1.close();
    query2.close();

    await subscription1.cancel();
    await subscription2.cancel();
  });

  tearDown(() {
    env.close();
  });
}
