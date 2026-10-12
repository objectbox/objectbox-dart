import 'dart:io';

import 'package:objectbox_test_app/objectbox.g.dart';
import 'package:path_provider/path_provider.dart';

/// Opens a [Store] in an empty database directory and deletes it on [close].
class TestEnv {
  /// Sandboxed macOS apps need an app group for ObjectBox (see the Store docs);
  /// matches the entitlements of the macOS Runner.
  static final String? macosApplicationGroup =
      Platform.isMacOS ? 'objectbox.test' : null;

  final String dir;
  late Store store;

  /// Creates an environment with a database in the [name] directory inside
  /// the application support directory.
  static Future<TestEnv> create(String name) async {
    // Not the documents directory: on macOS that is the user's Documents folder,
    // which needs user consent (TCC) that a test run cannot give.
    // On Android, this is the files directory.
    // On iOS, this is the Library/Application Support directory of the app
    // container.
    final appDir = await getApplicationSupportDirectory();
    return TestEnv._('${appDir.path}/$name');
  }

  TestEnv._(this.dir) {
    _cleanDir();
    store = _openStore();
  }

  Store _openStore() => Store(
    getObjectBoxModel(),
    directory: dir,
    macosApplicationGroup: macosApplicationGroup,
  );

  /// Closes the store and deletes the database.
  void close() {
    store.close();
    _cleanDir();
  }

  void _cleanDir() {
    Store.removeDbFiles(dir);
    final directory = Directory(dir);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }

  /// Closes the store, deletes the database and opens a new, empty store.
  void reopenEmpty() {
    close();
    store = _openStore();
  }
}
