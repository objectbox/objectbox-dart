import 'dart:io';

import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';

class TestEnv {
  final Directory dir;
  final Store store;
  final bool short;

  factory TestEnv(String name, {bool? queryCaseSensitive}) {
    final dir = Directory('testdata-' + name);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    final store = queryCaseSensitive == null
        ? Store(getObjectBoxModel(), directory: dir.path)
        : Store(getObjectBoxModel(),
            directory: dir.path,
            queriesCaseSensitiveDefault: queryCaseSensitive);
    return TestEnv._(
        dir, store, Platform.environment.containsKey('TEST_SHORT'));
  }

  TestEnv._(this.dir, this.store, this.short);

  Box<TestEntity> get box => store.box();

  void close() {
    store.close();
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
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
final yieldExecution = () async => await Future<void>.delayed(Duration.zero);
