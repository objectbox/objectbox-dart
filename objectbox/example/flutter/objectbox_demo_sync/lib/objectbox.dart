import 'dart:io';

import 'package:objectbox_sync_flutter_libs/objectbox_sync_flutter_libs.dart';

import 'model.dart';
import 'objectbox.g.dart'; // created by `flutter pub run build_runner build`

/// Provides access to the ObjectBox Store throughout the app.
///
/// Initialized in the apps main function.
class ObjectBox {
  Store? _store;

  /// A Box of notes.
  late final Box<Note> noteBox;

  /// A stream of all notes ordered by date.
  late final Stream<Query<Note>> queryStream;

  /// Initialize the store.
  Future<void> init() async {
    final store = Store(getObjectBoxModel(),
        directory: (await defaultStoreDirectory()).path + '-sync',
        macosApplicationGroup: 'objectbox.demo' // replace with a real name
        );
    _store = store;

    noteBox = Box<Note>(store);
    final qBuilder = noteBox.query()
      ..order(Note_.date, flags: Order.descending);
    queryStream = qBuilder.watch(triggerImmediately: true);

    // TODO configure actual sync server address and authentication
    // For configuration and docs, see objectbox/lib/src/sync.dart
    // 10.0.2.2 is your host PC if an app is run in an Android emulator.
    // 127.0.0.1 is your host PC if an app is run in an iOS simulator.
    final syncServerIp = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    final syncClient =
        Sync.client(store, 'ws://$syncServerIp:9999', SyncCredentials.none());
    syncClient.start();
  }

  /// Returns the open Store for this app or throws.
  Store get store {
    final store = _store;
    if (store != null) {
      return store;
    } else {
      throw Exception('Store was not initialized on app launch');
    }
  }
}
