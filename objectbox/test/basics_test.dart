import 'dart:ffi' as ffi;
import 'package:objectbox/internal.dart';
import 'package:objectbox/src/bindings/bindings.dart';
import 'package:objectbox/src/bindings/helpers.dart';
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

    final error = latestNativeError();
    expect(error.nativeMsg, matches('Argument .+ must not be null'));
  });

  test('model UID generation', () {
    final model = ModelInfo();
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
    expect(read /*!*/ .tString, 'foo');
    store2.close();
    env.close();
  });
}
