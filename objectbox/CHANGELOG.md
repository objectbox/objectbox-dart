## latest


## 1.7.2 (2023-01-31)

* Flutter Linux apps do not longer fail to run due to the shared ObjectBox C library not loading. #504
* Fixes writes failing with "Storage error (code -30786)", which may occur in some corner cases on 
  iOS and some Android devices. #485
* Update: [objectbox-c 0.18.1](https://github.com/objectbox/objectbox-c/releases/tag/v0.18.1).
* Update: [objectbox-swift 1.8.1](https://github.com/objectbox/objectbox-swift/releases/tag/v1.8.1).
* Update: [objectbox-android 3.5.1](https://github.com/objectbox/objectbox-java/releases/tag/V3.5.1).
  If you are using Admin, make sure to [update your `objectbox-android-objectbrowser` dependency](https://docs.objectbox.io/data-browser#setup).

## 1.7.1 (2023-01-17)

* Send anonymous data when running code generator to help us analyze its usage.

## 1.7.0 (2022-12-14)

* Support more concise method chaining when using a sort order with a query:
  ```dart
  // BEFORE
  final query = (box.query()..order(Person_.name)).build();
  // AFTER
  final query = box.query().order(Person_.name).build();
  ```
* Allow `analyzer` with major version 5. #487
* Generator not longer warns that it can not find the package source root if the output directory is
  the package root directory.
* Query: add `.containsElement`, deprecate `.contains` condition for `List<String>`. #481
* Add `StorageException` which is a `ObjectBoxException` with an `errorCode` (a `OBX_ERROR` code).
* Throw `DbFullException` instead of `ObjectBoxException` with message `10101 Could not put` (error 
  code `OBX_ERROR_DB_FULL`).
* Change `Query.findUnique()` to throw `NonUniqueResultException` instead of 
  `UniqueViolationException` if there is more than one result.
* Update: [objectbox-c 0.18.0](https://github.com/objectbox/objectbox-c/releases/tag/v0.18.0).
* Update: [objectbox-android 3.5.0](https://github.com/objectbox/objectbox-java/releases/tag/V3.5.0).
* Update: [objectbox-swift 1.8.1-rc](https://github.com/objectbox/objectbox-swift/releases/tag/v1.8.0).

## 1.6.2 (2022-08-24)

* Revert to [objectbox-android 3.2.0](https://github.com/objectbox/objectbox-java/releases/tag/V3.2.0) 
  to restore query functionality (#460). If you are using Admin, make sure to update your 
  `objectbox-android-objectbrowser` dependency.
* Generator messages should be more helpful, provide code location when possible and link to docs.

## 1.6.1 (2022-08-22)

* Store: add option to pass debug flags. #134 
* Add `// coverage:ignore-file` to generated objectbox.g.dart skipping this file from coverage test.
* Increase supported `analyzer` to v4. #443
* Update documentation on `Query` streams using `watch` to highlight it is a single-subscription
  stream that can only be listened to once. Also updated code examples to not imply the stream is
  re-usable.
* Update: [objectbox-android 3.2.1](https://github.com/objectbox/objectbox-java/releases/tag/V3.2.1).

## 1.6.0 (2022-06-27)

* Require at least Dart SDK 2.14 (shipped with Flutter 2.5.0).
* When using the "All Exceptions" debug option in Visual Studio Code there is no longer an exception
when initializing ObjectBox. #252
* Update: [objectbox-c 0.17.0](https://github.com/objectbox/objectbox-c/releases/tag/v0.17.0).
* Update: [objectbox-android 3.2.0](https://github.com/objectbox/objectbox-java/releases/tag/V3.2.0).

## 1.5.0 (2022-05-11)

* Add `Store.runInTransactionAsync` to run database operations asynchronously in the background
  (requires Flutter 2.8.0/Dart 2.15.0 or newer). #415
* Rename `Store.runIsolated` to `runAsync`, drop unused `mode` parameter, propagate errors and
  handle premature isolate exit. #415
* The native ObjectBox library is also searched for in the `lib` subfolder on desktop OS (macOS,
  Linux, Windows). This is where the [`install.sh`](/install.sh) script downloads it by default.
  E.g. it is no longer necessary to install the library globally to run `dart test` or `flutter test`.
* Windows: Support database directory paths that contain unicode (UTF-8) characters. #406
* Changed `Query.stream` to collect results in a worker isolate, which should typically be faster. #420
* Update: [objectbox-c 0.16.0](https://github.com/objectbox/objectbox-c/releases/tag/v0.16.0).
* Update: [objectbox-android 3.1.3](https://github.com/objectbox/objectbox-java/releases/tag/V3.1.3).
* Add new [task with tag list Flutter example app](example/flutter/objectbox_demo_relations) that 
  shows how to use relations. #419

## 1.4.1 (2022-03-01)

* Resolve "another store is still open" issue after Flutter hot restart (hot reload continues to work). #387
* Add `Store.isClosed()`. #390
* Add note to `objectbox.g.dart` on how to re-generate (update) it.

## 1.4.0 (2022-02-22)

* Support [ObjectBox Admin](https://docs.objectbox.io/data-browser) for Android apps to browse 
  the database. #148
* Add `Store.runIsolated` to run database operations (asynchronous) in the background 
  (requires Flutter 2.8.0/Dart 2.15.0 or newer). It spawns an isolate, runs the given callback in that 
  isolate with its own Store and returns the result of the callback. This is similar to Flutters 
  compute, but with the callback having access to a Store. #384
* Add `Store.attach` to attach to a Store opened in a directory. This is an improved replacement for 
  `Store.fromReference` to share a Store across isolates. It is no longer required to pass a
  Store reference and the underlying Store remains open until the last instance is closed. #376
* Add an option to change code-generator's `output_dir` in `pubspec.yaml`. #341
* Update: [objectbox-c 0.15.2](https://github.com/objectbox/objectbox-c/releases/tag/v0.15.0).
* Update: [objectbox-android 3.1.2](https://github.com/objectbox/objectbox-java/releases/tag/V3.1.0).
* Update: [objectbox-swift 1.7.0](https://github.com/objectbox/objectbox-swift/releases/tag/v1.7.0).

## 1.3.0 (2021-11-22)

* Support annotating a single property with `@Unique(onConflict: ConflictStrategy.replace)` to 
  replace an existing object if a conflict occurs when doing a put. #297

## 1.2.1 (2021-11-09)

* Fix Flutter apps crashing on iOS 15 simulator. #313
* Fix `ToMany.applyToDb()` not working after putting object with empty `ToMany`.
* Update objectbox-android to `3.0.1`.

## 1.2.0 (2021-08-31)

* Add `Query.findUnique()` to find a single object matching the query.
* Add support for relations when using 3rd-party JSON serialization libraries.
* Fix generator when mixing backlinks and "standard" relations in the same entity (generated code had a syntax error).
* Fix `@Backlink()` annotation when specifying a `ToOne` relation by field name.
* Fix `Query.find*()` exception forwarding when a user-provided property converter throws. 
* Increase supported `analyzer` dependency version to include v2.x major version.
* Update FlatBuffer dependency to the latest upstream version.

## 1.1.1 (2021-07-09)

* Add support for `Query.param()` on linked entities.
* Fix generated `openStore()` for apps that don't enable null-safety yet.

## 1.1.0 (2021-07-06)

* New `openStore()` in the generated code to simplify creating a store instance, especially on Flutter (uses application
  documents directory as a default). 
* Add support for Entities used together with some custom code-generators (immutable objects, JSON, ...).
  See `@Entity(realClass: )` new field and its docs.
* New `Query.param()` to support reusable queries (changing condition values before execution).
  See [Reusing queries](https://docs.objectbox.io/queries#reusing-queries-and-parameters) in docs.
* Rename semi-internal `QueryRelationProperty` to `QueryRelationToOne` and `QueryRelationMany` to `QueryRelationToMany`
  to help users pick the right link function: `link()` vs `linkMany()`.
* Add support for the entity/property/relation rename or reset workflow.
  See [Data model updates](https://docs.objectbox.io/advanced/data-model-updates) for details.
* Add support for `ToOne` relation cycles.
* Enforce you can only open the same database directory once (multiple parallel `Store` instances are not allowed).
* Fix `macOS` sandbox database directory permissions (see notes in Flutter-specific "Getting Started" docs).
* Fix `ToMany` showing duplicate items after adding them before reading the previous list.
* Fix invalid native free during store shutdown if large data was inserted (more than 64 kilobytes flatbuffer).
* FlatBuffers serialization performance improvements.
* Update to objectbox-android v2.9.2-RC3.

## 1.0.0 (2021-05-18)

* New Box `putAsync()` returning a `Future` and `putQueued()` for asynchronous writes.
* Query now supports auto-closing. You can still call `close()` manually if you want to free native resources sooner 
  than they would be by Dart's garbage collector, but it's not mandatory anymore.
* Change the "meta-model" fields to provide completely type-safe query building.
  Conditions you specify are now checked at compile time to match the queried entity.
* Make property queries fully typed, `PropertyQuery.find()` now returns the appropriate `List<...>` type without casts.
* Query conditions `inside()` renamed to `oneOf()`, `notIn()` and `notInList()` renamed to `notOneOf()`.
* Query `stream` and `findStream()` are replaced by `QueryBuilder.watch()`, i.e. `box.query(...).watch()`.
* New Query `stream()` to stream objects all the while the query is executed in the background.
* New Query condition `between()` for integers and IDs.
* Store `subscribe<EntityType>()` renamed to `watch()`.
* Store `subscribeAll()` replaced by a shared broadcast stream `entityChanges`.
* Entities can now contain `final` fields and they're properly stored/loaded (must be constructor params).
* Flutter desktop - native library is now downloaded automatically, same as for mobile platforms.
* Follow exception-vs-error throwing conventions - throwing errors when it's a permanent developer-caused error. Namely,
  there's a new `UniqueViolationException` thrown when an object you're trying to `put()` would violate a `Unique()` index.
* Even higher than usual amount of internal optimizations and improvements.
* Update to objectbox-c v0.14.0.
* Update to objectbox-swift v1.6.0.
* Update to objectbox-android v2.9.2-RC.

## 0.14.0 (2021-04-01)

* Fix non-nullable `DateTime` fields deserialization regression (introduced in v0.13.0) - fields were read as nanosecond instead of millisecond timestamp.
* Respect case-sensitivity setting in string `PropertyQuery.count()` with `distinct = true` (the result was always like with `caseSensitive = true`).
* Query `findFirst()` doesn't change `Query` object's `offset` and `limit` anymore.  
* Change Query string conditions `caseSensitive` default to `true`, previously conditions were case-insensitive by default.
* Introduce Store constructor argument `queriesCaseSensitiveDefault` - allows changing the default value of `caseSensitive` in queries.
  This includes string `PropertyQuery` when using `distinct = true`.
* Get around Flutter's Android release build issue by changing the code the compiler had trouble with.
* Remove deprecated APIs from internal plugin interfaces (deprecation notice printed during Flutter build).  
* Generator - update dependencies to their null-safe versions.
* Generated code - avoid more linter issues.

## 0.13.0 (2021-03-19)

* Null-safety support: both in the library and the generated code.
* Remove deprecated arguments `offset`, `limit`, `withEqual` from `Query` methods.
* More performance optimizations, mostly in our FlatBuffers fork.
* Fix FlatBuffers builder growing.
* Update to objectbox-c v0.13.0
* Update to objectbox-android v2.9.1
* Increase minimum SDK versions: Flutter v2.0 & Dart v2.12.

## 0.12.2 (2021-03-11)

* Fix `ToMany` relation internal ID assignment when multiple relations are used.
* Support `ToMany` relation code generation regardless of order of class definitions.

## 0.12.1 (2021-03-05)

* Further performance optimizations in our FlatBuffers fork.
* Avoid empty FFI structs - get rid of "INFO" messages with new Dart SDK v2.12.
* More internal changes in preparation for null-safety. 

## 0.12.0 (2021-02-26)

* Recognize `DateTime` entity fields, setting `PropertyType.date` (millisecond storage precision). 
* Support specifying `PropertyType.dateNano` for `DateTime` fields (nanosecond storage precision).  
* Add `Store.reference` getter and `Store.fromReference()` factory - enabling access to store from multiple isolates.
* Add `Store.subscribe<EntityType>()` and `Store.subscribeAll()` data change event streams.
* Add multiple `SyncClient` event streams.
* Add `Query` conditions for `lessOrEqual`/`greaterOrEqual` on integer and double property types.
* Add self-assignable IDs: annotation `@Id(assignable: true)`.  
* Update to objectbox-c v0.12.0
* Update to objectbox-android v2.9.0
* Update to objectbox-swift v1.5.0
* Increase minimum SDK versions: Flutter v1.20 & Dart v2.9. Code generator already required Flutter v1.22 & Dart v2.10. 

## 0.11.2 (2021-03-11)

* Fix `ToMany` relation internal ID assignment when multiple relations are used.
* Support `ToMany` relation code generation regardless of order of class definitions.

## 0.11.1 (2021-02-26)

* Fix `List<String>` and `List<int>` reading - replace official FlatBuffers lazy reader with a custom (eager) one.

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
