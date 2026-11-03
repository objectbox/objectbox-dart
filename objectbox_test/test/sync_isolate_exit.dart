// Not a test suite, a program started by a test in sync_test.dart:
// dart test/sync_isolate_exit.dart <server URL> <database directory>
//
// Like a Flutter app whose engine is destroyed while the process stays alive
// (https://github.com/objectbox/objectbox-dart/issues/841): an isolate opens a
// store and starts a sync client, then exits without closing either. Exits
// with code 0 if the process survives this.

import 'dart:io';
import 'dart:isolate';

import 'entity_sync.dart';
import 'objectbox.g.dart';

void _openStoreAndStartClient(List<String> args) {
  final store = Store(getObjectBoxModel(), directory: args[1]);
  final client = SyncClient(store, [args[0]], [SyncCredentials.none()]);
  client.start();
  final stopwatch = Stopwatch()..start();
  while (client.state() != SyncState.loggedIn) {
    if (stopwatch.elapsed > const Duration(seconds: 10)) {
      throw StateError('SyncClient did not log in');
    }
    sleep(const Duration(milliseconds: 10));
  }
  // Exit while the client is still sending and awaiting the ACK for this
  // change. Do not close the client or the store.
  store.box<TestEntitySynced>().put(TestEntitySynced(value: 1));
}

Future<void> main(List<String> args) async {
  final exited = ReceivePort();
  final errors = ReceivePort();
  await Isolate.spawn(
    _openStoreAndStartClient,
    args,
    onExit: exited.sendPort,
    onError: errors.sendPort,
  );
  errors.listen((error) {
    stderr.writeln('Isolate failed: $error');
    exit(1);
  });
  await exited.first;
  // Give the sync client threads time to use the store.
  await Future<void>.delayed(const Duration(seconds: 3));
  exit(0);
}
