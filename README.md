ObjectBox for Dart/Flutter
==========================
ObjectBox for Dart is a standalone database storing Dart objects locally, with strong ACID semantics.

Flutter/Dart compatibility
--------------------------
Starting with Flutter 1.20, additional changes were required, starting from objectbox-dart v0.7.0. 
To make sure your Flutter application works after update to Flutter 1.20, add `objectbox_flutter_libs: ^0.7.0` 
as an additional dependency, in addition to `objectbox`.

This library depends on a new Dart feature, FFI, introduced in Dart 2.5 (Flutter 1.9) as a feature preview. 
However, it has changed significantly in Dart 2.6/Flutter 1.12, i.e. introduced breaking changes we had to reflect.
Versions between ObjectBox v0.5 up to v0.6.x support Dart 2.6+ as well as Flutter 1.12+ and Flutter 1.17+.  

The last supported version for Flutter 1.9/Dart 2.5 is ObjectBox 0.4.*, so if you can't upgrade yet, please use the 
latest 0.4.x version instead.

Installation
------------
Add the following dependencies to your `pubspec.yaml`:
```yaml
dependencies:
  objectbox: ^0.7.0

dev_dependencies:
  build_runner: ^1.0.0
  objectbox_generator: ^0.7.0
```

Proceed based on whether you're developing a Flutter app or a standalone dart program:
1. **Flutter** only steps:
    * Add additional dependency to include native libraries (required in Flutter):
      ```yaml
      dependencies:
        objectbox: ^0.7.0
        objectbox_flutter_libs: ^0.7.0
      ```
    * Install the packages `flutter pub get`
    * XCode/iOS: under Architectures replace `${ARCHS_STANDARD)` with `arm64` (or `$ARCHS_STANDARD_64_BIT`).
      See [FAQ](#faq) for details.
1. **Dart standalone programs**:
    * Install the packages `pub get`
    * Install [objectbox-c](https://github.com/objectbox/objectbox-c) system-wide:
       * macOS/Linux: execute the following command (answer Y when it asks about installing to /usr/lib) 
            ```shell script
            bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh)
            ```
       * macOS: if dart later complains that it cannot find the `libobjectbox.dylib` you probably have to unsign the 
         `dart` binary (source: [dart issue](https://github.com/dart-lang/sdk/issues/38314#issuecomment-534102841)):
            ```shell script
            sudo codesign --remove-signature $(which dart)
            ```
       * Windows: use "Git Bash" or similar to execute the following command 
            ```shell script
            bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh)
            ```
            Then copy the downloaded `lib/objectbox.dll` to `C:\Windows\System32\` (requires admin privileges).

ObjectBox generates code binding code for classes you want stored based using build_runner.
After you've defined your persisted entities (see below), run `pub run build_runner build` or `flutter pub run build_runner build`.

Getting started
----------------
In general, Dart class annotations are used to mark classes as ObjectBox entities and provide meta information.
Entity IDs and UIDs that are defined in their respective annotations need to be unique across all entities, while 
property IDs only need to be unique in their respective entity; property UIDs also need to be globally unique.

Each entity is required to have an ID property of type `int`.
Already persisted entities have an ID greater or equal to 1.
New (not yet persisted) objects typically have ID value of `0` or `null`: calling `Box.put` automatically assigns a new ID to the object.

### Example
For a code example, see [example/README.md](example/README.md)

### Box
Box is your main interface for storing and retrieving data.
```dart
var box = Box<Note>(store);
    
var note = Note(text: "Hello");
note.id = box.put(note);
print("new note got id ${note.id}");
print("refetched note: ${box.get(note.id)}");
```

### Query and QueryBuilder
Basic querying can be done with e.g.:

```dart
// var store ...
// var box ...

box.putMany([Note(), Note(), Note()]);
box.put(Note.construct("Hello world!"));

final queryNullText = box.query(Note_.text.isNull()).build();

assert(queryNullText.count() == 3);

queryNullText.close(); // We have to manually close queries and query builders.
```

More complex queries can be constructed using `and/or` operators.
Also there is basic operator overloading support for `greater`, `less`, `and` and `or`,
respectively `>`, `<`, `&`, `|`.

```dart
// final box ...

box.query(value.greaterThan(10).or(date.isNull())).build();

// equivalent to

final overloaded = (value > 10) | date.isNull();
box.query(overloaded as Condition).build(); // the cast is necessary due to the type analyzer
```

### Ordering
The results from a query can be ordered using the `order` method, e.g.

```dart
final q = box.query(Entity_.number > 0)
  .order(Type_.number)
  .build();

// ...

final qt = box.query(Entity_.text.notNull())
  .order(Entity_.text, flags: Order.descending | Order.caseSensitive)
  .build();
```

### Property Queries

Instead of returning complete entities, with property queries only values or an aggregate of a property can be returned.
Build a regular query with conditions as seen above, then turn it into a property query, e.g.:

```dart
// final query ...
                            
// Use distinct or caseSensitive to refine results.
final textQuery = query.stringProperty(Note_.text)
    ..distinct = true
    ..caseSensitive = true;
final texts = textQuery.find();
textQuery.close();

// Get aggregates, like min, max, avg, sum and count.
final createdQuery = query.integerProperty(Note_.created);
final min = createdQuery.min();
createdQuery.close();

// Set replaceNullWith to map null values.
final scoreQuery = query.doubleProperty(Note_.score);
final scores = scoreQuery.find(replaceNullWith: 0.0);
scoreQuery.close();

query.close();
```

### Streams

Streams can be created from queries.
The streams can be extended with [rxdart](https://github.com/ReactiveX/rxdart);

```dart
    import "package:objectbox/src/observable.dart";

    // final store = ...
    final query = box.query(condition).build();
    final queryStream = query.stream;
    final sub1 = queryStream.listen((query) {
      print(query.count());
    });

    // box.put ...

    sub1.cancel();

    final stream = query.findStream(limit:5);
    final sub2 = stream.listen((list) {
      // ...
    });

    // clean up
    sub2.cancel();
    store.unsubscribe();

    store.close();
```

Help wanted
-----------
ObjectBox for Dart is still in an early stage with limited feature set (compared to other languages).
To bring all these features to Dart, we're asking the community to help out. PRs are more than welcome!
The ObjectBox team will try its best to guide you and answer questions. 

### Feedback
Also, please let us know your feedback by opening an issue:
for example, if you experience errors or if you have ideas for how to improve the API.
Thanks!

FAQ
---
**Q:** After adding ObjectBox, the size of the APK increased significantly. Why is that?<br>
**A:** Flutter compresses its native libraries (.so files) by default in the APK.
ObjectBox instructs the Android build to use uncompressed native libraries instead
(following the [official Android recommendations](https://developer.android.com/topic/performance/reduce-apk-size#extract-false)).
This setting affects the Flutter native libraries as well. Thus the now uncompressed Flutter libraries add to the APK size as well;
we've seen an additional 19 MB for the standard Flutter libraries.
_This is bad, right?_ Nope, actually uncompressed libraries use **less** storage space on device and have other advantages.
For details, please review the [official Android recommendations](https://developer.android.com/topic/performance/reduce-apk-size#extract-false)
and the [ObjectBox FAQ entry](https://docs.objectbox.io/faq#how-much-does-objectbox-add-to-my-apk-size) on this.
Both links also explain how to force compression using `android:extractNativeLibs="true"`.

**Q:** Flutter iOS builds for armv7 fail with "ObjectBox does not contain that architecture", does it not support 32-bit devices?
<br>
**A:** No, only 64-bit devices are supported. When ObjectBox was first released for iOS all the latest iOS devices had 64-bit support,
so we decided to not ship armv7 support. To resolve the build error, in your XCode project
look under Architectures and replace `${ARCHS_STANDARD)` with `arm64` (or `$ARCHS_STANDARD_64_BIT`). 

See also
---------
* [Changelog](CHANGELOG.md)
* [Contribution guidelines](CONTRIBUTING.md)

License
-------
    Copyright 2020 ObjectBox Ltd. All rights reserved.
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
        http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

