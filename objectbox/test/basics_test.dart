import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:objectbox/internal.dart';
import 'package:objectbox/src/native/bindings/bindings.dart';
import 'package:objectbox/src/native/bindings/helpers.dart';
import 'package:objectbox/src/native/version.dart';
import 'package:objectbox/src/store.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

void main() {
  print("Testing basics of ObjectBox using C lib V${libraryVersion()}");

  // Prior to Dart 2.6, the exception wasn't accessible and may have crashed.
  // Similarly, this occured in Fluter for Linux (desktop).
  // https://github.com/dart-lang/sdk/issues/38141
  // https://github.com/flutter/flutter/issues/74599
  test('error reporting works', () {
    final cStore = C.store_open(ffi.nullptr);

    // sanity check - the result is a null pointer
    expect(cStore,
        isA<ffi.Pointer>().having((ptr) => ptr.address, 'address', equals(0)));

    expect(
        throwLatestNativeError,
        throwsA(predicate(
            (ArgumentError e) => e.toString().contains('must not be null'))));
  });

  test('model UID generation', () {
    final model = ModelInfo.empty();
    final uid1 = model.generateUid();
    final uid2 = model.generateUid();
    expect(uid1, isNot(equals(uid2)));
    expect(uid1, isNot(equals(0)));
    expect(uid2, isNot(equals(0)));

    var foundLargeUid = false;
    for (var i = 0; i < 1000 && !foundLargeUid; i++) {
      foundLargeUid = model.generateUid() > (1 << 32);
    }
    expect(foundLargeUid, isTrue);
  });

  test('store reference', () {
    final env = TestEnv('basics');
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
    env.closeAndDelete();
  });

  test('store attach fails if same isolate', () {
    final env = TestEnv('basics');
    expect(
        () => Store.attach(getObjectBoxModel(), env.dir.path),
        throwsA(predicate((UnsupportedError e) =>
            e.message!.contains('Cannot create multiple Store instances'))));
    env.closeAndDelete();
  });

  test('store attach remains open if main store closed', () async {
    final env = TestEnv('basics');
    final store1 = env.store;
    final receivePort = ReceivePort();
    final received = StreamQueue<dynamic>(receivePort);
    await Isolate.spawn(storeAttachIsolate,
        StoreAttachIsolateInit(receivePort.sendPort, env.dir.path));
    final commandPort = await received.next as SendPort;

    // Check native instance pointer is different.
    final store2Address = await received.next as int;
    expect(InternalStoreAccess.ptr(store1).address, isNot(store2Address));

    final id = store1.box<TestEntity>().put(TestEntity(tString: 'foo'));
    expect(id, 1);
    // Close original store to test store remains open until all refs closed.
    store1.close();
    expect(true, Store.isOpen('testdata-basics'));

    // Read data with attached store.
    commandPort.send(id);
    final readtString = await received.next as String?;
    expect(readtString, isNotNull);
    expect(readtString, 'foo');

    // Close attached store, should close store completely.
    commandPort.send(null);
    await received.next;
    expect(false, Store.isOpen('testdata-basics'));

    // Dispose StreamQueue.
    await received.cancel();
  });

  test('store is open', () {
    expect(false, Store.isOpen(''));
    expect(false, Store.isOpen('testdata-basics'));
    final env = TestEnv('basics');
    expect(false, env.store.isClosed());
    expect(true, Store.isOpen('testdata-basics'));
    env.closeAndDelete();
    expect(true, env.store.isClosed());
    expect(false, Store.isOpen('testdata-basics'));
  });

  test('transactions', () {
    final env = TestEnv('basics');
    expect(TxMode.values.length, 2);
    TxMode.values.forEach((mode) {
      // Returned value falls through.
      expect(env.store.runInTransaction(mode, () => 1), 1);

      // Async callbacks are forbidden.
      final asyncCallbacks = [
        () async => null,
        () => Future<int>.delayed(const Duration(milliseconds: 1)),
        () => Future<void>.value(),
      ];
      asyncCallbacks.forEach((callback) => expect(
          () => env.store.runInTransaction(mode, callback),
          throwsA(predicate((UnsupportedError e) => e
              .toString()
              .contains('"async" function in a transaction is not allowed')))));

      // Functions that [Never] finish won't be executed at all.
      expect(
          () => env.store.runInTransaction(mode, () => throw 'hey there'),
          throwsA(predicate((UnsupportedError e) => e
              .toString()
              .contains('Given transaction callback always fails.'))));
    });
    env.closeAndDelete();
  });

  test('store multi-open', () {
    final stores = <Store>[];

    final createStore =
        (String? dir) => stores.add(Store(getObjectBoxModel(), directory: dir));

    final createMustFail = (String? dir) => expect(
        () => createStore(dir),
        throwsA(predicate(
            (UnsupportedError e) => e.toString().contains('same directory'))));

    createStore(null); // uses directory 'objectbox'
    createMustFail(null);
    createMustFail('objectbox');

    Directory.current = 'objectbox';
    createMustFail('.');
    createMustFail('../objectbox');

    // restore the directory so other tests won't fail
    Directory.current = '../';

    stores.forEach((store) => store.close());
    createStore(null);

    stores.forEach((store) => store.close());
    Directory('objectbox').deleteSync(recursive: true);
  });

  test('openStore()', () {
    final store = openStore(directory: 'objectbox');
    store.close();
    Directory('objectbox').deleteSync(recursive: true);
  });

  test('store options', () {
    final store = Store(getObjectBoxModel(),
        directory: 'basics',
        maxDBSizeInKB: 100,
        fileMode: int.parse('0666', radix: 8),
        maxReaders: 5,
        queriesCaseSensitiveDefault: false,
        macosApplicationGroup: 'foo-bar');
    store.close();
    Directory('basics').deleteSync(recursive: true);
  });

  test('store_runInIsolatedTx', () async {
    final env = TestEnv('basics');
    final id = env.box.put(TestEntity(tString: 'foo'));
    final futureResult =
        env.store.runIsolated(TxMode.write, readStringAndRemove, id);
    print('Count in main isolate: ${env.box.count()}');
    final String x;
    try {
      x = await futureResult;
    } catch (e) {
      final dartVersion = RegExp('([0-9]+).([0-9]+).([0-9]+)')
          .firstMatch(Platform.version)
          ?.group(0);
      if (dartVersion != null && dartVersion.compareTo('2.15.0') < 0) {
        print('runIsolated requires Dart 2.15, ignoring error.');
        env.closeAndDelete();
        return;
      } else {
        rethrow;
      }
    }
    expect(x, 'foo!');
    expect(env.box.count(), 0); // Must be removed once awaited
    env.closeAndDelete();
  });
}

Future<String> readStringAndRemove(Store store, int id) async {
  var box = store.box<TestEntity>();
  var testEntity = box.get(id);
  final result = testEntity!.tString! + '!';
  print('Result in 2nd isolate: $result');
  final removed = box.remove(id);
  print('Removed in 2nd isolate: $removed');
  print('Count in 2nd isolate after remove: ${box.count()}');
  // Pointless Future to test async functions are supported.
  return await Future.delayed(const Duration(milliseconds: 10), () => result);
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
}
