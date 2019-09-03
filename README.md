# ObjectBox for Dart/Flutter
ObjectBox for Dart is a standalone database storing Dart objects locally with strong ACID semantics.

## Help wanted
ObjectBox for Dart is still in a prototype stage supporting only the most basic database tasks like putting and getting objects.
The ObjectBox core however supports many more features, e.g. queries, indexing, async operations, transaction control.
To bring all these features to Dart, we're asking the community to help out. PRs are more than welcome!
The ObjectBox team will try its best to guide you and answer questions. 

Also, please let us know your feedback and open an issue: for example, if you experience errors or if you have ideas to how to improve the API.
Thanks!

## Getting started
To try out the demo code in this repository, do the following:
1. Install [objectbox-c](https://github.com/objectbox/objectbox-c) system-wide: `bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-c/master/download.sh)` (answer Y when it asks about installing to /usr/lib).
2. Back in this repository, run `pub get` to download all Dart dependencies.
3. Finally run `dart test/test.dart` to start the demo script.
   Note that, as fairly recent language features are used, the minimal required Dart version is 2.2.2.

## Dart integration
In general, Dart class annotations are used in order to design ObjectBox entities in the most intuitive way possible.
Note that right now, only a limited set of types is supported; this will be expanded upon in the near future.
Entity IDs and UIDs defined in their respective annotations need to be unique across all entities, while property IDs only need to be unique in their respective entity; property UIDs also need to be globally unique.
Additionally, each entity needs its own _Id_ property of type _Long_; its value always needs to be >= 1. If, when given to `Box.put`, the _Id_ property of an entity instance is `0` or `null`, it will be automatically filled with a new ID automatically assigned by ObjectBox.
All non-annotated class instance variables are ignored by ObjectBox.

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
Finally, you need a _box_, i.e. an interface to objects of one specific entity type contained in the store it is connected to.

```dart
var store = Store([Note]);
var box = Box<Note>(store);

var note = Note("Hello");
box.put(note);
print("new note got id ${note.id}");
print("refetched note: ${box.getById(note.id)}");

store.close();
```

## Basic technical approach
ObjectBox offers a [C API](https://github.com/objectbox/objectbox-c) which can be called by [Dart FFI](https://dart.dev/server/c-interop).
The C API is is also used by [ObjectBox Go](https://github.com/objectbox/objectbox-go) and the minimal [Python binding](https://github.com/objectbox/objectbox-python) (the [Swift binding](https://github.com/objectbox/objectbox-swift) will soon follow).
These language bindings currently serve as an example for this Dart implementation.

Internally, ObjectBox uses [FlatBuffers](https://google.github.io/flatbuffers/) to store objects.
There are two basic ways make the conversion: generated binding code or implicit FlatBuffers conversion.
In order to require as little setup as possible and to define entity classes directly in Dart code, the latter is used in this binding.
