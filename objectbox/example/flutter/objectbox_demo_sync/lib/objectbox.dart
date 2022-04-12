import 'dart:io';

import 'package:objectbox_sync_flutter_libs/objectbox_sync_flutter_libs.dart';

import 'model.dart';
import 'objectbox.g.dart'; // created by `flutter pub run build_runner build`

/// Provides access to the ObjectBox Store throughout the app.
///
/// Create this in the apps main function.
class ObjectBox {
  /// The Store of this app.
  late final Store store;

  /// A Box of notes.
  late final Box<Note> noteBox;

  /// A stream of all notes ordered by date.
  late final Stream<Query<Note>> queryStream;

  ObjectBox._create(this.store) {
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

  /// Create an instance of ObjectBox to use throughout the app.
  static Future<ObjectBox> create() async {
    final store = Store(getObjectBoxModel(),
        directory: (await defaultStoreDirectory()).path + '-sync',
        macosApplicationGroup: 'objectbox.demo' // TODO replace with a real name
        );
    return ObjectBox._create(store);
  }

  /// Add a note within a transaction.
  ///
  /// To avoid frame drops, run ObjectBox operations that take longer than a
  /// few milliseconds, e.g. putting many objects, in an isolate with its
  /// own Store instance.
  /// For this example only a single object is put which would also be fine if
  /// done here directly.
  Future<void> addNote(String text) =>
      store.runInTransactionAsync(TxMode.write, _addNoteInTx, text);

  static void _addNoteInTx(Store store, String text) {
    // Perform ObjectBox operations that take longer than a few milliseconds
    // here. To keep it simple, this example just puts a single object.
    store.box<Note>().put(Note(text));
  }
}
