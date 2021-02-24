## latest

* Update to objectbox-c v0.12.0
* Update to objectbox-android v2.9.0
* Update to objectbox-swift v1.5.0

## 0.11.0 (2021-02-01)

* Add `ToOne<>` class to wrap related entities. See examples for details.
  (thanks [@Buggaboo](https://github.com/Buggaboo) for jump-starting this).
* Add `ToMany<>` class to wrap related entities. See examples for details.
* Significantly improve `Box` read and write performance.
* Change `Box.put()` and `putMany()` - now also update given object's ID property.
  Note: If you previously `put()` the same new object instance multiple times without setting id, the object will now
  be inserted only the first time, and overwritten on subsequent puts of the same instance, its ID is not zero anymore.
* Change `Box.putMany()` and `Query.FindIds()` to return fixed-size lists.
* Change `Box.GetMany()` to return a fixed-size list by default, with an option to return a growable list.
* Change `@Id()` annotation to optional - recognized automatically if there's an `int id` field (case insensitive).
* Make `observable.dart` part of `objectbox.dart` exports, no need to import it separately.  
* Expose `PutMode` - allowing semantics choice between put, update and insert.
* Hide internal classes not intended for general use (e.g. all Model* classes).
* Rename `versionLib()` to `nativeLibraryVersion()`.
* Change `TxMode` enum values to lowercase.
* Remove `flags` from the `Property()` annotation.

## 0.10.0 (2020-12-01)

* Add support for string array properties: `List<String>`.
* Add support for byte array properties: `List<Int>`, `Uint8List`, `Int8List`.
* Add `@Index()` and `@Unique()` property annotations
  (thanks [@Buggaboo](https://github.com/Buggaboo) for [#123](https://github.com/objectbox/objectbox-dart/pull/123)).
* Add `Query.remove()` to remove all objects matching the query.
* Fix `Query.findStream()` to only rerun on changes to the queried type
  (thanks [@RTrackerDev](https://github.com/RTrackerDev) and [@Buggaboo](https://github.com/Buggaboo) for [#152](https://github.com/objectbox/objectbox-dart/pull/152)).
* Change `type` field on `@Property()` annotation to PropertyType.
* Mark `offset` and `limit` query parameters deprecated, use `offset()` and `limit()` instead.
* Update to objectbox-swift 1.4.1
* Internal changes in preparation for null-safety (still waiting for our dependencies to migrate).

## 0.9.0 (2020-11-12)

* Update to objectbox-c 0.11.0
* Update to objectbox-android 2.8.0
* Change `box.get(id)` to return null instead of throwing when trying to read a non-existent object.
* Change the generator to skip read-only fields (getters)
* Add SyncClient to enable the new [ObjectBox Sync](https://objectbox.io/sync)
* Add "empty" query support using `box.query()`.
    (thanks [@Buggaboo](https://github.com/Buggaboo) for [#132](https://github.com/objectbox/objectbox-dart/pull/132))
* Expose `lib/observable.dart` to avoid linter isues in apps using objectbox.
    (thanks [@cmengler](https://github.com/cmengler) for bringing this up in [#141](https://github.com/objectbox/objectbox-dart/pull/141))
* Documentation and examples updates & improvements.
* Switch C-API binding code generation to package `ffigen`.

## 0.8.0 (2020-10-13)

* Update to objectbox-c 0.10.0.
* Update to objectbox-android 2.7.1.
* Update to objectbox-swift 1.4.0.
* String startsWith and endsWith condition: removed unused `descending` parameter, add `caseSensitive` parameter.
* String greaterThan/lessThan condition: `withEqual` is deprecated, use the greaterOrEqual/lessOrEqual condition instead.
* Query find/findIds `offset` and `limit` parameters are deprecated, set them using the equally named methods instead.
* New support to create a Dart Stream from a Query
    (thanks [@Buggaboo](https://github.com/Buggaboo) for [#88](https://github.com/objectbox/objectbox-dart/pull/88))

## 0.7.0 (2020-08-14)

* Flutter v1.20 support
    (move libs to separate package `objectbox_flutter_libs`, add it as a new dependency if you use Flutter)
* New property query support
    (thanks [Jasm Sison](https://github.com/Buggaboo) for [#75](https://github.com/objectbox/objectbox-dart/pull/75))
* New `@Transient` annotation to skip storing select properties
    (thanks [Jasm Sison](https://github.com/Buggaboo) for [#98](https://github.com/objectbox/objectbox-dart/pull/98))
* Handle `Byte` property as a signed `int8` (was previously unsigned) to align with other bindings

## 0.6.4 (2020-05-12)

* Update to objectbox-swift 1.3.0
* Update to objectbox-android 2.5.1

## 0.6.3 (2020-05-07)

* Update FlatBuffers to 1.12.0
* Provide error hinting when DB can't be created (e.g. when an app docs directory isn't passed properly on Flutter).

## 0.6.2 (2020-03-09)

* Support large object arrays on 32-bit platforms/emulators.

## 0.6.1 (2020-01-23)

* Fix Flutter Android/iOS release build failures
* Updated to objectbox-c 0.8.2

## 0.6.0 (2019-12-19)

* Flutter iOS support
* Generator fixes and rework to support multiple entity files in addition to many entities in a single file.
    Please move `objectbox-model.json` to `lib/` before running the generator.
* Simplified Android support (automatic dependency).
* Docs improvements
* Updated to objectbox-c 0.8.1

## 0.5.0 (2019-11-18)

* Dart 2.6 support - breaking change due to Dart 2.6 FFI changes.
  Please keep using 0.4 if you're on Dart 2.5/Flutter 1.9.
  (thanks [Jasm Sison](https://github.com/Buggaboo) for [#57](https://github.com/objectbox/objectbox-dart/pull/57))
* Docs fixes & improvements

## 0.4.0 (2019-10-31)

* Flutter Android support
* Queries for all currently supported types
    (thanks [Jasm Sison](https://github.com/Buggaboo) for [#27](https://github.com/objectbox/objectbox-dart/pull/27) and [#46](https://github.com/objectbox/objectbox-dart/pull/46))
* More Box functions (count, isEmpty, contains, remove and their bulk variants)
    (thanks [liquidiert](https://github.com/liquidiert) for [#42](https://github.com/objectbox/objectbox-dart/pull/42) and [#45](https://github.com/objectbox/objectbox-dart/pull/45))
* Explicit write transactions
    (thanks [liquidiert](https://github.com/liquidiert) for [#50](https://github.com/objectbox/objectbox-dart/pull/50))
* Resolved linter issues
    (thanks [Gregory Sech](https://github.com/GregorySech) for [#31](https://github.com/objectbox/objectbox-dart/pull/31))
* Updated to objectbox-c 0.7.2
* First release on pub.dev

## 0.3.0 (2019-10-15)

* ID/UID generation and model persistence (objectbox-model.json)
* CI tests using GitHub Actions
* Code cleanup, refactoring and formatting
    (thanks [Jasm Sison](https://github.com/Buggaboo) for [#20](https://github.com/objectbox/objectbox-dart/pull/20) & [#21](https://github.com/objectbox/objectbox-dart/pull/21))

## 0.2.0 (2019-09-11)

* UTF-8 support for Store and Box
    (thanks [Jasm Sison](https://github.com/Buggaboo) for [#14](https://github.com/objectbox/objectbox-dart/pull/14)!)
* Bulk put and get functions (getMany, getAll, putMany)
* Updated to objectbox-c 0.7
* Basic Store options
* Minimal unit tests
* Removed reflection code, switched to model code generation instead
* Minimal Flutter Desktop example for Dart 2.5.0

## 0.1.0 (2019-09-03)

* Minimal Store setup
* Minimal Box with put and get
