import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'model.dart';
import 'objectbox.g.dart'; // created by `dart run build_runner build`

/// Provides access to the ObjectBox Store throughout the app.
///
/// Create this in the apps main function.
class ObjectBox {
  /// The Store of this app.
  late final Store _store;

  /// A Box of tasks.
  late final Box<Task> _taskBox;

  ObjectBox._create(this._store) {
    _taskBox = _store.box();

    // TODO configure actual sync server address and authentication
    // For configuration and docs, see objectbox/lib/src/sync.dart
    // 10.0.2.2 is your host PC if an app is run in an Android emulator.
    // 127.0.0.1 is your host PC if an app is run in an iOS simulator.
    final syncServerIp = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    final syncClient =
        Sync.client(_store, 'ws://$syncServerIp:9999', SyncCredentials.none());
    syncClient.start();
  }

  /// Create an instance of ObjectBox to use throughout the app.
  static Future<ObjectBox> create() async {
    // Note: setting a unique directory is recommended if running on desktop
    // platforms. If none is specified, the default directory is created in the
    // users documents directory, which will not be unique between apps.
    // On mobile this is typically fine, as each app has its own directory
    // structure.

    // Note: set macosApplicationGroup for sandboxed macOS applications, see the
    // info boxes at https://docs.objectbox.io/getting-started for details.

    // Future<Store> openStore() {...} is defined in the generated objectbox.g.dart
    final store = await openStore(
        directory: p.join(
            (await getApplicationDocumentsDirectory()).path, "obx-demo-sync"),
        macosApplicationGroup: "objectbox.demo");
    return ObjectBox._create(store);
  }

  Stream<List<Task>> getTasks() {
    // Query for all tasks, sorted by their date.
    // https://docs.objectbox.io/queries
    final builder =
        _taskBox.query().order(Task_.dateCreated, flags: Order.descending);
    // Build and watch the query,
    // set triggerImmediately to emit the query immediately on listen.
    return builder
        .watch(triggerImmediately: true)
        // Map it to a list of notes to be used by a StreamBuilder.
        .map((query) => query.find());
  }

  /// Add a task.
  ///
  /// To avoid frame drops, run ObjectBox operations that take longer than a
  /// few milliseconds, e.g. putting many objects, asynchronously.
  /// For this example only a single object is put which would also be fine if
  /// done using [Box.put].
  Future<void> addTask(String text) => _taskBox.putAsync(Task(text));

  Future<void> removeTask(int id) => _taskBox.removeAsync(id);

  Future<void> changeTaskFinished(Task task, bool isFinished) {
    task.setIsFinished(isFinished);
    return _taskBox.putAsync(task);
  }
}
