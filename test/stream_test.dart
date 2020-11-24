import 'dart:async';

import 'package:objectbox/observable.dart';
import 'package:test/test.dart';

import 'entity.dart';
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

    // The delay is here to ensure that the callback execution is executed
    // sequentially, otherwise the testing framework's execution  will be
    // prioritized (for some reason), before any callback.
    await Future.delayed(Duration(seconds: 0));

    box.putMany(<TestEntity>[
      TestEntity(tString: 'Goodbye'),
      TestEntity(tString: 'for now')
    ]);
    await Future.delayed(Duration(seconds: 0));

    expect(result, ['Hello world', 'for now, Goodbye, Hello world']);

    await subscription.cancel();
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
    await Future.delayed(Duration(seconds: 0));

    // idem, see above
    box.putMany(<TestEntity>[
      TestEntity(tString: 'Goodbye'),
      TestEntity(tString: 'for now')
    ]);
    await Future.delayed(Duration(seconds: 0));

    expect(result, [1, 3]);

    await subscription.cancel();
  });

  tearDown(() {
    env.close();
  });
}
