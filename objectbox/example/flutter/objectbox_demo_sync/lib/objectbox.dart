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

  ObjectBox._create(this.store) {
    noteBox = Box<Note>(store);

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

  Stream<List<Note>> getNotes() {
    // Query for all notes, sorted by their date.
    // https://docs.objectbox.io/queries
    final builder = noteBox.query().order(Note_.date, flags: Order.descending);
    // Build and watch the query,
    // set triggerImmediately to emit the query immediately on listen.
    return builder
        .watch(triggerImmediately: true)
        // Map it to a list of notes to be used by a StreamBuilder.
        .map((query) => query.find());
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

  /// Note: due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983)
  /// not using a closure as it may capture more objects than expected.
  /// These might not be send-able to an isolate. See Store.runAsync for details.
  static void _addNoteInTx(Store store, String text) {
    // Perform ObjectBox operations that take longer than a few milliseconds
    // here. To keep it simple, this example just puts a single object.
    store.box<Note>().put(Note(text));
  }
}
