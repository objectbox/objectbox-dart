import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:objectbox/src/native/bindings/bindings.dart';
import 'package:objectbox/src/store.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

void main() {
  test('store reference', () {
    final env = TestEnv('store');
    addTearDown(() => env.closeAndDelete());

    final store1 = env.store;
    final store2 = Store.fromReference(getObjectBoxModel(), store1.reference);
    expect(store1, isNot(store2));
    expect(InternalStoreAccess.ptr(store1), InternalStoreAccess.ptr(store2));

    final id = store1.box<TestEntity>().put(TestEntity(tString: 'foo'));
    expect(id, 1);
    final read = store2.box<TestEntity>().get(id);
    expect(read, isNotNull);
    expect(read!.tString, 'foo');
    store2.close();
  });

  test('in-memory store does not create files', () {
    final store = Store(getObjectBoxModel(),
        directory: "${Store.inMemoryPrefix}in-memory-test");
    addTearDown(() => store.close());
    expect(Directory("in-memory-test").existsSync(), false);
    expect(Directory("memory").existsSync(), false);
    expect(Directory("memory:in-memory-test").existsSync(), false);
  });

  test('store attach fails if same isolate', () {
    final env = TestEnv('store');
    addTearDown(() => env.closeAndDelete());

    expect(
        () => Store.attach(getObjectBoxModel(), env.dbDirPath),
        throwsA(predicate((UnsupportedError e) =>
            e.message!.contains('Cannot create multiple Store instances'))));
  });

  test('store attach remains open if main store closed', () async {
    final env = TestEnv('store');
    addTearDown(() => env.closeAndDelete());

    final store1 = env.store;
    final receivePort = ReceivePort();
    final received = StreamQueue<dynamic>(receivePort);
    await Isolate.spawn(storeAttachIsolate,
        StoreAttachIsolateInit(receivePort.sendPort, env.dbDirPath));
    final commandPort = await received.next as SendPort;

    // Check native instance pointer is different.
    final store2Address = await received.next as int;
    expect(InternalStoreAccess.ptr(store1).address, isNot(store2Address));

    final id = store1.box<TestEntity>().put(TestEntity(tString: 'foo'));
    expect(id, 1);
    // Close original store to test store remains open until all refs closed.
    store1.close();
    expect(Store.isOpen(env.dbDirPath), true);

    // Read data with attached store.
    commandPort.send(id);
    final readtString = await received.next as String?;
    expect(readtString, isNotNull);
    expect(readtString, 'foo');

    // Close attached store, should close store completely.
    commandPort.send(null);
    await received.next;
    expect(Store.isOpen(env.dbDirPath), false);

    // Dispose StreamQueue.
    await received.cancel();
  });

  test('store attach with configuration', () {
    final name = "store";
    final env = TestEnv(name);
    // Closing manually below, but clean up if any expect fails before
    addTearDown(() => env.closeAndDelete());

    // Get store config.
    final storeConfig = env.store.configuration();
    expect(storeConfig.id, isNot(0));

    // Obtain store by ID.
    var store = StoreInternal.attachByConfiguration(storeConfig);
    expect(store.configuration().id, storeConfig.id);
    // Release reference.
    store.close();

    // Try again to obtain by ID.
    final store2 = StoreInternal.attachByConfiguration(storeConfig);
    expect(store2.configuration().id, storeConfig.id);
    store2.close();

    // Close underlying store, should not longer be able to obtain by ID.
    env.closeAndDelete();
    expect(
        () => StoreInternal.attachByConfiguration(storeConfig),
        throwsA(predicate(
            (ObjectBoxException e) => e.message == "failed to create store")));

    // Re-open underlying store, store ID should have changed.
    final env2 = TestEnv(name);
    addTearDown(() => env2.closeAndDelete());
    expect(env2.store.configuration().id, isNot(storeConfig.id));
  });

  test('store is open', () {
    final name = 'store';
    expect(Store.isOpen(''), false);
    expect(Store.isOpen(TestEnv.testDbDirPath(name)), false);
    expect(Store.isOpen(TestEnv.testDbDirPath(name, inMemory: true)), false);

    final env = TestEnv(name);
    // Closing manually below, but clean up if any expect fails before
    addTearDown(() => env.closeAndDelete());

    expect(env.store.isClosed(), false);
    expect(Store.isOpen(env.dbDirPath), true);

    env.closeAndDelete();

    expect(env.store.isClosed(), true);
    expect(Store.isOpen(env.dbDirPath), false);
  });

  test('transactions', () {
    final env = TestEnv('store');
    addTearDown(() => env.closeAndDelete());

    expect(TxMode.values.length, 2);
    for (var mode in TxMode.values) {
      // Returned value falls through.
      expect(env.store.runInTransaction(mode, () => 1), 1);

      // Async callbacks are forbidden.
      final asyncCallbacks = [
        () async => null,
        () => Future<int>.delayed(const Duration(milliseconds: 1)),
        Future<void>.value,
      ];
      for (var callback in asyncCallbacks) {
        expect(
            () => env.store.runInTransaction(mode, callback),
            throwsA(predicate((UnsupportedError e) => e.toString().contains(
                '"async" function in a transaction is not allowed'))));
      }

      // Functions that [Never] finish won't be executed at all.
      expect(
          () => env.store.runInTransaction(mode, () => throw 'hey there'),
          throwsA(predicate((UnsupportedError e) => e
              .toString()
              .contains('Given transaction callback always fails.'))));
    }
  });

  test('async transactions', () async {
    final env = TestEnv('store');
    addTearDown(() => env.closeAndDelete());

    expect(TxMode.values.length, 2);
    for (var mode in TxMode.values) {
      // Returned value falls through.
      expect(
          await env.store
              .runInTransactionAsync(mode, (store, param) => 1, null),
          1);

      // Async callbacks are forbidden.
      final asyncCallbacks = [
        (Store s, Object? p) async => null,
        (Store s, Object? p) =>
            Future<int>.delayed(const Duration(milliseconds: 1)),
        (Store s, Object? p) => Future<void>.value(),
      ];
      for (var callback in asyncCallbacks) {
        try {
          await env.store.runInTransactionAsync(mode, callback, null);
          fail("Should throw UnsupportedError");
        } on UnsupportedError catch (e) {
          expect(e.message,
              'Executing an "async" function in a transaction is not allowed.');
        }
      }

      // Functions that [Never] finish won't be executed at all.
      try {
        await env.store.runInTransactionAsync(mode, (store, param) {
          throw 'Should never execute';
        }, null);
      } on UnsupportedError catch (e) {
        expect(e.message, 'Given transaction callback always fails.');
      }
    }
  });

  test('store multi-open', () {
    final stores = <Store>[];

    createStore(String? dir) {
      stores.add(Store(getObjectBoxModel(), directory: dir));
    }

    createMustFail(String? dir) {
      expect(
          () => createStore(dir),
          throwsA(predicate((UnsupportedError e) =>
              e.toString().contains('same directory'))));
    }

    createStore(null); // uses directory 'objectbox'
    createMustFail(null);
    createMustFail('objectbox');

    Directory.current = 'objectbox';
    createMustFail('.');
    createMustFail('../objectbox');

    // restore the directory so other tests won't fail
    Directory.current = '../';

    for (var store in stores) {
      store.close();
    }
    createStore(null);

    for (var store in stores) {
      store.close();
    }
    Directory('objectbox').deleteSync(recursive: true);
  });

  test('store create close multiple', () {
    final dir = Directory('testdata-store');
    if (dir.existsSync()) dir.deleteSync(recursive: true);

    for (var i = 0; i < 1000; i++) {
      final store = Store(getObjectBoxModel(), directory: dir.path);
      store.close();
    }

    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('store create close multiple async', () async {
    final dir = Directory('testdata-store');
    if (dir.existsSync()) dir.deleteSync(recursive: true);

    for (var i = 0; i < 100; i++) {
      final createStoreFuture = Future.delayed(const Duration(milliseconds: 1),
          () => Store(getObjectBoxModel(), directory: dir.path));
      final store = await createStoreFuture;
      store.close();
    }

    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('openStore()', () {
    final store = openStore(directory: 'objectbox');
    store.close();
    Directory('objectbox').deleteSync(recursive: true);
  });

  test('store options', () {
    final store = Store(getObjectBoxModel(),
        directory: 'store',
        maxDBSizeInKB: 100,
        fileMode: int.parse('0666', radix: 8),
        maxReaders: 5,
        debugFlags:
            DebugFlags.logTransactionsRead | DebugFlags.logTransactionsWrite,
        queriesCaseSensitiveDefault: false,
        macosApplicationGroup: 'foo-bar');

    store.close();
    Directory('store').deleteSync(recursive: true);
  });

  test('store dbFileSize', () {
    final testEnv = TestEnv("db-file-size");
    expect(Store.dbFileSize(testEnv.dbDirPath), isPositive);
    testEnv.closeAndDelete();
  });

  test('store maxDBSizeInKB', () {
    final testDir = Directory('db-size-test');
    if (testDir.existsSync()) testDir.deleteSync(recursive: true);

    // Empty file is around 24 KB, object below adds about 16 KB.
    var store =
        Store(getObjectBoxModel(), directory: testDir.path, maxDBSizeInKB: 50);
    var box = store.box<TestEntity>();
    box.put(TestEntity.filled(id: 0));

    final testEntity2 = TestEntity.filled(id: 0);
    expect(
        () => box.put(testEntity2),
        throwsA(predicate((e) =>
            e is DbFullException &&
            e.errorCode == OBX_ERROR_DB_FULL &&
            e.message == 'object put failed: Could not put')));

    // Re-open with larger size.
    store.close();
    store =
        Store(getObjectBoxModel(), directory: testDir.path, maxDBSizeInKB: 60);
    testEntity2.id = 0; // Clear ID of object that failed to put.
    store.box<TestEntity>().put(testEntity2);
  });

  test('store maxDataSizeInKB', () {
    final testDir = Directory('db-data-size-test');
    if (testDir.existsSync()) testDir.deleteSync(recursive: true);

    // Throws if setting both maxDBSizeInKB and maxDataSizeInKB
    // and data size is larger.
    expect(
        () => Store(getObjectBoxModel(),
            directory: testDir.path, maxDBSizeInKB: 10, maxDataSizeInKB: 11),
        throwsA(isArgumentError.having(
            (e) => e.message,
            'message',
            contains(
                'Maximum data size option must not exceed the maximum DB size'))));

    // Throws special Dart exception if put exceeds data size
    final store =
        Store(getObjectBoxModel(), directory: testDir.path, maxDataSizeInKB: 1);
    final longString =
        "ObjectBox Flutter database is a great option for storing Dart objects locally in your cross-platform apps.";
    final box = store.box<TestEntity>();
    box.put(TestEntity.filled(id: 0, tString: longString));
    box.put(TestEntity.filled(id: 0, tString: longString));
    box.put(TestEntity.filled(id: 0, tString: longString));
    expect(
        () => box.put(TestEntity.filled(id: 0, tString: longString)),
        throwsA(isA<DbMaxDataSizeExceededException>().having((e) => e.message,
            "message", contains("Exceeded user-set maximum by [bytes]"))));
    store.close();
  });

  test('store open in unicode symbol path', () async {
    final parentDir = Directory('unicode-test');
    await parentDir.create();
    final unicodeDir = Directory(
        '${parentDir.path}${Platform.pathSeparator}Îñţérñåţîöñåļîžåţîờñ');
    final store = Store(getObjectBoxModel(), directory: unicodeDir.path);
    store.close();

    // Check only expected files and directories exist.
    final paths = await parentDir
        .list(recursive: true)
        .map((event) => event.path)
        .toList();
    expect(paths.length, 3);
    final expectedPaths = [
      unicodeDir.path,
      File('${unicodeDir.path}${Platform.pathSeparator}data.mdb').path,
      File('${unicodeDir.path}${Platform.pathSeparator}lock.mdb').path
    ];
    expect(paths, containsAll(expectedPaths));

    parentDir.deleteSync(recursive: true);
  });

  test('store run in isolate', () async {
    final env = TestEnv('store');
    addTearDown(() => env.closeAndDelete());

    final id = env.box.put(TestEntity(tString: 'foo'));
    final futureResult = env.store.runAsync(_readStringAndRemove, id);
    print('Count in main isolate: ${env.box.count()}');
    final String x = await futureResult;
    expect(x, 'foo!');
    expect(env.box.count(), 0); // Must be removed once awaited
  });

  test('store runAsync returns isolate error', () async {
    final env = TestEnv('store');
    addTearDown(() => env.closeAndDelete());

    try {
      await env.store.runAsync(_producesIsolateError, 'nothing');
      fail("Should throw RemoteError");
    } on RemoteError {
      // expected
    }
  });

  test('store runAsync returns callback error', () async {
    final env = TestEnv('store');
    addTearDown(() => env.closeAndDelete());

    try {
      await env.store.runAsync(_producesCallbackError, 'nothing');
      fail("Should throw error produced by callback");
    } catch (e) {
      expect(e, isA<ArgumentError>());
      expect(e, predicate((ArgumentError e) => e.message == 'Return me'));
    }
  });
}

Future<String> _readStringAndRemove(Store store, int id) async {
  var box = store.box<TestEntity>();
  var testEntity = box.get(id);
  final result = '${testEntity!.tString!}!';
  print('Result in 2nd isolate: $result');
  final removed = box.remove(id);
  print('Removed in 2nd isolate: $removed');
  print('Count in 2nd isolate after remove: ${box.count()}');
  // Pointless Future to test async functions are supported.
  return await Future.delayed(const Duration(milliseconds: 10), () => result);
}

// Produce an error within the isolate that triggers the onError handler case.
// Errors because ReceivePort can not be sent via SendPort.
int _producesIsolateError(Store store, String param) {
  final port = ReceivePort();
  try {
    throw port;
  } finally {
    port.close();
  }
}

// Produce an error that is caught and sent, triggering the error thrown
// by callable case.
int _producesCallbackError(Store store, String param) {
  throw ArgumentError('Return me');
}

class StoreAttachIsolateInit {
  SendPort sendPort;
  String path;

  StoreAttachIsolateInit(this.sendPort, this.path);
}

void storeAttachIsolate(StoreAttachIsolateInit init) async {
  final store2 = Store.attach(getObjectBoxModel(), init.path);

  final commandPort = ReceivePort();
  init.sendPort.send(commandPort.sendPort);
  init.sendPort.send(InternalStoreAccess.ptr(store2).address);

  await for (final message in commandPort) {
    if (message is int) {
      final read = store2.box<TestEntity>().get(message);
      init.sendPort.send(read?.tString);
    } else if (message == null) {
      store2.close();
      init.sendPort.send(null);
      break;
    }
  }

  print('Store attach isolate finished');
  Isolate.exit();
}
