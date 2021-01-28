import 'dart:ffi' as ffi;
import 'package:objectbox/internal.dart';
import 'package:objectbox/src/bindings/bindings.dart';
import 'package:objectbox/src/bindings/helpers.dart';
import 'package:test/test.dart';

void main() {
  // Prior to Dart 2.6, the exception wasn't accessible in the core so the text wasn't reported
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
}
