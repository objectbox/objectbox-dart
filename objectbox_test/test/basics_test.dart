import 'dart:ffi' as ffi;

import 'package:objectbox/internal.dart';
import 'package:objectbox/src/native/bindings/bindings.dart';
import 'package:objectbox/src/native/bindings/helpers.dart';
import 'package:objectbox/src/native/version.dart';
import 'package:test/test.dart';

import 'test_env.dart';

void main() {
  test("Dart version test helper", () {
    expect(atLeastDart("2.15.0"), true);
    expect(atLeastDart("999.0.0"), false);
  });

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
}
