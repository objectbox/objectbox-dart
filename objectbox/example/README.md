ObjectBox Examples
==========================

If you want to dive straight into the code:

* see a [Flutter example app](flutter/objectbox_demo_relations)

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
  int id = 0;

  String? text;

  @Property(type: PropertyType.date) // Store as int in milliseconds
  DateTime date;

  @Transient() // Make this field ignored, not stored in the database.
  int? notPersisted;

  // An empty default constructor is needed but you can use optional args.
  Note({this.text, DateTime? date}) : date = date ?? DateTime.now();

  // Note: just for logs in the examples below(), not needed by ObjectBox.
  toString() => 'Note{id: $id, text: $text}';
}
```

To generate ObjectBox binding code for your entities run
- for Flutter apps `flutter pub run build_runner build` or
- for Dart CLI apps `dart run build_runner build`.

ObjectBox generator will look for all `@Entity` annotations in your `lib` folder and create
- a single database definition `lib/objectbox-model.json` and
- supporting code in `lib/objectbox.g.dart`.

You should commit `objectbox-model.json` into your source control (e.g. git) and add `objectbox.g.dart` to the ignore
list (e.g. .gitignore), otherwise the build_runner will complain about it being changed each time you pull a change.

> The generator will process `lib` and `test` folders separately and create a separate database in each one, if it finds
> annotations there. This is useful if you need a separate test DB. If you're just writing tests for your own code, you
> won't have any annotations in the `test` folder so no DB will be created there.

To customize the directory (relative to the package root) where the generated files are written,
add the following to your `pubspec.yaml`:
```
objectbox:
  # Writes objectbox-model.json and objectbox.g.dart to lib/custom (and test/custom).
  output_dir: custom
  # Or optionally specify the lib and test output folder separately.
  # output_dir:
  #   lib: custom
  #   test: other
```

Creating a store
----------------

`Store` is your entrypoint to ObjectBox - see below how to open it, based on the SDK you're using.

### Flutter apps

For example, open the `Store` in a small helper class like this:

```dart
import 'objectbox.g.dart'; // created by `flutter pub run build_runner build`

class ObjectBox {
  /// The Store of this app.
  late final Store store;
  
  ObjectBox._create(this.store) {
    // Add any additional setup code, e.g. build queries.
  }

  /// Create an instance of ObjectBox to use throughout the app.
  static Future<ObjectBox> create() async {
    // Future<Store> openStore() {...} is defined in the generated objectbox.g.dart
    final store = await openStore();
    return ObjectBox._create(store);
  }
}
```

The best time to create the ObjectBox class is when your app starts. 
We suggest to do it in your app's `main()` function:

```dart
/// Provides access to the ObjectBox Store throughout the app.
late ObjectBox objectbox;

Future<void> main() async {
  // This is required so ObjectBox can get the application directory
  // to store the database in.
  WidgetsFlutterBinding.ensureInitialized();

  objectbox = await ObjectBox.create();

  runApp(MyApp());
}
```

Then the `Store` remains open throughout the lifetime of the app. 
This is typically fine and recommended for most use cases.

### Dart CLI apps

In standard apps (not on mobile), ObjectBox can write anywhere the current user can. The following minimal example
omits the argument to `Store(directory: )`, thus using the default - 'objectbox' in the current working directory.

```dart
import 'objectbox.g.dart'; // created by `dart pub run build_runner build`

void main() {
  // Store openStore() {...} is defined in the generated objectbox.g.dart
  final store = openStore();

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
final box = store.box<Note>();

final note = Note(text: 'Hello'); // note: note.id is null
final id = box.put(note);         // note: sets note.id and also returns it
print('new note got id=${id}, which is the same as note.id=${note.id}');
print('re-read note: ${box.get(id)}');
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

The results from a query can be ordered using the `order` method:

```dart
final builder = box.query(Note_.date > 0).order(Note_.date);
final query = builder.build();

// ...

final builder = box.query(Note_.text.notNull())
  ..order(Note_.text, flags: Order.descending | Order.caseSensitive)
  ..order(Note_.date);
final query = builder.build();
```

### Property Queries

Use "Property Queries" If you're interested only in a single property from an Entity.
You can access a list of property values across matching objects, or an aggregation.

```dart
final query = box.query(Note_.date > 0).build();

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

### Reactive queries

You can create a reactive query to get notified any time queried entity types change.

```dart
Stream<Query<Note>> watchedQuery = box.query(condition).watch();
final sub1 = watchedQuery.listen((Query<Note> query) {
  // This gets triggered any there are changes to the queried entity types.
  // You can call any query method here, for example:
  print(query.count());
  print(query.find());
});
...
sub1.cancel(); // cancel the subscription after you're done
```

Similarly to the previous example but with an initial event immediately after you start listening:
```dart
Stream<Query<Note>> watchedQuery = box.query(condition).watch();
final sub1 = watchedQuery.listen((Query<Note> query) {
  // This gets triggered once right away and then after queried entity types changes.
});
...
sub1.cancel(); // cancel the subscription after you're done
```

> Note: Dart Streams can be extended with [rxdart](https://github.com/ReactiveX/rxdart).

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
  int id = 0;
  String? name;
}

@Entity()
class Order {
  int id = 0;

  final customer = ToOne<Customer>();
  final items = ToMany<Item>();
}

@Entity()
class Item {
  int id = 0;
}
```

Now, let’s say a new customer has just confirmed an order through the UI. We need to create the `Customer` and the
`Order` in the database, attaching a list of purchased items. We assume those items are already stored in the DB,
customer must have selected them somehow, right?

```dart
List<Item> purchasedItems = [...]; // loaded from the shopping basket

// create a new order with a new customer
final order = Order();
order.customer.target = Customer()..name = 'Jane Smith'; // add a new Customer object
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
  int id = 0;
  String? name;
  
  @Backlink()
  final orders = ToMany<Order>();
}

@Entity()
class Order {
  int id = 0;
  bool paid = false;

  final customer = ToOne<Customer>();
  final items = ToMany<Item>();
}

@Entity()
class Item {
  int id = 0;
}
```

To query a backlink relation, use `backlink` and reference the `ToOne` it is based on:
```dart
QueryBuilder<Customer> builder = 
    customerBox.query(Customer_.name.equals('Jane Smith'));
builder.backlink(Order_.customer, Order_.paid.equals(true));
```

Note: if you change the `customer.orders` list, you're actually changing `order.customer.targetId` on each target.

### Backlink to a ToMany relation

Similarly to "backlinking" a `ToOne` relation, you can add a backlink against another `ToMany` relation, creating a view
of its data for an easy access from the target object. Again, let's update the previous example schema, adding a
such a backlink to `Item`, so that we can access all `Order`s where this `Item` was sold.


```dart
@Entity()
class Customer {
  int id = 0;
  String? name;
}

@Entity()
class Order {
  int id = 0;

  final customer = ToOne<Customer>();
  final items = ToMany<Item>();
}

@Entity()
class Item {
  int id = 0;
  String? category;
  
  @Backlink()
  final orders = ToMany<Order>();
}
```

To query a backlink relation, use `backlinkMany` and reference the `ToMany` it is based on:
```dart
QueryBuilder<Item> builder = 
    itemBox.query(Item_.category.equal('common'));
builder.backlinkMany(Order_.items, Order_.id.equals(42));
```

