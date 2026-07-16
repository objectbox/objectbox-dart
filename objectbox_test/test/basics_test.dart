import 'dart:ffi' as ffi;

import 'package:objectbox/internal.dart';
import 'package:objectbox/objectbox.dart';
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

  print("Testing basics of ObjectBox using C lib V${libraryVersion()} "
      "with database version ${Store.databaseVersion()}");

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

  group('database version check', () {
    const min = "5.3.2-2026-05-05";

    test('accepts same or newer versions', () {
      expect(isAtLeastDatabaseVersion(min, min), isTrue);
      // Flags suffix on otherwise equal version and date.
      expect(isAtLeastDatabaseVersion("5.3.2-2026-05-05 (Sync)", min), isTrue);
      // Pre-release label between version and date.
      expect(isAtLeastDatabaseVersion("5.3.2-next-2026-05-16", min), isTrue);
      expect(isAtLeastDatabaseVersion("5.3.3-2026-06-01", min), isTrue);
      expect(isAtLeastDatabaseVersion("5.4.0-2026-06-01", min), isTrue);
      expect(isAtLeastDatabaseVersion("6.0.0-2027-01-01", min), isTrue);
      // Two-digit components must compare numerically, not lexicographically.
      expect(isAtLeastDatabaseVersion("5.3.10-2026-09-01", min), isTrue);
      expect(isAtLeastDatabaseVersion("5.10.0-2027-01-01", min), isTrue);
      expect(isAtLeastDatabaseVersion("10.0.0-2028-01-01", min), isTrue);
    });

    test('rejects older versions', () {
      expect(isAtLeastDatabaseVersion("5.3.1-2026-05-01", min), isFalse);
      expect(isAtLeastDatabaseVersion("5.2.9-2026-05-05", min), isFalse);
      expect(isAtLeastDatabaseVersion("4.9.9-2026-05-05", min), isFalse);
      // Same version, but older build date.
      expect(isAtLeastDatabaseVersion("5.3.2-2026-05-04", min), isFalse);
    });

    test('accepts unrecognized version formats', () {
      // The version string format "may change in any future release", the
      // numeric C API version check is the authoritative compatibility gate.
      expect(isAtLeastDatabaseVersion("unknown", min), isTrue);
      expect(isAtLeastDatabaseVersion("5.3.2", min), isTrue);
    });
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
