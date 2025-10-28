import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:objectbox/internal.dart';
import 'package:objectbox/src/native/store.dart';
import 'package:objectbox/src/native/sync.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'entity2.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

// We want to have types explicit - verifying the return types of functions.
// ignore_for_file: omit_local_variable_types

/// Tests Dart specific parts of the Sync APIs.
///
/// - client tests that do not require a server
/// - server tests that are currently run manually (in their own test groups)
///   - by making sure sync-server is on PATH or for some
///   - by configuring and running a server, making sure its available on
///   [serverPort]. For these also see the setup notes on specific tests.
void main() {
  late TestEnv env;
  late Store store;
  late TestEnv env2;
  int serverPort = 9999;

  /// Returns a test server URL with the current [serverPort].
  serverUrl() {
    return 'ws://127.0.0.1:$serverPort';
  }

  setUp(() {
    env = TestEnv('sync');
    store = env.store;
    env2 = TestEnv('sync2');
  });

  tearDown(() {
    env.closeAndDelete();
    env2.closeAndDelete();
  });

  waitUntilLoggedIn(SyncClient client) {
    expect(waitUntil(() => client.state() == SyncState.loggedIn), isTrue);
  }

  // lambda to easily create clients in the tests below
  SyncClient createAuthenticatedClient(
          Store s, List<SyncCredentials> credentials) =>
      Sync.clientMultiCredentials(s, serverUrl(), credentials);

  SyncClient createClient(Store s) =>
      createAuthenticatedClient(s, [SyncCredentials.none()]);

  // lambda to easily create clients in the test below
  SyncClient loggedInClient(Store s) {
    final client = createClient(s);
    client.start();
    waitUntilLoggedIn(client);
    return client;
  }

  test('Model Entity has sync enabled', () {
    final model = getObjectBoxModel().model;
    final entity =
        model.entities.firstWhere((e) => e.name == 'TestEntitySynced');
    expect(entity.hasFlag(OBXEntityFlags.SYNC_ENABLED), isTrue);
  });

  test('Sync.clientMulti throws if empty URL list', () {
    // Note: this test works with a library that does not have the Sync
    // feature, because the URLs are checked before checking for the feature.
    expect(
        () => Sync.clientMultiUrls(store, [], SyncCredentials.none()),
        throwsA(isArgumentError.having((e) => e.message, 'message',
            contains('Provide at least one server URL'))));

    expect(
        () => Sync.clientMultiCredentialsMultiUrls(
            store, [], [SyncCredentials.none()]),
        throwsA(isArgumentError.having((e) => e.message, 'message',
            contains('Provide at least one server URL'))));
  });

  test('SyncCredentials string encoding', () {
    // Let's check some special characters and verify the data is how it would
    // look like if the same shared secret was provided to the sync-server via
    // an utf-8 encoded json file (i.e. the usual way).
    final str = 'uũú';
    expect(
        (SyncCredentials.sharedSecretString(str) as SyncCredentialsSecret).data,
        equals(Uint8List.fromList([117, 197, 169, 195, 186])));
  });

  if (Sync.isAvailable()) {
    // TESTS to run when SYNC is available
    print("Testing Sync with protocol version ${SyncClient.protocolVersion()}");

    test('SyncClient lifecycle', () {
      expect(store.syncClient(), isNull);

      SyncClient c1 = createClient(store);

      // Store now has the client available in cache.
      expect(store.syncClient(), equals(c1));

      // Can't have two clients on the same store.
      expect(
          () => createClient(store),
          throwsA(predicate(
              (StateError e) => e.toString().contains('one sync client'))));

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
      SyncClient? client = store.syncClient();
      expect(client, isNotNull);
      expect(client!.isClosed(), isFalse);
      client.close();
      expect(store.syncClient(), isNull);
    });

    test('Sync.clientMulti throws if empty credential list', () {
      expect(
          () => Sync.clientMultiCredentials(store, 'test-url', []),
          throwsA(isArgumentError.having((e) => e.message, 'message',
              contains('Provide at least one credential'))));

      expect(
          () => Sync.clientMultiCredentialsMultiUrls(store, ['test-url'], []),
          throwsA(isArgumentError.having((e) => e.message, 'message',
              contains('Provide at least one credential'))));
    });

    test('SyncClient is closed when a store is closed', () {
      final client = createClient(env2.store);
      env2.closeAndDelete();
      expect(client.isClosed(), isTrue);
    });

    test('different Store => different SyncClient', () {
      SyncClient c1 = createClient(store);

      SyncClient c2 = createClient(env2.store);
      expect(c1, isNot(equals(c2)));
      env2.closeAndDelete();
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

      final error = throwsA(predicate((StateError e) =>
          e.toString().contains('SyncClient already closed')));
      expect(() => c.start(), error);
      expect(() => c.stop(), error);
      expect(() => c.state(), error);
      expect(() => c.cancelUpdates(), error);
      expect(() => c.requestUpdates(subscribeForFuturePushes: true), error);
      expect(() => c.outgoingMessageCount(), error);

      expect(() => c.setCredentials(SyncCredentials.none()), error);
      expect(
          () => c.setCredentials(SyncCredentials.sharedSecretString('secret')),
          error);
      expect(
          () => c
              .setCredentials(SyncCredentials.userAndPassword('obx', 'secret')),
          error);

      expect(
          () => c.setMultipleCredentials([
                SyncCredentials.sharedSecretString('secret'),
                SyncCredentials.userAndPassword('obx', 'secret')
              ]),
          error);

      expect(() => c.setRequestUpdatesMode(SyncRequestUpdatesMode.auto), error);
    });

    test('SyncClient simple coverage (no server available)', () async {
      SyncClient c = createClient(store);
      expect(c.isClosed(), isFalse);

      expect(SyncClient.protocolVersion(), greaterThanOrEqualTo(7));
      expect(c.protocolVersionServer(), 0);

      c.setCredentials(SyncCredentials.none());
      c.setCredentials(SyncCredentials.googleAuthString('secret'));
      c.setCredentials(SyncCredentials.sharedSecretString('secret'));
      c.setCredentials(
          SyncCredentials.googleAuthUint8List(Uint8List.fromList([13, 0, 25])));
      c.setCredentials(SyncCredentials.sharedSecretUint8List(
          Uint8List.fromList([13, 0, 25])));
      c.setCredentials(SyncCredentials.userAndPassword('obx', 'secret'));
      c.setCredentials(SyncCredentials.jwtIdToken('id-token'));
      c.setCredentials(SyncCredentials.jwtAccessToken('access-token'));
      c.setCredentials(SyncCredentials.jwtRefreshToken('refresh-token'));
      c.setCredentials(SyncCredentials.jwtCustomToken('custom-token'));

      c.setCredentials(SyncCredentials.none());
      c.setRequestUpdatesMode(SyncRequestUpdatesMode.manual);
      c.start();
      // false because not connected
      expect(c.requestUpdates(subscribeForFuturePushes: true), isFalse);
      expect(c.requestUpdates(subscribeForFuturePushes: false), isFalse);
      expect(c.outgoingMessageCount(), isZero);
      // Wait until client reaches state disconnected (as there is no server),
      // only then reconnect will be attempted.
      var waitedForDisconnected = 0;
      while (c.state() != SyncState.disconnected) {
        if (waitedForDisconnected == 0) {
          print('Waiting until SyncClient state is disconnected...');
        }
        if (waitedForDisconnected == 50) {
          fail('SyncClient did not reach disconnected state within 5 seconds');
        }
        await Future.delayed(const Duration(milliseconds: 100));
        waitedForDisconnected++;
      }
      expect(c.triggerReconnect(), true);
      c.stop();
      expect(c.state(), equals(SyncState.stopped));
    });

    test('SyncClient setMultipleCredentials', () {
      SyncClient c = createClient(store);

      expect(
          () => c.setMultipleCredentials([]),
          throwsA(isA<ArgumentError>()
              .having((e) => e.name, "name", "credentials")));

      // none() not supported
      expect(
          () => c.setMultipleCredentials([SyncCredentials.none()]),
          throwsA(isA<ArgumentError>()
              .having((e) => e.name, "name", "credentials")));

      // Not throwing in Dart for any supported type
      c.setMultipleCredentials([
        SyncCredentials.googleAuthString('secret'),
        SyncCredentials.sharedSecretString('secret'),
        SyncCredentials.userAndPassword('obx', 'secret'),
        SyncCredentials.jwtIdToken('id-token'),
        SyncCredentials.jwtAccessToken('access-token'),
        SyncCredentials.jwtRefreshToken('refresh-token'),
        SyncCredentials.jwtCustomToken('custom-token')
      ]);
    });

    test('SyncClient filter variables', () {
      final filterVariables = {
        'test-var-1': 'test value 1',
        'test-var-2': 'test value 2'
      };
      SyncClient client = Sync.client(
          store, serverUrl(), SyncCredentials.none(),
          filterVariables: filterVariables);
      addTearDown(() {
        client.close();
      });

      client.putFilterVariable('test-var-2', 'test value 2');
      client.removeFilterVariable('test-var-2');
      client.putFilterVariable('test-var-2', '');
      client.removeAllFilterVariables();

      expect(
          () => client.putFilterVariable('', 'value'),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
              contains('Filter variables must have a name'))));
    });

    group('Server tests using sync-server in PATH', () {
      late SyncServer server;

      setUp(() async {
        server = SyncServer();
        serverPort = await server.start();
      });

      tearDown(() async => await server.stop());

      test('SyncClient data sync', () async {
        await server.online();
        final client1 = loggedInClient(env.store);
        final client2 = loggedInClient(env2.store);

        final box = env.store.box<TestEntitySynced>();
        final box2 = env2.store.box<TestEntitySynced>();
        int id = box.put(TestEntitySynced(value: Random().nextInt(1 << 32)));
        expect(waitUntil(() => box2.get(id) != null), isTrue);

        TestEntitySynced? read1 = box.get(id);
        TestEntitySynced? read2 = box2.get(id);
        expect(read1, isNotNull);
        expect(read2, isNotNull);
        expect(read1!.id, equals(read2!.id));
        expect(read1.value, equals(read2.value));
        client1.close();
        client2.close();
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

        waitUntilLoggedIn(client);
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

        waitUntilLoggedIn(client);
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

        waitUntilLoggedIn(client);
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
        addTearDown(() {
          client.close();
        });
        final box = env.store.box<TestEntitySynced>();
        final box2 = env2.store.box<TestEntitySynced>();
        expect(box.isEmpty(), isTrue);
        // Do multiple changes to verify only a single completion event is sent
        // after all changes are received.
        box.put(TestEntitySynced(value: 1));
        box.put(TestEntitySynced(value: 100));

        // Note: wait for the client to finish sending to the server.
        // There's currently no other way to recognize this.
        sleep(const Duration(milliseconds: 100));

        final client2 = createClient(env2.store);
        addTearDown(() {
          client2.close();
        });
        final Completer firstEvent = Completer();
        var receivedEvents = 0;
        final subscription = client2.completionEvents.listen((event) {
          if (!firstEvent.isCompleted) {
            firstEvent.complete();
          }
          receivedEvents++;
        });

        client2.start();
        waitUntilLoggedIn(client2);

        // Yield and wait for the first event...
        await firstEvent.future.timeout(defaultTimeout);
        // ...and some more on any additional events (should be none)
        await Future.delayed(Duration(milliseconds: 200));
        expect(receivedEvents, 1);
        // Note: the ID just happens to be the same as the box was unused
        expect(box2.get(2)!.value, 100);

        // Do another change
        box.put(TestEntitySynced(value: 200));
        // Yield and wait for event(s) to come in
        await Future.delayed(Duration(milliseconds: 200));
        await subscription.cancel();
        expect(receivedEvents, 2);
      });

      test('SyncClient listeners: changes', () async {
        await server.online();
        final client = loggedInClient(store);
        final client2 = loggedInClient(env2.store);

        final events = <List<SyncChange>>[];
        client2.changeEvents.listen(events.add);

        expect(env2.store.box<TestEntitySynced>().get(1), isNull);
        final box = env.store.box<TestEntitySynced>();
        final box2 = env2.store.box<TestEntitySynced>();
        box.put(TestEntitySynced(value: 10));
        env.store.runInTransaction(TxMode.write, () {
          Box<TestEntity>(env.store).put(TestEntity()); // not synced
          box.put(TestEntitySynced(value: 20));
          box.put(TestEntitySynced(value: 1));
          expect(box.remove(1), isTrue);
        });

        // wait for the data to be transferred
        expect(waitUntil(() => box2.count() == 2), isTrue);

        // check the events
        await yieldExecution();
        expect(events.length, 2);

        // box.put(TestEntitySynced(value: 10));
        expect(events[0].length, 1);
        expect(events[0][0].entity, TestEntitySynced);
        expect(events[0][0].entityId,
            InternalStoreAccess.entityDef<TestEntitySynced>(store).model.id.id);
        expect(events[0][0].puts, [1]);
        expect(events[0][0].removals, isEmpty);

        // env.store.runInTransaction(TxMode.Write, () {
        //   Box<TestEntity>(env.store).put(TestEntity()); // not synced
        //   box.put(TestEntitySynced(value: 20));
        //   box.put(TestEntitySynced(value: 1));
        //   expect(box.remove(1), isTrue);
        // });
        expect(events[1].length, 1);
        expect(events[1][0].entity, TestEntitySynced);
        expect(events[1][0].entityId,
            InternalStoreAccess.entityDef<TestEntitySynced>(store).model.id.id);
        expect(events[1][0].puts, [2, 3]);
        expect(events[1][0].removals, [1]);

        client.close();
        client2.close();
      });
    },
        skip: SyncServer.isAvailable()
            ? null
            : 'sync-server executable is not available in PATH - tests requiring it are skipped');

    group('Server tests expecting running Sync server', () {
      final String testJwtToken = "INSERT_VALID_JWT";
      final String testInvalidJwtToken =
          "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiJzeW5jLXNlcnZlciIsImlzcyI6Im9iamVjdGJveC1hdXRoIiwiZXhwIjoxNzM4MjE1NjAwLCJpYXQiOjE3MzgyMTc0MDN9.3auqtgaSEqpFqXhuCyoDM-LbfTOIEGGF6X0AjCcykJ2Nv1WN6LaVbuMDjMf-tKSLyeqFkzQbIckP4FvLHh7wQJ6rafDiT4H2pb6xhouU1QH3szK2S_7VDl_4BhxRbW5pEUt9086HXaVFHEZVS0417pxomlPHxrc1n4Z_A4QxZM5_xh5xcHV8PiGgXWb6_2basjBj5z6POTrazRs67IOQ-ob6ROIsOUGu3om6b8i0h_QSMmeJbujfr2EZqhYWTKijeyidbjRWZ97NFxtGRYN_jPOvy-T3gANXs2a32Er8XvgZTjr_-O8tl_1fHPo2kDE-UCNdwUfBQFhTokDUdJ81bg";

      /// NOTE Unlike the other tests, this test assumes a Sync server is
      /// already running on [serverPort] and has JWT auth configured.
      /// Then obtain a JWT and insert it in [testJwtToken] above.
      ///
      /// Background: Sync server needs to run in a supported environment to
      /// enable JWT authentication. So this test can not interact with a
      /// sync-server binary like the other tests.
      test('Auth with JSON Web Token (JWT)', () async {
        // Note: the objectbox project covers all cases, this test just
        // ensures the Dart parts work as expected.

        expect(testJwtToken, isNot("INSERT_VALID_JWT"),
            reason:
                "Paste a valid JWT into testJwtToken before running this test");

        // Using an already running server, at least check it's available
        await SyncServer.onlineAt(serverPort);

        // invalid token should fail to log in
        var client = createAuthenticatedClient(
            env.store, [SyncCredentials.jwtIdToken(testInvalidJwtToken)]);

        final events = <SyncLoginEvent>[];
        client.loginEvents.listen(events.add);
        client.start();
        addTearDown(() => client.close());

        expect(
            await client.loginEvents.first.timeout(defaultTimeout,
                onTimeout: () => throw TimeoutException(
                    "Did not receive login event within $defaultTimeout")),
            equals(SyncLoginEvent.credentialsRejected));

        // valid token should succeed to log in
        client.setCredentials(SyncCredentials.jwtIdToken(testJwtToken));

        waitUntilLoggedIn(client);
        await yieldExecution();

        expect(
            events,
            equals(
                [SyncLoginEvent.credentialsRejected, SyncLoginEvent.loggedIn]));
      });
    }, skip: "Test requires to manually run Sync server");
  } else {
    // TESTS to run when SYNC is NOT available

    test('SyncClient cannot be created when running with non-sync library', () {
      expect(
          () => createClient(store),
          throwsA(predicate((UnsupportedError e) => e.toString().contains(
              'Sync is not available in the loaded ObjectBox runtime library'))));
    });
  }
}

