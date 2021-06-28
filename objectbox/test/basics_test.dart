import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:objectbox/internal.dart';
import 'package:objectbox/src/native/bindings/bindings.dart';
import 'package:objectbox/src/native/bindings/helpers.dart';
import 'package:objectbox/src/store.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

void main() {
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
    env.close();
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
    env.close();
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
}
