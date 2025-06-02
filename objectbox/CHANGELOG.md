## latest

## 4.3.0 (2025-05-28)

* Update ObjectBox database for Flutter Linux/Windows, Dart Native apps to [4.3.0](https://github.com/objectbox/objectbox-c/releases/tag/v4.3.0).
  This includes significant improvements to ObjectBox Sync like raising the maximum messages/transaction size.
* Update ObjectBox database for Flutter Android apps to 4.3.0.
  If your project is [using Admin](https://docs.objectbox.io/data-browser#admin-for-android), make
  sure to update to `io.objectbox:objectbox-android-objectbrowser:4.3.0` in `android/app/build.gradle`.
* Update ObjectBox database for Flutter iOS/macOS apps to 4.3.0.
  For existing projects, run `pod repo update` and `pod update ObjectBox` in the `ios` or `macos` directories.
* External property types (via [MongoDB connector](https://sync.objectbox.io/mongodb-sync-connector)):
  add `jsonToNative` to support sub (embedded/nested) documents/arrays in MongoDB.

## 4.2.0 (2025-04-15)

* Requires at least Dart SDK 3.4 or Flutter SDK 3.22.
* Allow analyzer 7, dart_style 3, source_gen 2 and pointycastle 4. [#705](https://github.com/objectbox/objectbox-dart/issues/705)
* Examples: demos are compatible with JDK 21 included with Android Studio Ladybug or later, require
  Flutter SDK 3.24 (with Dart SDK 3.5) or newer.
* Update ObjectBox database for Flutter Linux/Windows, Dart Native apps to [4.2.0](https://github.com/objectbox/objectbox-c/releases/tag/v4.2.0).
* Update ObjectBox database for Flutter Android apps to 4.2.0.
  If your project is [using Admin](https://docs.objectbox.io/data-browser#admin-for-android), make
  sure to update to `io.objectbox:objectbox-android-objectbrowser:4.2.0` in `android/app/build.gradle`.
* Update ObjectBox database for Flutter iOS/macOS apps to 4.2.0.
  For existing projects, run `pod repo update` and `pod update ObjectBox` in the `ios` or `macos` directories.

## 4.1.0 (2025-02-04)

* Flutter for Android: requires Android 5.0 (API level 21).
* Vector Search: You can now use the new `VectorDistanceType.GEO` distance-type to perform vector searches on
  geographical coordinates. This is particularly useful for location-based applications.
* Flutter for Linux/Windows, Dart Native: update to [objectbox-c 4.1.0](https://github.com/objectbox/objectbox-c/releases/tag/v4.1.0).
* Flutter for Android: update to [objectbox-android 4.1.0](https://github.com/objectbox/objectbox-java/releases/tag/V4.1.0).
  If your project is [using Admin](https://docs.objectbox.io/data-browser#admin-for-android), make sure to
  update to `io.objectbox:objectbox-android-objectbrowser:4.1.0` in `android/app/build.gradle`.
* Flutter for iOS/macOS: update to [objectbox-swift 4.1.0](https://github.com/objectbox/objectbox-swift/releases/tag/v4.1.0).
  For existing projects, run `pod repo update` and `pod update ObjectBox` in the `ios` or `macos` directories.

### Sync

* Add [JWT authentication](https://sync.objectbox.io/sync-server-configuration/jwt-authentication).
* Sync clients can send multiple credentials for login.

## 4.0.3 (2024-10-17)

* Generator: replace cryptography library, allows to use newer versions of the transitive `js` dependency. [#638](https://github.com/objectbox/objectbox-dart/issues/638)
* iOS: support `Query.findWithScores()` with big objects (> 4 KB), previously would throw a
  `StorageException: Do not use vector-based find on 32 bit systems with big objects`. [#676](https://github.com/objectbox/objectbox-dart/issues/676)
* Make closing the Store more robust. It waits for ongoing queries and transactions to finish.
  This is just an additional safety net. Your code should still make sure to finish all Store
  operations, like queries, before closing it.
* Flutter for Linux/Windows, Dart Native: update to [objectbox-c 4.0.2](https://github.com/objectbox/objectbox-c/releases/tag/v4.0.2).
* Flutter for iOS/macOS: update to [objectbox-swift 4.0.1](https://github.com/objectbox/objectbox-swift/releases/tag/v4.0.1).
  Existing projects may have to run `pod repo update` and `pod update ObjectBox`.
* Flutter for Android: update to [objectbox-android 4.0.3](https://github.com/objectbox/objectbox-java/releases/tag/V4.0.3).
  If you are [using Admin](https://docs.objectbox.io/data-browser#admin-for-android), make sure to
  update to `io.objectbox:objectbox-android-objectbrowser:4.0.3` in `android/app/build.gradle`.

### Sync
* **Fix a serious regression, please update as soon as possible.**
* Add special compression for tiny transactions (internally).

## 4.0.2 (2024-08-14)

* Sync: support option to enable [shared global IDs](https://sync.objectbox.io/advanced/object-ids#shared-global-ids).

## 4.0.1 (2024-05-27)

* Export `ObjectWithScore` and `IdWithScore` used by the new find with score `Query` methods. [#637](https://github.com/objectbox/objectbox-dart/issues/637)
* Add simple `vectorsearch_cities` Dart Native example application.

Note: this release includes the same versions of the Android library and ObjectBox pod as
[release 4.0.0](https://github.com/objectbox/objectbox-dart/releases/tag/v4.0.0).
See update instructions there.

## 4.0.0 (2024-05-15)

**To upgrade to this major release** run `flutter pub upgrade objectbox --major-versions`
  (or for Dart Native apps `dart pub upgrade objectbox --major-versions`).

**ObjectBox now supports on-device [Vector Search](https://docs.objectbox.io/on-device-ann-vector-search)** to enable 
efficient similarity searches.

This is particularly useful for AI/ML/RAG applications, e.g. image, audio, or text similarity. Other
use cases include semantic search or recommendation engines.

Create a Vector (HNSW) index for a floating point vector property. For example, a `City` with a
location vector:

```dart
@Entity()
class City {

  @HnswIndex(dimensions: 2)
  @Property(type: PropertyType.floatVector)
  List<double>? location;

}
```

Perform a nearest neighbor search using the new `nearestNeighborsF32(queryVector, maxResultCount)`
query condition and the new "find with scores" query methods (the score is the distance to the 
query vector). For example, find the 2 closest cities:

```dart
final madrid = [40.416775, -3.703790];
final query = box
    .query(City_.location.nearestNeighborsF32(madrid, 2))
    .build();
final closest = query.findWithScores()[0].object;
```

For an introduction to Vector Search, more details and other supported languages see the 
[Vector Search documentation](https://docs.objectbox.io/on-device-ann-vector-search).

* The generator correctly errors when using an unsupported index on a vector type.
* Flutter for Linux/Windows, Dart Native: update to [objectbox-c 4.0.0](https://github.com/objectbox/objectbox-c/releases/tag/v4.0.0).
* Flutter for Android: update to [objectbox-android 4.0.0](https://github.com/objectbox/objectbox-java/releases/tag/V4.0.0).
  If you are [using Admin](https://docs.objectbox.io/data-browser#admin-for-android), make sure to
  update to `io.objectbox:objectbox-android-objectbrowser:4.0.0` in `android/app/build.gradle`.
* Flutter for iOS/macOS: update to [objectbox-swift 2.0.0](https://github.com/objectbox/objectbox-swift/releases/tag/v2.0.0).
  Existing projects may have to run `pod repo update` and `pod update ObjectBox`.

## 2.5.1 (2024-03-04)

* Add `SyncCredentials.userAndPassword()`.
* Change `SyncCredentials` from constructors to static methods. This should not require any changes
  in your code.

## 2.5.0 (2024-02-14)

* Support creating file-less in-memory databases, for example for caching or testing. To create one
  pass an in-memory identifier together with `Store.inMemoryPrefix` as the `directory`:
  ```dart
   final inMemoryStore =
       Store(getObjectBoxModel(), directory: "${Store.inMemoryPrefix}test-db");
  ```
  See the `Store` documentation for details.
* Add `Store.removeDbFiles()` to conveniently delete database files or an in-memory database.
* Add `Store.dbFileSize()` to get the size in bytes of the main database file or memory occupied by
  an in-memory database.
* Add `relationCount()` query condition to match objects that have a certain number of related
  objects pointing to them. E.g. `Customer_.orders.relationCount(2)` will match all customers with
  two orders. `Customer_.orders.relationCount(0)` will match all customers with no associated order.
  This can be useful to find objects where the relation was dissolved, e.g. after the related object
  was removed.
* Support for setting a maximum data size via the `maxDataSizeInKB` property when building a `Store`.
  This is different from the existing `maxDBSizeInKB` property in that it is possible to remove data
  after reaching the limit and continue to use the database. See the `Store` documentation for more
  details.
* For `DateTime` properties new convenience query conditions are generated that accept `DateTime`
  and auto-convert to milliseconds (or nanoseconds for `@Property(type: PropertyType.dateNano)`) [#287](https://github.com/objectbox/objectbox-dart/issues/287)
  ```dart
  // For example instead of:
  Order_.date.between(DateTime(2024, 1).millisecondsSinceEpoch, DateTime(2024, 2).millisecondsSinceEpoch)
  // You can now just write:
  Order_.date.betweenMilliseconds(DateTime(2024, 1), DateTime(2024, 2))
  ```
* When defining a property with a getter and setter instead of a field, support annotating the
  getter to configure or ignore the property [#392](https://github.com/objectbox/objectbox-dart/issues/392)
  
  For example, it is now possible to do this:
  ```dart
  @Property(type: PropertyType.date)
  @Index()
  DateTime get date => TODO;
  set date(DateTime value) => TODO;
  
  @Transient()
  int get computedValue => TODO;
  set computedValue(int value) => TODO;
  ```
* For Flutter apps: `loadObjectBoxLibraryAndroidCompat()` is now called by default when using
  `openStore()` (effective after re-running `flutter pub run build_runner build`). For devices
  running Android 6 or older this will pre-load the ObjectBox library in Java to prevent errors when
  loading it in Dart.

  If your code was calling the compat method manually, remove the call and re-run above command.

  Let us know if there are issues with this change in [#369](https://github.com/objectbox/objectbox-dart/issues/369)!
* Avoid conflicts with entity class names in generated code [#519](https://github.com/objectbox/objectbox-dart/issues/519)
* Flutter for Linux/Windows, Dart Native: update to [objectbox-c 0.21.0](https://github.com/objectbox/objectbox-c/releases/tag/v0.21.0).
* Flutter for Android: update to [objectbox-android 3.8.0](https://github.com/objectbox/objectbox-java/releases/tag/V3.8.0).
  If you are [using Admin](https://docs.objectbox.io/data-browser#admin-for-android), make sure to
  update to `io.objectbox:objectbox-android-objectbrowser:3.8.0` in `android/app/build.gradle`.
* Flutter for iOS/macOS: update to [objectbox-swift 1.9.2](https://github.com/objectbox/objectbox-swift/releases/tag/v1.9.2).
  Existing projects may have to run `pod repo update` and `pod update ObjectBox`.

## 2.4.0 (2023-12-13)

* Fix crash in Flutter plugin when running in debug mode on iOS. [#561](https://github.com/objectbox/objectbox-dart/issues/561)
* Support Flutter projects using Android Gradle Plugin 8. [#581](https://github.com/objectbox/objectbox-dart/issues/581)
* Flutter for Linux/Windows: fix CMake build deprecation warning. [#522](https://github.com/objectbox/objectbox-dart/issues/522)
* Flutter for Linux/Windows, Dart Native: update to [objectbox-c 0.20.0](https://github.com/objectbox/objectbox-c/releases/tag/v0.20.0).
* Flutter for Android: update to [objectbox-android 3.7.1](https://github.com/objectbox/objectbox-java/releases/tag/V3.7.1).
  If you are [using Admin](https://docs.objectbox.io/data-browser#admin-for-android), make sure to
  update to `io.objectbox:objectbox-android-objectbrowser:3.7.1` in `android/app/build.gradle`.
  Notably requires Android 4.4 (API 19) or higher.
* Flutter for iOS/macOS: update to [objectbox-swift 1.9.1](https://github.com/objectbox/objectbox-swift/releases/tag/v1.9.1).
  Existing projects may have to run `pod repo update` and `pod update ObjectBox`.
  Notably requires at least iOS 12.0 and macOS 10.15.
* Sync: add `Sync.clientMultiUrls` to work with multiple servers.

## 2.3.1 (2023-10-02)

* Fix "Loaded ObjectBox core dynamic library has unsupported version 0.18.1" on Android

## 2.3.0 (2023-09-19)

* **Query support for integer and floating point lists**: For integer lists (excluding byte lists)
  greater, less and equal are supported on elements of the vector (e.g. "has element greater").
  
  For floating point lists greater and less queries are supported on elements of the vector
 (e.g. "has element greater").

  A simple example is a shape entity that stores a palette of RGB colors:
  ```dart
  @Entity()
  class Shape {
      @Id()
      int id = 0;

      // An array of RGB color values that are used by this shape.
      Int32List? palette;
  }
  
  // Find all shapes that use red in their palette
  final query = store.box<Shape>()
          .query(Shape_.palette.equals(0xFF0000))
          .build();
  query.findIds();
  query.close();
  ```
* Queries: all expected results are now returned when using a less-than or less-or-equal condition 
  for a String property with `IndexType.value`. [#318](https://github.com/objectbox/objectbox-dart/issues/318)
* Queries: when combining multiple conditions with OR and adding a condition on a related entity
  ("link condition") the combined conditions are now properly applied. [#546](https://github.com/objectbox/objectbox-dart/issues/546)
* Update: [objectbox-c 0.19.0](https://github.com/objectbox/objectbox-c/releases/tag/v0.19.0).
  Notably now requires glibc 2.28 or higher (and GLIBCXX_3.4.25); e.g. at least **Debian Buster 10 
  (2019) or Ubuntu 20.04**.
* Update: [objectbox-swift 1.9.0](https://github.com/objectbox/objectbox-swift/releases/tag/v1.9.0).
  Existing projects may have to run `pod repo update` and `pod update ObjectBox`.
* Update: [objectbox-android 3.7.0](https://github.com/objectbox/objectbox-java/releases/tag/V3.7.0).
  If you are [using Admin](https://docs.objectbox.io/data-browser#setup), make sure to update to 
  `io.objectbox:objectbox-android-objectbrowser:3.7.0`.

## 2.2.1 (2023-08-22)

* Resolve an issue where not all query results are returned, when an entity constructor or property 
  setter itself executes a query. [#550](https://github.com/objectbox/objectbox-dart/issues/550)

## 2.2.0 (2023-08-08)

* For Flutter apps running on Android 6 (or older): added `loadObjectBoxLibraryAndroidCompat()` to 
  `objectbox_flutter_libs` (and `objectbox_sync_flutter_libs`). Use this to fix loading the 
  ObjectBox library on these devices.
  
  Let us know if this works for you in [#369](https://github.com/objectbox/objectbox-dart/issues/369)!
  We might consider calling this automatically in a future release.
* Improve code generator performance if there are many entities with many constructor parameters.
* Throw `StateError` instead of crashing on closed `Box`, `Query` and `PropertyQuery`.
* Export query property classes to make them usable in user code.
* Resolve an issue where unexpected data was returned when doing a read operation in an entity 
  constructor or property setter. [#550](https://github.com/objectbox/objectbox-dart/issues/550)

## 2.1.0 (2023-06-13)

* **Support for integer and floating point lists**: store 8-bit, 16-bit, 32-bit and 64-bit integer
  lists as well as 32-bit and 64-bit floating point lists (called "vectors" by ObjectBox).

  Use a `typed_data` class like `Int16List`, `Uint16List` or `Float32List` for large lists, it uses
  less memory and CPU. Otherwise just [use a Dart number list](https://docs.objectbox.io/advanced/custom-types).

  A simple example is a shape entity that stores a palette of RGB colors:
  ```dart
  @Entity()
  class Shape {
      @Id()
      int id = 0;

      // An array of RGB color values that are used by this shape.
      Int32List? palette;
  }
  ```

  This can also be useful to store vector embeddings produced by machine learning:
  ```dart
  @Entity()
  class ImageEmbedding {
      @Id()
      int id = 0;

      // Link to the actual image, e.g. on Cloud storage
      String? url;

      // The coordinates computed for this image (vector embedding)
      @Property(type: PropertyType.floatVector)
      List<double>? coordinates;
  }
  ```
  Note: for queries currently only the `isNull` and `notNull` conditions are supported.
* Changed `PropertyType.char` from a 8-bit signed integer to a 16-bit unsigned integer to match the 
  ObjectBox database type.
* Fix put returning an incorrect error message in a rare case.
* Require at least Dart SDK 2.18 (shipped with Flutter 3.3.0).
* Let `Store.awaitQueueCompletion` actually wait on the async queue to become idle. It previously
  behaved like `Store.awaitQueueSubmitted`.
* Fix analysis event send failure breaking the code generator. #542

## 2.0.0 (2023-03-21)

* **To upgrade to this major release** run `flutter pub upgrade objectbox --major-versions` 
  (or for Dart Native apps `dart pub upgrade objectbox --major-versions`).
* **Breaking changes to generated code:** run `flutter pub run build_runner build`
  (or `dart run build_runner build` for Dart Native apps) after updating!
* Added and updated async APIs in `Box`:
  * new `getAsync`, `getManyAsync`, `getAllAsync`,
  * new `putAsync` and `putManyAsync` which support objects with relations,
  * renamed the former `putAsync` to `putQueuedAwaitResult`,
  * new `putAndGetAsync` and `putAndGetManyAsync` which return a copy of the given objects with new
    IDs set.
  * new `removeAsync`, `removeManyAsync` and `removeAllAsync`.
* Add new async `Query` APIs: `findAsync`, `findFirstAsync`, `findUniqueAsync`, `findIdsAsync` and 
  `removeAsync`.
* Support sending objects containing `ToOne` and `ToMany` across isolates, e.g. when using
  `store.runInTransactionAsync`. #340
* `Store.attach` (and `Store.fromReference`) do not longer accept a null model, which was not
  supported anyhow.
* **Breaking change:** renamed `store.awaitAsyncSubmitted` and `awaitAsyncCompletion` to
  `awaitQueueSubmitted` and `awaitQueueCompletion` to avoid any mix-up with the new async methods.
* Removed deprecated `Store.runIsolated`.
* Require at least Dart SDK 2.15 (shipped with Flutter 2.8.0).

## 1.7.2 (2023-01-31)

* Flutter Linux apps do not longer fail to run due to the shared ObjectBox C library not loading. #504
* Fixes writes failing with "Storage error (code -30786)", which may occur in some corner cases on 
  iOS and some Android devices. #485
* Update: [objectbox-c 0.18.1](https://github.com/objectbox/objectbox-c/releases/tag/v0.18.1).
* Update: [objectbox-swift 1.8.1](https://github.com/objectbox/objectbox-swift/releases/tag/v1.8.1).
  Existing projects may have to run `pod repo update` and `pod update ObjectBox`.
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
  Linux, Windows). This is where the [`install.sh`](../install.sh) script downloads it by default.
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