/// sync-server process wrapper for testing clients
class SyncServer {
  Directory? _dir;
  int? _port;
  Process? _process;

  static bool isAvailable() {
    // Note: this causes an additional valgrind summary output with a leak.
    // Unfortunately, it seems like we can't do anything about that...
    // Tried running with Process.start() but that didn't help. There currently
    // doesn't seem to be a way to check if a command is available so we have to
    // live with that.
    // At least, the additional error report doesn't cause valgrind to fail.
    try {
      Process.runSync('sync-server', ['--help']);
      return true;
    } on ProcessException {
      //print(e);
      return false;
    }
  }

  static Future<File> _writeConfFile(
      Directory directory, String contents) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final configFile = File('${directory.path}/sync-server-conf-test.json');
    await configFile.writeAsString(contents); // overwrites by default

    return configFile;
  }

  /// By default uses `--unsecured-no-authentication`. To use a custom
  /// authentication configuration, pass [configContents].
  /// It will be used to create a config file that is passed using `--conf`.
  ///
  /// Set [keepDb] to not delete an existing database before starting the
  /// server.
  Future<int> start({bool keepDb = false, String? configContents}) async {
    final port = _port ??= await _getUnusedPort();
    _port = port;

    final dir = _dir ??= Directory('testdata-sync-server-$port');
    _dir = dir;
    if (!keepDb) _deleteDb();

    // Note: add arguments using the '--arg=value' syntax (unlike at the
    // command line, which uses '--arg value')!
    final arguments = [
      '--db-directory=${dir.path}',
      '--model=${Directory.current.path}/test/objectbox-model.json',
      '--bind=ws://127.0.0.1:$port',
      '--admin-bind=http://127.0.0.1:${await _getUnusedPort()}'
    ];
    if (configContents != null && configContents.isNotEmpty) {
      // Note: command line arguments overwrite values in a conf file
      final configFile = await _writeConfFile(dir, configContents);
      arguments.add("--conf=${configFile.absolute.path}");
    } else {
      arguments.add('--unsecured-no-authentication');
    }

    print("Starting Sync server with arguments: $arguments");
    final process = await Process.start('sync-server', arguments);
    _process = process;

    // Make log output visible when running tests
    stdout.addStream(process.stdout);
    stderr.addStream(process.stderr);

    return port;
  }

  /// Like [onlineAt], but assuming the [_port] of this server.
  Future<void> online() async {
    return onlineAt(_port!);
  }

  /// Wait for the server to respond to a simple http request.
  /// This simple check speeds up test by only trying to log in after the server
  /// has started, avoiding the reconnect backoff intervals altogether.
  static Future<void> onlineAt(int port) async => Future(() async {
        final httpClient = HttpClient();
        while (true) {
          try {
            await httpClient.get('127.0.0.1', port, '');
            break;
          } on SocketException catch (e) {
            // Only retry if "Connection refused" (not using error codes as they
            // differ by platform).
            if (e.osError!.message.contains('Connection refused')) {
              await Future<void>.delayed(const Duration(milliseconds: 1));
            } else {
              rethrow;
            }
          }
        }
        httpClient.close(force: true);
      }).timeout(defaultTimeout,
          onTimeout: () => throw TimeoutException(
              "Server did not come online within $defaultTimeout ms"));

  Future<void> stop({bool keepDb = false}) async {
    final proc = _process;
    if (proc == null) return;
    _process = null;
    proc.kill(ProcessSignal.sigint);
    final exitCode = await proc.exitCode;
    if (exitCode != 0) {
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
    if (_dir != null && _dir!.existsSync()) {
      _dir!.deleteSync(recursive: true);
    }
  }
}
