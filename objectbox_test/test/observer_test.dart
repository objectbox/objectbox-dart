import 'dart:async';
import 'dart:isolate';

import 'package:test/test.dart';

import 'entity.dart';
import 'entity2.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

void main() async {
  late TestEnv env;
  late Box<TestEntity> box;

  simpleStringItems() => <String>['One', 'Two', 'Three', 'Four', 'Five', 'Six']
      .map((s) => TestEntity(tString: s))
      .toList()
      .cast<TestEntity>();

  setUp(() {
    env = TestEnv('observers');
    box = env.box;
  });

  tearDown(() => env.closeAndDelete());

  test('create subscription after store is closed', () async {
    env.store.close();
    // Previously the error surfaced only as an unhandled zone error the
    // subscriber can not catch, and the just-created receive port leaked
    // (keeping the isolate alive).
    Future<void> testListenAfterClose(Stream<void> stream) async {
      final errors = <Object>[];
      final sub = stream.listen((_) {}, onError: errors.add);
      await yieldExecution();
      expect(errors, hasLength(1));
      expect(
          errors.first,
          isA<StateError>().having(
              (e) => e.message, 'message', contains('Store is closed')));
      await sub.cancel();
    }

    await testListenAfterClose(env.store.entityChanges);
    await testListenAfterClose(env.store.watch<TestEntity>());
  });

  test('cancel subscription after store is closed', () async {
    // Native observers are freed together with the native store, so closing
    // the store must stop them: cancelling afterwards previously closed the
    // already freed native observer (use-after-free, confirmed by valgrind).
    final subWatch = env.store.watch<TestEntity>().listen((_) {});
    final subEntityChanges = env.store.entityChanges.listen((_) {});
    box.put(TestEntity(tString: 'event'));
    await yieldExecution();
    env.store.close();
    await subWatch.cancel();
    await subEntityChanges.cancel();
  });

  test('isolate exits with active observers', () async {
    final env = TestEnv('isolate-observers');
    addTearDown(() => env.closeAndDelete());
    final exited = ReceivePort();
    await Isolate.spawn(watchAndExit, env.dbDirPath, onExit: exited.sendPort);
    await exited.first;
    exited.close();

    // The observers of the exited isolate were closed by their finalizers;
    // changes must not fail (e.g. notify a dead isolate) and closing works.
    // Note: the following calls and the close on tear-down won't fail if the
    // observer is leaked, they are done only for safety.
    env.box.put(TestEntity(tString: 'after exit'));
    expect(env.box.count(), 1);
  });

  test('isolate exits after canceling last entityChanges subscription',
      () async {
    final env = TestEnv('isolate-entity-changes');
    addTearDown(() => env.closeAndDelete());
    final exited = ReceivePort();
    final worker = await Isolate.spawn(subscribeAndCancel, env.dbDirPath,
        onExit: exited.sendPort);
    // If the isolate fails to exit on its own (test failure), kill it so it
    // does not keep the test process alive and the store can be closed
    // (tear-downs run in reverse order, so this runs before closeAndDelete).
    addTearDown(() => worker.kill(priority: Isolate.immediate));
    addTearDown(exited.close);

    // The worker neither calls Isolate.exit() nor closes its store (which would
    // close the entityChanges observer): it can only exit normally if no
    // receive ports are left open. So if the (cached) entityChanges stream does
    // not close its receive port once the last subscription is cancelled, the
    // isolate never exits and this times out.
    // Note that this relies on the native store getting closed by the store
    // finalizer.
    await exited.first.timeout(defaultTimeout,
        onTimeout: () => fail(
            'Isolate did not exit, likely the receive port of entityChanges is still open'));
  });

  test('Observe single entity', () async {
    late Completer<void> completer;
    var expectedEvents = 0;

    final stream = env.store.watch<TestEntity>();
    final subscription = stream.listen((_) {
      print('TestEntity updated');
      expectedEvents--;
      if (expectedEvents == 0) {
        completer.complete();
      }
    });

    // expect two events after one put() and one putMany()
    expectedEvents = 2;
    completer = Completer();
    final first = simpleStringItems().first;
    box.put(first);
    Box<TestEntity2>(env.store).put(TestEntity2());
    box.putMany(simpleStringItems());
    await completer.future.timeout(defaultTimeout);
    expect(expectedEvents, 0);

    // expect one event after modifying ToMany
    expectedEvents = 1;
    completer = Completer();
    first.relManyA.add(RelatedEntityA(tInt: 1));
    // applyToDb does currently not trigger an event on the observed box
    // first.relManyA.applyToDb();
    box.put(first);
    await completer.future.timeout(defaultTimeout);
    expect(expectedEvents, 0);

    // cancel the subscription
    await subscription.cancel();

    // make sure there are no more events after cancelling
    expectedEvents = 1;
    completer = Completer();
    box.put(simpleStringItems().first);
    expect(completer.future.timeout(defaultTimeout),
        throwsA(isA<TimeoutException>()));
    expect(expectedEvents, 1); // note: unchanged, no events received anymore
  });

  test('Observe multiple entities', () async {
    late Completer<void> completer;
    var expectedEvents = 0;
    var typesUpdates = <Type, int>{}; // number of events per entity type

    final subscription =
        env.store.entityChanges.listen((List<Type> entityTypes) {
      print('Entities updated: $entityTypes');
      expectedEvents--;

      for (var entityType in entityTypes) {
        typesUpdates[entityType] = 1 + (typesUpdates[entityType] ?? 0);
      }

      if (expectedEvents == 0) {
        completer.complete();
      }
    });

    // expect three events: two puts() (separate entities), one putMany()
    expectedEvents = 3;
    completer = Completer();
    box.put(simpleStringItems().first);
    Box<TestEntity2>(env.store).put(TestEntity2());
    box.putMany(simpleStringItems());
    await completer.future.timeout(defaultTimeout);
    expect(expectedEvents, 0);
    expect(typesUpdates.keys, sameAsList<Type>([TestEntity, TestEntity2]));
    expect(typesUpdates[TestEntity], 2);
    expect(typesUpdates[TestEntity2], 1);

    // cancel the subscription
    await subscription.cancel();

    // make sure there are no more events after cancelling
    expectedEvents = 1;
    completer = Completer();
    box.put(simpleStringItems().first);
    expect(completer.future.timeout(defaultTimeout),
        throwsA(isA<TimeoutException>()));
    expect(expectedEvents, 1); // note: unchanged, no events received anymore
  });

  test(
      'entityChanges broadcast stream: multiple listeners, cancel and re-listen',
      () async {
    // Supports multiple listeners
    final receivedEventsA = <List<Type>>[];
    final subscriptionA = env.store.entityChanges.listen(receivedEventsA.add);
    final receivedEventsB = <List<Type>>[];
    final subscriptionB = env.store.entityChanges.listen(receivedEventsB.add);

    box.put(simpleStringItems().first);
    await yieldExecution();
    expect(receivedEventsA, hasLength(1));
    expect(receivedEventsB, hasLength(1));

    // Cancel all listeners, this closes the native observer and receive port.
    await subscriptionA.cancel();
    await subscriptionB.cancel();

    // Add a new listener, internal observer and port should be re-created and
    // deliver events.
    var completer = Completer<void>();
    final receivedEventsC = <List<Type>>[];
    final subscriptionC = env.store.entityChanges.listen((event) {
      receivedEventsC.add(event);
      completer.complete();
    });
    addTearDown(() => subscriptionC.cancel());

    box.put(simpleStringItems().first);
    await completer.future.timeout(defaultTimeout);
    expect(receivedEventsC, hasLength(1));
    // Previous (cancelled) subscriptions must not have received more events.
    expect(receivedEventsA, hasLength(1));
    expect(receivedEventsB, hasLength(1));
  });

  test('Observer pause/resume', () async {
    testPauseResume(Stream stream) async {
      late Completer<void> completer;
      final subscription = stream.listen((dynamic _) {
        completer.complete();
      });

      // triggers when listening
      completer = Completer();
      box.put(simpleStringItems().first);
      await completer.future.timeout(defaultTimeout);

      // won't trigger when paused
      subscription.pause();
      completer = Completer();
      box.put(simpleStringItems().first);
      expect(completer.future.timeout(defaultTimeout),
          throwsA(isA<TimeoutException>()));

      // triggers when resumed (Note: no buffering of previous events)
      subscription.resume();
      completer = Completer();
      box.put(simpleStringItems().first);
      await completer.future.timeout(defaultTimeout);

      // won't trigger when cancelled
      await subscription.cancel();
      completer = Completer();
      box.put(simpleStringItems().first);
      expect(completer.future.timeout(defaultTimeout),
          throwsA(isA<TimeoutException>()));
    }

    await testPauseResume(env.store.watch<TestEntity>());
    await testPauseResume(env.store.entityChanges);
  });
}

/// Subscribes to changes and exits without canceling the subscriptions.
void watchAndExit(String dbDirPath) {
  final store = Store.attach(getObjectBoxModel(), dbDirPath);
  store.watch<TestEntity>().listen((_) {});
  store.entityChanges.listen((_) {});
  Box<TestEntity>(store).query().watch().listen((_) {});
  Isolate.exit();
}

/// Subscribes to entityChanges, cancels the subscription again and returns
/// without calling Isolate.exit() and without explicitly closing the store.
Future<void> subscribeAndCancel(String dbDirPath) async {
  final store = Store.attach(getObjectBoxModel(), dbDirPath);
  final subscription = store.entityChanges.listen((_) {});
  await subscription.cancel();
}
