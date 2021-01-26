ObjectBox Examples
==========================

If you want to dive straight into the code:

* see a [Flutter example app](flutter/objectbox_demo)

Data model
--------------------

In the following file, e.g. `models.dart`, we import ObjectBox to access annotations.
Then, we define a single "Entity" that should be persisted by ObjectBox. You can have multiple
entities in the same file, or you can have them spread across multiple files in your package's `lib` directory.

```dart
import 'package:objectbox/objectbox.dart';

@Entity()
class Note {
    // Each "Entity" needs a unique integer ID property.
    // Add `@Id()` annotation if its name isn't "id" (case insensitive).
    int id;

    String text;

    int date;

    @Transient() // Make this field ignored, not stored in the database.
    int notPersisted;

    // An empty default constructor is needed but you can use optional args.
    Note({this.text});

    // Note: just for logs in the examples below(), not needed by ObjectBox.
    toString() => 'Note{id: $id, text: $text}';
}
```

To generate ObjectBox binding code for your entities, run `pub run build_runner build`.
ObjectBox generator will look for all `@Entity` annotations in your `lib` folder and create a single database definition
`lib/objectbox-model.json` and supporting code in `lib/objectbox.g.dart`.
You should commit `objectbox-model.json` into your source control (e.g. git) and add `objectbox.g.dart` to the ignore
list (e.g. .gitignore), otherwise the build_runner will complain about it being changed each time you pull a change.

> The generator will process `lib` and `test` folders separately and create a separate database in each one, if it finds
> annotations there. This is useful if you need a separate test DB. If you're just writing tests for your own code, you
> won't have any annotations in the `test` folder so no DB will be created there.

Creating a store
----------------

`Store` is your entrypoint to ObjectBox - see below how to open it, based on the SDK you're using.

### Flutter apps

On mobile devices, you should store data in your app documents directory - it stays there even when you close the app.

Use `getApplicationDocumentsDirectory()` from the `path_provider` package to retrieve this directory.

```dart
import 'package:path_provider/path_provider.dart';

import 'objectbox.g.dart'; // created by `flutter pub run build_runner build`

class _MyHomePageState extends State<MyHomePage> {
  Store _store;

  @override
  void initState() {
    super.initState();

    getApplicationDocumentsDirectory().then((Directory dir) {
      // Note: getObjectBoxModel() is generated for you in objectbox.g.dart
      _store = Store(getObjectBoxModel(), directory: dir.path + '/objectbox');
    });
  }

  @override
  void dispose() {
    _store?.close();  // don't forget to close the store
    super.dispose();
  }
}
```

