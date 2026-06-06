import 'dart:io';
import 'dart:typed_data';

import 'package:android_runner/objectbox.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:objectbox/internal.dart';
import 'package:objectbox/src/native/sync.dart';
import 'package:path_provider/path_provider.dart';

// We want to have types explicit - verifying the return types of functions.
// ignore_for_file: omit_local_variable_types

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Store store;
  late Store store2;
  late String dbDir;
  late String dbDir2;
  int serverPort = 9999;

  serverUrl() => 'ws://127.0.0.1:$serverPort';

  setUp(() async {
    final appDir = await getApplicationDocumentsDirectory();
    dbDir = '${appDir.path}/testdata-sync';
    dbDir2 = '${appDir.path}/testdata-sync2';
    _cleanDir(dbDir);
    _cleanDir(dbDir2);
    store = Store(getObjectBoxModel(), directory: dbDir);
    store2 = Store(getObjectBoxModel(), directory: dbDir2);
  });

  tearDown(() {
    store.close();
    store2.close();
    _cleanDir(dbDir);
    _cleanDir(dbDir2);
  });

  SyncClient createClient(Store s) =>
      SyncClient(s, [serverUrl()], [SyncCredentials.none()]);

  test('Model Entity has sync enabled', () {
    final model = getObjectBoxModel().model;
    final entity = model.entities.firstWhere(
      (e) => e.name == 'TestEntitySynced',
    );
    expect(entity.hasFlag(OBXEntityFlags.SYNC_ENABLED), isTrue);
  });

  test('SyncCredentials string encoding', () {
    final str = 'uũú';
    expect(
      (SyncCredentials.sharedSecretString(str) as SyncCredentialsSecret).data,
      equals(Uint8List.fromList([117, 197, 169, 195, 186])),
    );
  });

  group(
    'Tests if Sync is not available',
    () {
      test('SyncClient cannot be created when running with non-sync library', () {
        expect(
          () => createClient(store),
          throwsA(
            predicate(
              (UnsupportedError e) => e.toString().contains(
                'Sync is not available in the loaded ObjectBox runtime library',
              ),
            ),
          ),
        );
      });
    },
    skip:
        Sync.isAvailable()
            ? 'Sync is available in the loaded database library'
            : null,
  );

  group(
    'Tests if Sync is available',
    () {
      test('SyncClient lifecycle', () {
        expect(store.syncClient(), isNull);

        SyncClient c1 = createClient(store);
        expect(store.syncClient(), equals(c1));

        expect(
          () => createClient(store),
          throwsA(
            predicate(
              (StateError e) => e.toString().contains('one sync client'),
            ),
          ),
        );

        expect(c1.isClosed(), isFalse);
        c1.close();
        expect(c1.isClosed(), isTrue);
        expect(store.syncClient(), isNull);
      });

      test('SyncClient instance caching', () {
        {
          final client = createClient(store);
          expect(client.isClosed(), isFalse);
        }
        SyncClient? client = store.syncClient();
        expect(client, isNotNull);
        expect(client!.isClosed(), isFalse);
        client.close();
        expect(store.syncClient(), isNull);
      });

      test('SyncClient throws if empty URL list', () {
        expect(
          () => SyncClient(store, [], [SyncCredentials.none()]),
          throwsA(
            isArgumentError.having(
              (e) => e.message,
              'message',
              contains('At least one URL must be added'),
            ),
          ),
        );
      });

      test('SyncClient throws if empty credential list', () {
        expect(
          () => SyncClient(store, ['test-url'], []),
          throwsA(
            isArgumentError.having(
              (e) => e.message,
              'message',
              contains('Credentials must be provided'),
            ),
          ),
        );
      });

      test('SyncClient is closed when a store is closed', () {
        final client = createClient(store2);
        store2.close();
        _cleanDir(dbDir2);
        store2 = Store(getObjectBoxModel(), directory: dbDir2);
        expect(client.isClosed(), isTrue);
      });

      test('different Store => different SyncClient', () {
        SyncClient c1 = createClient(store);
        SyncClient c2 = createClient(store2);
        expect(c1, isNot(equals(c2)));
      });

      test('SyncClient states (no server available)', () {
        SyncClient client = createClient(store);
        expect(client.state(), equals(SyncState.created));
        client.start();
        expect(client.state(), equals(SyncState.started));
        client.stop();
        expect(client.state(), equals(SyncState.stopped));
        client.close();
      });

      test('SyncClient access after closing must throw', () {
        SyncClient c = createClient(store);
        c.close();
        expect(c.isClosed(), isTrue);

        final error = throwsA(
          predicate(
            (StateError e) =>
                e.toString().contains('SyncClient already closed'),
          ),
        );
        expect(() => c.start(), error);
        expect(() => c.stop(), error);
        expect(() => c.state(), error);
        expect(() => c.cancelUpdates(), error);
        expect(() => c.requestUpdates(subscribeForFuturePushes: true), error);
        expect(() => c.outgoingMessageCount(), error);
        expect(() => c.setCredentials(SyncCredentials.none()), error);
        expect(
          () => c.setCredentials(SyncCredentials.sharedSecretString('secret')),
          error,
        );
        expect(
          () => c.setCredentials(
            SyncCredentials.userAndPassword('obx', 'secret'),
          ),
          error,
        );
        expect(
          () => c.setMultipleCredentials([
            SyncCredentials.sharedSecretString('secret'),
            SyncCredentials.userAndPassword('obx', 'secret'),
          ]),
          error,
        );
        expect(
          () => c.setRequestUpdatesMode(SyncRequestUpdatesMode.auto),
          error,
        );
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
          SyncCredentials.googleAuthUint8List(Uint8List.fromList([13, 0, 25])),
        );
        c.setCredentials(
          SyncCredentials.sharedSecretUint8List(
            Uint8List.fromList([13, 0, 25]),
          ),
        );
        c.setCredentials(SyncCredentials.userAndPassword('obx', 'secret'));
        c.setCredentials(SyncCredentials.jwtIdToken('id-token'));
        c.setCredentials(SyncCredentials.jwtAccessToken('access-token'));
        c.setCredentials(SyncCredentials.jwtRefreshToken('refresh-token'));
        c.setCredentials(SyncCredentials.jwtCustomToken('custom-token'));

        c.setCredentials(SyncCredentials.none());
        c.setRequestUpdatesMode(SyncRequestUpdatesMode.manual);
        c.start();
        expect(c.requestUpdates(subscribeForFuturePushes: true), isFalse);
        expect(c.requestUpdates(subscribeForFuturePushes: false), isFalse);
        expect(c.outgoingMessageCount(), isZero);

        // Wait until client reaches state disconnected (as there is no server).
        var waitedForDisconnected = 0;
        while (c.state() != SyncState.disconnected) {
          if (waitedForDisconnected == 0) {
            print('Waiting until SyncClient state is disconnected...');
          }
          if (waitedForDisconnected == 100) {
            fail(
              'SyncClient did not reach disconnected state within 10 seconds',
            );
          }
          await Future.delayed(const Duration(milliseconds: 100));
          waitedForDisconnected++;
        }
        expect(c.triggerReconnect(), true);
        c.stop();
        expect(c.state(), equals(SyncState.stopped));
        c.close();
      });

      test('SyncClient setMultipleCredentials', () {
        SyncClient c = createClient(store);

        expect(
          () => c.setMultipleCredentials([]),
          throwsA(
            isA<ArgumentError>().having((e) => e.name, "name", "credentials"),
          ),
        );

        expect(
          () => c.setMultipleCredentials([SyncCredentials.none()]),
          throwsA(
            isA<ArgumentError>().having((e) => e.name, "name", "credentials"),
          ),
        );

        c.setMultipleCredentials([
          SyncCredentials.googleAuthString('secret'),
          SyncCredentials.sharedSecretString('secret'),
          SyncCredentials.userAndPassword('obx', 'secret'),
          SyncCredentials.jwtIdToken('id-token'),
          SyncCredentials.jwtAccessToken('access-token'),
          SyncCredentials.jwtRefreshToken('refresh-token'),
          SyncCredentials.jwtCustomToken('custom-token'),
        ]);
        c.close();
      });

      test('SyncClient filter variables', () {
        SyncClient client = SyncClient(
          store,
          [serverUrl()],
          [SyncCredentials.none()],
          filterVariables: {
            'test-var-1': 'test value 1',
            'test-var-2': 'test value 2',
          },
        );
        addTearDown(() => client.close());

        client.putFilterVariable('test-var-2', 'test value 2');
        client.removeFilterVariable('test-var-2');
        client.putFilterVariable('test-var-2', '');
        client.removeAllFilterVariables();
        client.putFilterVariable('test-var-1', 'test value 1 updated');
        client.applyFilterVariables();

        expect(
          () => client.putFilterVariable('', 'value'),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Filter variables must have a name'),
            ),
          ),
        );
      });

      test('SyncClient certificatePaths', () {
        SyncClient multiple = SyncClient(
          store,
          [serverUrl()],
          [SyncCredentials.none()],
          certificatePaths: [
            '/path/to/does-not-exist-1.crt',
            '/path/to/does-not-exist-2.crt',
          ],
        );
        multiple.close();

        SyncClient empty = SyncClient(
          store,
          [serverUrl()],
          [SyncCredentials.none()],
          certificatePaths: [],
        );
        empty.close();
      });

      test('SyncClient flags', () {
        SyncClient client = SyncClient(
          store,
          [serverUrl()],
          [SyncCredentials.none()],
          flags:
              OBXSyncFlags.DebugLogIdMapping |
              OBXSyncFlags.KeepDataOnSyncError |
              OBXSyncFlags.DebugLogFilterVariables |
              OBXSyncFlags.RemoveWithObjectData |
              OBXSyncFlags.DebugLogTxLogs |
              OBXSyncFlags.SkipInvalidTxOps,
        );
        client.close();
      });

      test('Mesh sync smoke test', () async {
        SyncClient client = SyncClient(
          store,
          [serverUrl()],
          [SyncCredentials.none()],
          mesh: MeshConfig(
            'test-mesh',
            maxConnectionCount: 3,
            backoffMillis: 5000,
            randomSeed: 42,
            discoveryDurationSeconds: 10,
          ),
        );

        MeshSync? mesh = client.mesh;
        expect(mesh, isNotNull);

        // Before start, the mesh is just created.
        expect(mesh!.state(), equals(MeshState.created));
        expect(mesh.stateString(), isNotEmpty);
        expect(mesh.connectedPeerCount(), isZero);

        // All statistics counters should be readable and zero initially.
        for (final counter in MeshStats.values) {
          expect(mesh.stats(counter), isZero, reason: counter.name);
        }

        // Starting the client also starts the mesh: it begins discovering peers.
        // The transition happens on a background thread, so wait for it.
        client.start();
        var waitedForDiscovering = 0;
        while (mesh.state() != MeshState.discovering) {
          if (waitedForDiscovering == 100) {
            fail('Mesh did not reach discovering state within 10 seconds');
          }
          await Future.delayed(const Duration(milliseconds: 100));
          waitedForDiscovering++;
        }

        client.stop();
        expect(mesh.state(), equals(MeshState.stopped));

        // Closing the client invalidates the mesh; any further access must throw.
        client.close();
        final error = throwsA(
          predicate(
            (StateError e) => e.toString().contains('MeshSync already closed'),
          ),
        );
        expect(() => mesh.state(), error);
        expect(() => mesh.stateString(), error);
        expect(() => mesh.connectedPeerCount(), error);
        expect(() => mesh.stats(MeshStats.peersConnected), error);
      });

      test('SyncClient without mesh config has no mesh', () {
        SyncClient client = createClient(store);
        addTearDown(() => client.close());
        expect(client.mesh, isNull);
      });

      test('SyncClient stats', () {
        SyncClient client = createClient(store);
        addTearDown(() => client.close());

        // All counters are readable and zero before connecting to a server.
        for (final counter in SyncStats.values) {
          expect(client.stats(counter), isZero, reason: counter.name);
        }
      });

      test('syncClockTimestamp', () {
        final clockValue = 1860802100721610852;
        final expectedTime = 1774599171372;

        expect(Sync.syncClockTimestamp(clockValue), equals(expectedTime));
        expect(
          Sync.syncClockTimestampCorrected(clockValue),
          equals(expectedTime - 10),
        );
      });
    },
    skip:
        Sync.isAvailable()
            ? null
            : 'Sync is not available in the loaded database library',
  );
}

void _cleanDir(String path) {
  Store.removeDbFiles(path);
  final dir = Directory(path);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
}
