ObjectBox for Dart/Flutter
==========================
ObjectBox for Dart is a standalone database storing Dart objects locally, with strong ACID semantics.

Help wanted
-----------
ObjectBox for Dart is still in a prototype stage supporting only the most basic database tasks, like putting and getting objects.
However, the ObjectBox core supports many more features, e.g. queries, indexing, async operations, transaction control.
To bring all these features to Dart, we're asking the community to help out. PRs are more than welcome!
The ObjectBox team will try its best to guide you and answer questions. 

Also, please let us know your feedback by opening an issue:
for example, if you experience errors or if you have ideas for how to improve the API.
Thanks!

Getting started
---------------
To try out the demo code in this repository, follow these:

1. Install [objectbox-c](https://github.com/objectbox/objectbox-c) system-wide: `bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-c/master/download.sh)` (answer Y when it asks about installing to /usr/lib).
2. Back in this repository, run `pub get` to download all Dart dependencies.
3. Finally run `dart test/test.dart` to start the demo script.
   Note that, as fairly recent language features are used, the minimal required Dart version is 2.2.2.

Dart integration
----------------
In general, Dart class annotations are used to mark classes as ObjectBox entities and provide meta information.
Note that right now, only a limited set of types is supported; this will be expanded upon in the near future.
Entity IDs and UIDs that are defined in their respective annotations need to be unique across all entities, while property IDs only need to be unique in their respective entity; property UIDs also need to be globally unique.

All non-annotated class instance variables are ignored by ObjectBox.

### Object IDs

Each entity is required to have an _Id_ property of type _Long_.
Already persisted entities have an ID greater or equal to 1.
New (not yet persisted) objects typically have _Id_ value of `0` or `null`: calling `Box.put` automatically assigns a new ID to the object.

### Example

```dart
import "../lib/objectbox.dart";

@Entity(id: 1, uid: 1)
class Note {
    @Id(id: 1, uid: 1001, type: Type.Long)
    int id;

    @Property(id: 2, uid: 1002)
    String text;

    Note();             // empty default constructor needed
    Note.construct(this.text);

    toString() => "Note{id: $id, text: $text}";
}
```

In your main function, you can then create a _store_ which needs an array of your entity classes to be constructed.
Finally, you need a _box_, representing the interface for objects of one specific entity type.

```dart
var store = Store([Note]);
var box = Box<Note>(store);

var note = Note("Hello");
box.put(note);
print("new note got id ${note.id}");
print("refetched note: ${box.getById(note.id)}");

store.close();
```

Basic technical approach
------------------------
ObjectBox offers a [C API](https://github.com/objectbox/objectbox-c) which can be called by [Dart FFI](https://dart.dev/server/c-interop).
The C API is is also used by the ObjectBox language bindings for [Go](https://github.com/objectbox/objectbox-go), [Swift](https://github.com/objectbox/objectbox-swift), and [Python](https://github.com/objectbox/objectbox-python).
These language bindings currently serve as an example for this Dart implementation.

Internally, ObjectBox uses [FlatBuffers](https://google.github.io/flatbuffers/) to store objects.
There are two basic ways to make the conversion: generated binding code, or implicit FlatBuffers conversion.
In order to require as little setup as possible and to define entity classes directly in Dart code, the latter is used in this binding.
