import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:objectbox/src/bindings/bindings.dart';
import 'package:objectbox/internal.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'entity2.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

// We want to have types explicit - verifying the return types of functions.
// ignore_for_file: omit_local_variable_types

void main() {
  /*late final*/ TestEnv env;
  /*late final*/
  Store store;
  TestEnv /*?*/ env2;
  int serverPort = 9999;

  setUp(() {
    env = TestEnv('sync');
    store = env.store;
    env2 = TestEnv('sync2');
  });

  tearDown(() {
    env?.close();
    env2?.close();
  });

  // lambda to easily create clients in the test below
  SyncClient createClient(Store s) =>
      Sync.client(s, 'ws://127.0.0.1:$serverPort', SyncCredentials.none());

  // lambda to easily create clients in the test below
  SyncClient loggedInClient(Store s) {
    final client = createClient(s);
    client.start();
    expect(waitUntil(() => client.state() == SyncState.loggedIn), isTrue);
    return client;
  }

  test('Model Entity has sync enabled', () {
    final model = getObjectBoxModel().model;
    final entity = model.entities.firstWhere((e) => e.name == 'TestEntity');
    expect(entity.hasFlag(OBXEntityFlags.SYNC_ENABLED), isTrue);
  });

  test('SyncCredentials string encoding', () {
    // Let's check some special characters and verify the data is how it would
    // look like if the same shared secret was provided to the sync-server via
    // an utf-8 encoded json file (i.e. the usual way).
    final str = 'uũú';
    expect(
        InternaSyncTestAccess.credentialsData(
            SyncCredentials.sharedSecretString(str)),
        equals(Uint8List.fromList([117, 197, 169, 195, 186])));
  });

  if (Sync.isAvailable()) {
    // TESTS to run when SYNC is available

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
    });

    test('SyncClient instance caching', () {
      {
        // Just losing the variable scope doesn't close the client automatically.
        // Store holds onto the same instance.
        final client = createClient(store);
        expect(client.isClosed(), isFalse);
      }

      // But we can still get a handle of the client in the store - we're never
      // completely without an option to close it.
      SyncClient /*?*/ client = store.syncClient();
      expect(client, isNotNull);
      expect(client /*!*/ .isClosed(), isFalse);
      client.close();
      expect(store.syncClient(), isNull);
    });

    test('SyncClient is closed when a store is closed', () {
      final client = createClient(env2.store);
      env2.close();
      expect(client.isClosed(), isTrue);
    });

    test('different Store => different SyncClient', () {
      SyncClient c1 = createClient(store);

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
      expect(() => c.requestUpdates(subscribeForFuturePushes: true), error);
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
      // false because not connected
      expect(c.requestUpdates(subscribeForFuturePushes: true), isFalse);
      expect(c.requestUpdates(subscribeForFuturePushes: false), isFalse);
      expect(c.outgoingMessageCount(), isZero);
      c.stop();
      expect(c.state(), equals(SyncState.stopped));
    });

    group('Sync tests with server', () {
      SyncServer server;
      setUp(() async {
        server = SyncServer();
        await server.start();
        serverPort = server.port;
      });

      tearDown(() async {
        await server.stop();
      });

      test('SyncClient data sync', () async {
        await server.online();
        loggedInClient(env.store);
        loggedInClient(env2.store);

        int id = env.box.put(TestEntity(tLong: Random().nextInt(1 << 32)));
        expect(waitUntil(() => env2.box.get(id) != null), isTrue);

        TestEntity /*?*/ read1 = env.box.get(id);
        TestEntity /*?*/ read2 = env2.box.get(id);
        expect(read1, isNotNull);
        expect(read2, isNotNull);
        expect(read1 /*!*/ .id, equals(read2 /*!*/ .id));
        expect(read1 /*!*/ .tLong, equals(read2 /*!*/ .tLong));
      });

      test('SyncClient listeners: connection', () async {
        final client = createClient(env.store);

        // collect connection events
        final events = <SyncConnectionEvent>[];
        final streamSub = client.connectionEvents.listen(events.add);

        // multiple subscriptions work as well
        final events2 = <SyncConnectionEvent>[];
        final streamSub2 = client.connectionEvents.listen(events2.add);

        await server.online();
        client.start();

        expect(waitUntil(() => client.state() == SyncState.loggedIn), isTrue);
        await yieldExecution();
        expect(events, equals([SyncConnectionEvent.connected]));
        expect(events2, equals([SyncConnectionEvent.connected]));

        await streamSub2.cancel();

        await server.stop(keepDb: true);

        expect(
            waitUntil(() => client.state() == SyncState.disconnected), isTrue);
        await yieldExecution();
        expect(
            events,
            equals([
              SyncConnectionEvent.connected,
              SyncConnectionEvent.disconnected
            ]));

        await server.start(keepDb: true);
        await server.online();

        expect(waitUntil(() => client.state() == SyncState.loggedIn), isTrue);
        await yieldExecution();

        expect(
            events,
            equals([
              SyncConnectionEvent.connected,
              SyncConnectionEvent.disconnected,
              SyncConnectionEvent.connected
            ]));
        expect(events2, equals([SyncConnectionEvent.connected]));

        await streamSub.cancel();
        client.close();
      });

      test('SyncClient listeners: login', () async {
        final client = createClient(env.store);

        client.setCredentials(SyncCredentials.sharedSecretString('foo'));

        // collect login events
        final events = <SyncLoginEvent>[];
        client.loginEvents.listen(events.add);

        await server.online();
        client.start();

        expect(await client.loginEvents.first.timeout(defaultTimeout),
            equals(SyncLoginEvent.credentialsRejected));

        client.setCredentials(SyncCredentials.none());

        expect(waitUntil(() => client.state() == SyncState.loggedIn), isTrue);
        await yieldExecution();
        expect(
            events,
            equals(
                [SyncLoginEvent.credentialsRejected, SyncLoginEvent.loggedIn]));

        client.close();
      });

      test('SyncClient listeners: completion', () async {
        await server.online();
        final client = loggedInClient(store);
        expect(env.box.isEmpty(), isTrue);
        int id = env.box.put(TestEntity(tLong: 100));

        // Note: wait for the client to finish sending to the server.
        // There's currently no other way to recognize this.
        sleep(Duration(milliseconds: 100));
        client.close();

        final client2 = loggedInClient(env2.store);
        await client2.completionEvents.first.timeout(defaultTimeout);
        client2.close();

        expect(env2.box.get(id) /*!*/ .tLong, 100);
      });

      test('SyncClient listeners: changes', () async {
        await server.online();
        final client = loggedInClient(store);
        final client2 = loggedInClient(env2.store);

        final events = <List<SyncChange>>[];
        client2.changeEvents.listen(events.add);

        expect(env2.box.get(1), isNull);

        env.box.put(TestEntity(tString: 'foo'));
        env.store.runInTransaction(TxMode.write, () {
          Box<TestEntity2>(env.store).put(TestEntity2()); // not synced
          env.box.put(TestEntity(tString: 'bar'));
          env.box.put(TestEntity(tString: 'oof'));
          env.box.remove(1);
        });

        // wait for the data to be transferred
        expect(waitUntil(() => env2.box.count() == 2), isTrue);

        // check the events
        await yieldExecution();
        expect(events.length, 2);

        // env.box.put(TestEntity(tString: 'foo'));
        expect(events[0].length, 1);
        expect(events[0][0].entity, TestEntity);
        expect(events[0][0].entityId, 1);
        expect(events[0][0].puts, [1]);
        expect(events[0][0].removals, isEmpty);

        // env.store.runInTransaction(TxMode.Write, () {
        //   Box<TestEntity2>(env.store).put(TestEntity2()); // not synced
        //   env.box.put(TestEntity(tString: 'bar'));
        //   env.box.put(TestEntity(tString: 'oof'));
        //   env.box.remove(1);
        // });
        expect(events[1].length, 1);
        expect(events[1][0].entity, TestEntity);
        expect(events[1][0].entityId, 1);
        expect(events[1][0].puts, [2, 3]);
        expect(events[1][0].removals, [1]);

        client.close();
        client2.close();
      });
    },
        skip: SyncServer.isAvailable()
            ? null
            : 'sync-server executable is not available in PATH - tests requiring it are skipped');
  } else {
    // TESTS to run when SYNC is NOT available

    test('SyncClient cannot be created when running with non-sync library', () {
      expect(
          () => createClient(store),
          throwsA(predicate((Exception e) => e.toString().contains(
              'Sync is not available in the loaded ObjectBox runtime library'))));
    });
  }
}

