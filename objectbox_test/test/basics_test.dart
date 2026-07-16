import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
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

  test('dartStringFromC handles malformed UTF-8', () {
    final ptr = malloc<ffi.Uint8>(3);
    ptr.asTypedList(3).setAll(0, [0x61, 0xFF, 0x00]);
    try {
      expect(() => dartStringFromC(ptr.cast()), throwsFormatException);
      // Error messages are decoded leniently so a malformed message (e.g.
      // embedded OS strings) does not mask the actual error.
      expect(dartStringFromC(ptr.cast(), allowMalformed: true), 'a�');
    } finally {
      malloc.free(ptr);
    }
  });

  group('database version check', () {
    const min = "5.3.2-2026-05-05";

    test('accepts same or newer versions', () {
      expect(isAtLeastDatabaseVersion(min, min), isTrue);
      // Same version and date, including flags suffix
      expect(isAtLeastDatabaseVersion("5.3.2-2026-05-05 (Sync)", min), isTrue);
      // Later date, including pre-release label
      expect(isAtLeastDatabaseVersion("5.3.2-next-2026-05-16", min), isTrue);

      // Newer versions (and older date on purpose to verify it's ignored)
      // Newer patch version
      expect(isAtLeastDatabaseVersion("5.3.3-2026-05-04", min), isTrue);
      // Two-digit components must compare numerically, not lexicographically
      expect(isAtLeastDatabaseVersion("5.3.10-2026-05-04", min), isTrue);
      // Newer minor version
      expect(isAtLeastDatabaseVersion("5.4.0-2026-05-04", min), isTrue);
      expect(isAtLeastDatabaseVersion("5.10.0-2026-05-04", min), isTrue);
      // Newer major version
      expect(isAtLeastDatabaseVersion("6.0.0-2026-05-04", min), isTrue);
      expect(isAtLeastDatabaseVersion("10.0.0-2026-05-04", min), isTrue);
    });

    test('rejects older versions', () {
      // Lower versions (and same date to verify it's ignored)
      expect(isAtLeastDatabaseVersion("5.3.1-2026-05-05", min), isFalse);
      expect(isAtLeastDatabaseVersion("5.2.9-2026-05-05", min), isFalse);
      expect(isAtLeastDatabaseVersion("4.9.9-2026-05-05", min), isFalse);
      // Same version, but older date
      expect(isAtLeastDatabaseVersion("5.3.2-2026-05-04", min), isFalse);
    });

    test('rejects unrecognized version formats', () {
      final invalidFormatError = throwsA(isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('Version string not in expected format')));

      expect(
          () => isAtLeastDatabaseVersion("unknown", min), invalidFormatError);
      expect(
          () => isAtLeastDatabaseVersion(min, "unknown"), invalidFormatError);
      expect(() => isAtLeastDatabaseVersion("5.3.2", min), invalidFormatError);
      expect(() => isAtLeastDatabaseVersion(min, "5.3.2"), invalidFormatError);
    });
  });

  test('model containsUid covers property index UIDs', () {
    final model = ModelInfo.empty();
    final entity = model.createEntity('A');
    final prop = entity.createProperty('indexedProp');
    prop.indexId = model.createIndexId();
    final prop2 = entity.createProperty('otherIndexedProp');
    prop2.indexId = model.createIndexId();

    // The UID of the older (non-last) index must be known to the model so
    // duplicate-UID guards and generateUid() can not collide with it.
    expect(model.containsUid(prop.indexId!.uid), isTrue);
    expect(() => entity.createProperty('newProp', prop.indexId!.uid),
        throwsStateError);
  });
}