See [Flutter: read & write files](https://flutter.dev/docs/cookbook/persistence/reading-writing-files) for more info.
If you didn't specify this path to ObjectBox, it would try to use a default directory "objectbox" in the current working
directory, but it doesn't have permissions to write there: `failed to create store: 10199 Dir does not exist: objectbox (30)`.

### Dart CLI apps

In standard apps (not on mobile), ObjectBox can write anywhere the current user can. The following minimal example
omits the argument to `Store(directory: )`, thus using the default - 'objectbox' in the current working directory.

```dart
import 'objectbox.g.dart'; // created by `dart pub run build_runner build`

void main() {
  var store = Store(getObjectBoxModel()); // Note: getObjectBoxModel() is generated for you in objectbox.g.dart

  // your app code ...

  store.close(); // don't forget to close the store
}
```

Box
---------------

`Box<Entity>` is your main interface for storing and retrieving data.
Objects are stored using `box.put()` which checks the ID and:

* assigns a new object a unique non-zero ID - new objects are those that have a zero or `null` ID,
* or if the object already has an ID, overwrites an object with that ID.

```dart
import 'objectbox.g.dart';

final box = store.box<Note>();

final note = Note(text: 'Hello'); // note: node.id is null
final id = box.put(note);         // note: sets note.id and also returns it
print('new note got id=${id}, which is the same as note.id=${note.id}');
print('refetched note: ${box.get(id)}');
```

Queries
---------------

The generated `objectbox.g.dart` contains a "meta-information" class for your entity, called `Note_` in our example.
This class contains all fields in your entity, with the information necessary to create queries in a type-safe manner.

```dart
box.putMany([Note(), Note(), Note(), Note(text: 'Hello world!')]);

final queryNullText = box.query(Note_.text.isNull()).build();

assert(queryNullText.count() == 3);             // executes the query, returns int
final notesWithNullText = queryNullText.find(); // executes the query, returns List<Note>

queryNullText.close(); // close the query to free resources
```

More complex queries can be constructed using `and/or` operators.
Also there is basic operator overloading support for `greaterThan`, `lessThan`, `and` and `or`,
respectively `>`, `<`, `&`, `|`.

```dart
box.query(Note_.text.isNull().or(Note_.date.greaterThan())).build();

// equivalent to

box.query(Note_.text.isNull() | Note_.date > 0).build();
```

### Ordering query results

The results from a query can be ordered using the `order` method, e.g.

```dart
final q = box.query(Note_.date > 0)
  .order(Note_.date)
  .build();

// ...

final qt = box.query(Note_.text.notNull())
  .order(Note_.text, flags: Order.descending | Order.caseSensitive)
  .build();
```

### Property Queries

Use "Property Queries" If you're interested only in a single property from an Entity.
You can access a list of property values across matching objects, or an aggregation.

```dart
final query = box.query(Note_.date > 0).build()

// Use distinct or caseSensitive to refine results.
final textQuery = query.stringProperty(Note_.text)
    ..distinct = true
    ..caseSensitive = true;
final texts = textQuery.find();
textQuery.close();

// Get aggregates, like min, max, avg, sum and count.
final dateQuery = query.integerProperty(Note_.date);
final min = dateQuery.min();
dateQuery.close();

// You can also change how stored `null` values are handled, use [replaceNullWith].
final dateQuery = query.integerProperty(Note_.score);
final dates = scoreQuery.find(replaceNullWith: 0);
dateQuery.close();

query.close();
```

### Query streams

Streams can be created from queries.
Note: Dart Streams can be extended with [rxdart](https://github.com/ReactiveX/rxdart).

```dart
final query = box.query(condition).build();
final queryStream = query.stream;
final sub1 = queryStream.listen((query) {
  print(query.count());
});

// box.put() creates some data ...

sub1.cancel();

final stream = query.findStream(limit:5);
final sub2 = stream.listen((list) {
  // ...
});

// clean up
sub2.cancel();
```

Relations
---------

Objects may reference other objects, for example using a simple reference or a list of objects. In database terms, we
call those references relations. The object defining the relation we call the source object, the referenced object we
call target object. So the relation has a direction.

If there is one target object, we call the relation to-one. And if there can be multiple target objects, we call it
to-many. Relations are lazily initialized: the actual target objects are fetched from the database when they are first
accessed. Once the target objects are fetched, they are cached for further accesses.

You define a to-one relation using the `ToOne` class, a smart proxy to the target object. It gets and caches the target
object transparently. For example, an order is typically made by one customer. Thus, we could model the `Order` class to
have a to-one relation to the `Customer`.

Similarly, you can define a to-many relation using the `ToMany` class, which you can use as an ordinary list in your
code and it takes care of loading/storing the relational data for you.

Have a look at the following example how a shop database could look like.

```dart
@Entity()
class Customer {
  int id;
  String name;
}

@Entity()
class Order {
  int id;

  final customer = ToOne<Customer>();
  final items = ToMany<Item>();
}

@Entity()
class Item {
  int id;
}
```

Now, let’s say a new customer has just confirmed an order through the UI. We need to create the `Customer` and the
`Order` in the database, attaching a list of purchased items. We assume those items are already stored in the DB,
customer must heve selected them somehow, right?

```dart
List<Item> purchasedItems = [...]; // loaded from the shopping basket

// create a new order with a new customer
final order = Order();
order.customer.target = Customer()..name="John Doe"; // add a new Customer object
order.items.addAll(purchasedItems); // add a list of existing items

// create the order and the customer in the database with a single call
store.box<Order>().put(order);
```

### Backlink to a ToOne relation 

For every `ToOne` relation that you have, you can define a backlink. Backlinks are using the same relation information, 
but in the reverse direction. Thus, a backlink of a `ToOne` will result in a list of potentially multiple objects: all 
objects pointing to the same target.

Example: Two `Order` objects point to the same `Customer` using a `ToOne`. The backlink is a `ToMany` from the 
`Customer` referencing its two `Order` objects. The updated schema from the previous example could look like this:

```dart
@Entity()
class Customer {
  int id;
  String name;
  
  @Backlink()
  final orders = ToMany<Order>();
}

@Entity()
class Order {
  int id;

  final customer = ToOne<Customer>();
  final items = ToMany<Item>();
}

@Entity()
class Item {
  int id;
}
```

Note: if you change the `customer.orders` list, you're actually changing `order.customer.targetId` on each target.

### Backlink to a ToMany relation

Similarly to "backlinking" a `ToOne` relation, you can add a backlink against another `ToMany` relation, creating a view
of its data for an easy access from the target object. Again, let's update the previous example schema, adding a
such a backlink to `Item`, so that we can access all `Order`s where this `Item` was sold.


```dart
@Entity()
class Customer {
  int id;
  String name;
}

@Entity()
class Order {
  int id;

  final customer = ToOne<Customer>();
  final items = ToMany<Item>();
}

@Entity()
class Item {
  int id;
  
  @Backlink()
  final orders = ToMany<Order>();
}
```