/// sync-server process wrapper for testing clients
class SyncServer {
  Directory /*?*/ dir;
  int /*?*/ port;
  Future<Process> /*?*/ process;

  static bool isAvailable() {
    try {
      Process.runSync('sync-server', ['--help']);
      return true;
    } on ProcessException {
      //print(e);
      return false;
    }
  }

  void start({bool keepDb = false}) async {
    port ??= await _getUnusedPort();

    dir ??= Directory('testdata-sync-server-$port');
    if (!keepDb) _deleteDb();

    process = Process.start('sync-server', [
      '--unsecured-no-authentication',
      '--db-directory=${dir.path}',
      '--model=${Directory.current.path}/test/objectbox-model.json',
      '--bind=ws://127.0.0.1:$port',
      '--browser-bind=http://127.0.0.1:${await _getUnusedPort()}'
    ]);
  }

  /// Wait for the server to respond to a simple http request.
  /// This simple check speeds up test by only trying to log in after the server
  /// has started, avoiding the reconnect backoff intervals altogether.
  Future<void> online() async => Future(() async {
        while (true) {
          try {
            await HttpClient().get('127.0.0.1', port, '');
            break;
          } on SocketException catch (e) {
            // only retry if "connection refused"
            if (e.osError.errorCode != 111) rethrow;
            await Future<void>.delayed(Duration(milliseconds: 1));
          }
        }
      }).timeout(defaultTimeout);

  void stop({bool keepDb = false}) async {
    if (process == null) return;
    final proc = await process /*!*/;
    process = null;
    proc.kill(ProcessSignal.sigint);
    final exitCode = await proc.exitCode;
    if (exitCode != 0) {
      await stdout.addStream(proc.stdout);
      await stderr.addStream(proc.stderr);
      expect(await proc.exitCode, isZero);
    }
    if (!keepDb) _deleteDb();
  }

  Future<int> _getUnusedPort() =>
      ServerSocket.bind(InternetAddress.loopbackIPv4, 0).then((socket) {
        var port = socket.port;
        socket.close();
        return port;
      });

  void _deleteDb() {
    if (dir != null && dir /*!*/ .existsSync()) {
      dir /*!*/ .deleteSync(recursive: true);
    }
  }
}
