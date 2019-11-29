ObjectBox for Dart/Flutter
==========================
ObjectBox for Dart is a standalone database storing Dart objects locally, with strong ACID semantics.

Flutter/Dart compatibility
--------------------------
This library depends on a new Dart feature, FFI, introduced in Dart 2.5 (Flutter 1.9) as a feature preview. 
However, it has been change significantly significantly in Dart 2.6 (future Flutter 1.10.x), i.e. introduced breaking changes we had to reflect.
Versions starting with ObjectBox 0.5 support Dart 2.6 as well as Flutter 1.10 (when it's finally released).

The last supported version for Flutter 1.9/Dart 2.5 is ObjectBox 0.4.*, so if you can't upgrade yet, please use latest 0.4.x version instead.
For Flutter users, this is the only option, as long as a new version of Flutter (1.10), including Dart 2.6 is released.

If you're developing standalone/non-flutter dart programs, you can already use Dart 2.6 with the latest ObjectBox version.

Installation
------------
Add the following dependencies to your `pubspec.yaml`:
```yaml
dependencies:
  objectbox: ^0.5.0

dev_dependencies:
  build_runner: ^1.0.0
  objectbox_generator: ^0.5.0
```

Proceed based on whether you're developing a Flutter app or a standalone dart program:
1. **Flutter** only steps:
    * Install the packages `flutter pub get`
    * Add `objectbox-android` dependency to your `android/app/build.gradle` 
        ```
        dependencies {
            implementation "io.objectbox:objectbox-android:2.4.1"
            ...
       ```
    * iOS coming soon
1. **Dart standalone programs**:
    * Install the packages `pub get`
    * Install [objectbox-c](https://github.com/objectbox/objectbox-c) system-wide:
       * macOS/Linux: execute the following command (answer Y when it asks about installing to /usr/lib) 
            ```shell script
            bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-c/master/download.sh) 0.7.2
            ```
       * macOS: if dart later complains that it cannot find the `libobjectbox.dylib` you probably have to unsign the 
         `dart` binary (source: [dart issue](https://github.com/dart-lang/sdk/issues/38314#issuecomment-534102841)):
            ```shell script
            sudo codesign --remove-signature $(which dart)
            ```
       * Windows: use "Git Bash" or similar to execute the following command 
            ```shell script
            bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-c/master/download.sh) 0.7.2
            ```
            Then copy the downloaded `lib/objectbox.dll` to `C:\Windows\System32\` (requires admin privileges).

ObjectBox generates code binding code for classes you want stored based using build_runner.
After you've defined your persisted entities (see below), run `pub run build_runner build` or `flutter pub run build_runner build`.

Getting started
----------------
In general, Dart class annotations are used to mark classes as ObjectBox entities and provide meta information.
Note that right now, only a limited set of types is supported; this will be expanded upon in the near future.
Entity IDs and UIDs that are defined in their respective annotations need to be unique across all entities, while 
property IDs only need to be unique in their respective entity; property UIDs also need to be globally unique.

### Object IDs

Each entity is required to have an _Id_ property of type _Long_.
Already persisted entities have an ID greater or equal to 1.
New (not yet persisted) objects typically have _Id_ value of `0` or `null`: calling `Box.put` automatically assigns a new ID to the object.

### Example

```dart
import "package:objectbox/objectbox.dart";

@Entity()
class Note {
    @Id()       // automatically always 'int' in Dart code and 'Long' in ObjectBox
    int id;

    String text;

    Note();             // empty default constructor needed
    Note.construct(this.text);
    toString() => "Note{id: $id, text: $text}";
}
```

In your main function, you can then create a _store_ which needs an array of your entity classes and definitions to be constructed. If you have several entities, construct your store like `Store([[Entity1, Entity1_OBXDefs], [Entity2, Entity2_OBXDefs]])` etc.
Finally, you need a _box_, representing the interface for objects of one specific entity type.

```dart
import 'objectbox.g.dart';

// ...

var store = Store(getObjectBoxModel());
var box = Box<Note>(store);

var note = Note.construct("Hello");
note.id = box.put(note);
print("new note got id ${note.id}");
print("refetched note: ${box.get(note.id)}");

store.close();
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

### Querying properties

The sum, average, minimum and maximum etc. can be calculated on a property of a query.
Calculating the minimum can be done like this, e.g.:

```dart
final tFloat = Entity_.tFloat;
final tDouble = Entity_.tDouble;
final query = box.query((tFloat > -0.01).or(tDouble > -0.01) as Condition).build();
final propMin = (qp) {
  final p = query.doubleProperty(qp);
  try {
    return p.min();
  }finally {
    p.close();
  }
};

final all = box.getAll();

final minFloat = all.map((s) => s.tFloat).toList().reduce(min);
final minDouble = all.map((s) => s.tDouble).toList().reduce(min);

assert(propMin(tFloat) == minFloat, "These are the same");
assert(propMin(tDouble) == minDouble, "These should also be the same");
```

Also the value of a property, present on all the instances of an entity can be returned
with `find`, or counted with `count`.


Help wanted
-----------
ObjectBox for Dart is still in an early stage with limited feature set (compared to other languages).
To bring all these features to Dart, we're asking the community to help out. PRs are more than welcome!
The ObjectBox team will try its best to guide you and answer questions. 

### Feedback
Also, please let us know your feedback by opening an issue:
for example, if you experience errors or if you have ideas for how to improve the API.
Thanks!

See also
---------
* [Changelog](CHANGELOG.md)
* [Contribution guidelines](CONTRIBUTING.md)

License
-------
    Copyright 2019 ObjectBox Ltd. All rights reserved.
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
        http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

