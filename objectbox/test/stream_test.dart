import 'dart:async';

import 'package:test/test.dart';

import 'entity.dart';
import 'entity2.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

// ignore_for_file: non_constant_identifier_names

void main() {
  late TestEnv env;
  late Box<TestEntity> box;

  setUp(() {
    env = TestEnv('streams');
    box = env.box;
  });

  tearDown(() => env.close());

  test('Subscribe to stream of entities', () async {
    final result = <String>[];
    final text = TestEntity_.tString;
    final condition = text.notNull();
    final queryStream = (box.query(condition)..order(text)).watch();
    final subscription = queryStream.listen((q) {
      final str = q.find().map((t) => t.tString).toList().join(', ');
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
  });

  test('Subscribe to stream of query', () async {
    final result = <int>[];
    final text = TestEntity_.tString;
    final condition = text.notNull();
    final queryStream = (box.query(condition)..order(text)).watch();
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
  });

  test('trigger immediately', () async {
    var completer = Completer<void>();
    final sub1 = box.query().watch(triggerImmediately: true).listen((query) {
      expect(query.count(), 0);
      completer.complete();
    });
    await completer.future.timeout(defaultTimeout);
    await sub1.cancel();

    // If no triggerImmediately passed, then it mustn't trigger without changes.
    completer = Completer<void>();
    final sub2 = box.query().watch().listen((query) => completer.complete());
    expect(
        completer.future.timeout(const Duration(milliseconds: 100)),
        throwsA(predicate((TimeoutException e) =>
            e.toString().contains('Future not completed'))));
    await sub2.cancel();
  });

  test('can use query after subscription is canceled', () async {
    // This subscribes, gets the first element and cancels immediately.
    // We're testing that if user keeps the query instance, they can use it
    // later. This is only possible because of query auto-close with finalizers.
    final query = await box
        .query()
        .watch(triggerImmediately: true)
        .first
        .timeout(defaultTimeout);

    expect(query.count(), 0);
  });

  test(
      'Only observers of a single entity are notified, no cross-entity observer notification',
      () async {
    // setup listeners
    final box2 = Box<TestEntity2>(env.store);

    var counter1 = 0, counter2 = 0;

    final subscription2 = box2.query().watch().listen((_) {
      counter2++;
    });

    final subscription1 = box.query().watch().listen((_) {
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

    await subscription1.cancel();
    await subscription2.cancel();
  });
}
