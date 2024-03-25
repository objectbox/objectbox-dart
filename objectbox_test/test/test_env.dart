import 'dart:io';

import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';

/// Test environment for ObjectBox. Call [closeAndDelete] to clean up after
/// a test.
///
/// For a test file or group of tests:
/// ```
/// late TestEnv env;
/// setUp(() {
///   env = TestEnv('name');
/// });
/// tearDown(() => env.closeAndDelete());
/// ```
///
/// For a single test:
/// ```
/// final env = TestEnv('name');
/// addTearDown(() => env.closeAndDelete());
/// ```
class TestEnv {
  /// If environment variable OBX_IN_MEMORY=true is set, this will be true.
  ///
  /// If tests should be run with an in-memory database, so not using files.
  final bool isInMemory;
  final String dbDirPath;
  final Store store;

  /// If environment variable TEST_SHORT=1 is set, this will be true.
  ///
  /// If true, try to run tests quicker, e.g. with less objects or iterations.
  /// This was used to speed up valgrind analysis and avoid CI timeouts.
  final bool short;

  static String testDbDirPath(String name, {bool inMemory = false}) =>
      inMemory ? "${Store.inMemoryPrefix}testdata-$name" : "testdata-$name";

  /// Creates a store in a directory based on the given [name], or if in-memory
  /// with name as the identifier. Deletes any database files before.
  factory TestEnv(String name, {bool? queryCaseSensitive, int? debugFlag}) {
    final inMemory = Platform.environment["OBX_IN_MEMORY"] == "true";
    if (inMemory) {
      print("Using in-memory database for testing");
    }
    final String dbDirPath = testDbDirPath(name, inMemory: inMemory);
    // Ensure there is no leftover data from a previous test failure.
    _cleanUpDatabase(inMemory, dbDirPath);

    final Store store;
    var modelDefinition = getObjectBoxModel();
    try {
      store = queryCaseSensitive == null
          ? Store(modelDefinition, directory: dbDirPath, debugFlags: debugFlag)
          : Store(modelDefinition,
              directory: dbDirPath,
              debugFlags: debugFlag,
              queriesCaseSensitiveDefault: queryCaseSensitive);
    } catch (ex) {
      if (!inMemory) {
        final dir = Directory(dbDirPath);
        print("$dir exists: ${dir.existsSync()}");
      }
      print("Store is open: ${Store.isOpen(dbDirPath)}");
      print("Model Info: ${modelDefinition.model.toMap()}");
      rethrow;
    }
    return TestEnv._(inMemory, dbDirPath, store,
        Platform.environment.containsKey('TEST_SHORT'));
  }

  TestEnv._(this.isInMemory, this.dbDirPath, this.store, this.short);

  Box<TestEntity> get box => store.box();

  /// Call once done with this to clean up, for example in [tearDown] or using
  /// [addTearDown]. Safe to call multiple times.
  void closeAndDelete() {
    store.close();
    _cleanUpDatabase(isInMemory, dbDirPath);
  }

  static void _cleanUpDatabase(bool isInMemory, String dbDirPath) {
    // Note: removeDbFiles does not remove the directory, so do it manually.
    Store.removeDbFiles(dbDirPath);
    if (!isInMemory) {
      final dir = Directory(dbDirPath);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
  }
}

const defaultTimeout = Duration(milliseconds: 1000);

/// "Busy-waits" until the predicate returns true.
bool waitUntil(bool Function() predicate, {Duration timeout = defaultTimeout}) {
  var success = false;
  final until = DateTime.now().add(timeout);

  while (!(success = predicate()) && until.isAfter(DateTime.now())) {
    sleep(const Duration(milliseconds: 1));
  }
  return success;
}

/// same as package:test unorderedEquals() but statically typed
Matcher sameAsList<T>(List<T> list) => unorderedEquals(list);

// Yield execution to other isolates.
//
// We need to do this to receive an event in the stream before processing
// the remainder of the test case.
Future<void> yieldExecution() async =>
    await Future<void>.delayed(Duration.zero);

bool atLeastDart(String expectedLowestVersion) {
  final dartVersion = RegExp('([0-9]+).([0-9]+).([0-9]+)')
      .firstMatch(Platform.version)
      ?.group(0);
  if (dartVersion != null && dartVersion.compareTo(expectedLowestVersion) > 0) {
    return true;
  } else {
    return false;
  }
}
