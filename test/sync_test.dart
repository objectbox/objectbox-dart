import 'package:test/test.dart';
import 'package:objectbox/objectbox.dart';
import 'test_env.dart';

// We want to have types explicit - verifying the return types of functions.
// ignore_for_file: omit_local_variable_types

void main() {
  TestEnv env;
  Store store;

  setUp(() {
    env = TestEnv('sync');
    store = env.store;
  });

  tearDown(() {
    env.close();
  });

  // lambda to easily create clients in the test below
  SyncClient createClient(Store s) =>
      Sync.client(s, 'ws://127.0.0.1:9999', SyncCredentials.none());

  test('SyncClient lifecycle', () {
    expect(store.syncClient(), isNull);

    SyncClient c1 = createClient(store);

    // Store now has the client available in cache.
    expect(store.syncClient(), equals(c1));

    // Can't have two clients on the same store.
    expect(
        () => createClient(store),
        throwsA(predicate(
            (Exception e) => e.toString().contains('one sync client'))));

    // But we can have another one after the previous is closed or destroyed.
    expect(c1.isClosed(), isFalse);
    c1.close();
    expect(c1.isClosed(), isTrue);
    expect(store.syncClient(), isNull);

    {
      // Just losing the variable scope doesn't close the client automatically.
      // Store holds onto the same instance.
      final c2 = createClient(store);
      expect(c2.isClosed(), isFalse);
    }

    // But we can still get a handle of the client in the store - we're never
    // completely without an option to close it.
    final c2 = store.syncClient();
    expect(c2, isNotNull);
    expect(c2.isClosed(), isFalse);
    c2.close();
    expect(store.syncClient(), isNull);

    // closing a store closes a client
    final env2 = TestEnv('sync2');
    final c3 = createClient(env2.store);
    env2.close();
    expect(c3.isClosed(), isTrue);
  });

  test('different Store => different SyncClient', () {
    SyncClient c1 = createClient(store);

    final env2 = TestEnv('sync2');
    SyncClient c2 = createClient(env2.store);
    expect(c1, isNot(equals(c2)));
    env2.close();
  });

  test('SyncClient states (no server available)', () {
    SyncClient client = createClient(store);
    expect(client.state(), equals(SyncState.created));
    client.start();
    expect(client.state(), equals(SyncState.started));
    client.stop();
    expect(client.state(), equals(SyncState.stopped));
  });

  test('SyncClient access after closing must throw', () {
    SyncClient c = createClient(store);
    c.close();
    expect(c.isClosed(), isTrue);

    final error = throwsA(predicate(
        (Exception e) => e.toString().contains('SyncClient already closed')));
    expect(() => c.start(), error);
    expect(() => c.stop(), error);
    expect(() => c.state(), error);
    expect(() => c.cancelUpdates(), error);
    expect(() => c.requestUpdates(true), error);
    expect(() => c.outgoingMessageCount(), error);
    expect(() => c.setCredentials(SyncCredentials.none()), error);
    expect(() => c.setRequestUpdatesMode(SyncRequestUpdatesMode.auto), error);
  });

  test('SyncClient simple coverage (no server available)', () {
    SyncClient c = createClient(store);
    expect(c.isClosed(), isFalse);
    c.setCredentials(SyncCredentials.none());
    c.setCredentials(SyncCredentials.googleAuthString('secret'));
    c.setCredentials(SyncCredentials.sharedSecretString('secret'));
    c.setCredentials(
        SyncCredentials.googleAuthUint8List(Uint8List.fromList([13, 0, 25])));
    c.setCredentials(SyncCredentials.sharedSecretUint8List(
        Uint8List.fromList([13, 0, 25])));
    c.setCredentials(SyncCredentials.none());
    c.setRequestUpdatesMode(SyncRequestUpdatesMode.manual);
    c.start();
    expect(c.requestUpdates(true), isFalse); // false because not connected
    expect(c.requestUpdates(false), isFalse); // false because not connected
    expect(c.outgoingMessageCount(), isZero);
    c.stop();
    expect(c.state(), equals(SyncState.stopped));
  });
}
