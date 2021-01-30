/// Entity annotation is used to on a class to let ObjectBox know it should
/// store it - making the class a "persistable Entity".
///
/// This annotation is matched by ObjectBox code generator when you call
/// `pub run_build_runner build`. The generator creates `objectbox.g.dart` with
/// all the binding code necessary to store the class in the database.
class Entity {
  /// ObjectBox keeps track of entities and properties by assigning them unique
  /// identifiers, UIDs, during the code-generation phase. All those UIDs are
  /// stored in a file objectbox-model.json in your package and are looked up by
  /// name. If the name changes a new uid is assigned, effectively creating a
  /// new Entity in the database.
  ///
  /// If you explicitly specify a [uid] on an [Entity], ObjectBox would be able
  /// to identify it even after you change the name and would update the
  /// database accordingly on the next application launch - renaming the stored
  /// Entity instead of creating a new one.
  final int /*?*/ uid;

  /// Create an Entity annotation.
  const Entity({this.uid});
}

/// Property annotation enables you to explicitly specify configure some details
/// about how a field is stored in the database.
///
/// Use PropertyType and OBXPropertyFlag values, resp. for type and flag.
class Property {
  /// ObjectBox keeps track of entities and properties by assigning them unique
  /// identifiers, UIDs, during the code-generation phase. All those UIDs are
  /// stored in a file objectbox-model.json in your package and are looked up by
  /// name. If the name changes a new uid is assigned, effectively creating a
  /// new field in the database.
  ///
  /// If you explicitly specify a [uid] on a [Property], ObjectBox would be able
  /// to identify it even after you change the name and would update the
  /// database accordingly on the next application launch - renaming the stored
  /// Property instead of creating a new one.
  final int /*?*/ uid;

  /// Override dart type with an alternative ObjectBox property type.
  ///
  /// A dart int value can map to different [PropertyType]s,
  /// e.g. Short (Int16), Int (Int32), Long (Int64), all signed values.
  /// Also a dart double can also map to e.g. Float and Double
  ///
  /// The defaults are e.g. Int -> Int64, double -> Float64, bool -> Bool.
  final PropertyType /*?*/ type;

  /// Create an Property annotation.
  const Property({this.type, this.uid});
}

/// Specify ObjectBox property storage type explicitly.
enum PropertyType {
  // dart type=bool, size: 1-byte/8-bits
  // no need to specify explicitly, just use `bool`
  // bool,

  /// size: 1-byte/8-bits
  byte,

  /// size: 2-bytes/16-bits
  short,

  /// size: 1-byte/8-bits
  char,

  /// size: 4-bytes/32-bits
  int,

  // dart type=int, size: 8-bytes/64-bits
  // no need to specify explicitly, just use `int`
  // long,

  /// size: 4-bytes/32-bits
  float,

  // dart type=double, size: 8-bytes/64-bits
  // no need to specify explicitly, just use `double`
  // double,

  // dart type=String
  // no need to specify explicitly, just use `String`
  // string,

  // Relation, currently not supported
  // relation,

  /// Unix timestamp (milliseconds since 1970), size: 8-bytes/64-bits
  date,

  /// Unix timestamp (nanoseconds since 1970), size: 8-bytes/64-bits
  dateNano,

  /// dart type=Uint8List - automatic, no need to specify explicitly
  /// dart type=Int8List  - automatic, no need to specify explicitly
  /// dart type=List<int> - specify the type explicitly using @Property(type:)
  ///                     - values are truncated to 8-bit int (0..255)
  byteVector,

  // dart type=List<String>
  // no need to specify explicitly, just use `List<String> `
  // stringVector
}

/// Annotation Id can be used to specify an entity ID property if it's named
/// anything else then "id" (case insensitive).
class Id {
  /// Create an Id annotation.
  const Id();
}

/// Transient annotation marks properties that should not be stored in the DB.
class Transient {
  /// Create a Transient annotation.
  const Transient();
}

// See Sync() in sync.dart.
// Defining a class with the same name here would cause a duplicate export.
// class Sync {
//   const Sync();
// }

/// Specifies that the property should be indexed.
///
/// It is highly recommended to index properties that are used in a Query to
/// improve query performance. To fine tune indexing of a property you can
/// override the default index type.
///
/// Note: indexes are currently not supported for ByteVector, Float or Double
/// properties.
class Index {
  /// Index type.
  final IndexType /*?*/ type;

  /// Create an Index annotaion.
  const Index({this.type});
}

/// IndexType can be used to change what type ObjectBox uses when indexing a
/// property.
///
/// Limits of [hash]/[hash64] indexes: Hashes work great for equality checks,
/// but not for "starts with" conditions. If you frequently use those, consider
/// [value] indexes instead for [String] properties.
enum IndexType {
  /// Uses property values to build the index. This is a default for scalar
  /// properties.
  ///
  /// If used for a [String] property, this may require more storage space than
  /// it's default, [hash].
  value,

  /// Uses a 32-bit hash of the field value to build the index. This is a
  /// default for [String] properties.
  ///
  /// Hash collisions should be sporadic and shouldn't impact performance in
  /// practice. Because it requires less storage space, it's usually a better
  /// choice than  [hash64].
  hash,

  /// Uses a long hash of the field value to build the index. Uses more storage
  /// space than [hash], thus should be used with consideration.
  hash64,
}

/// Unique annotation forces that the value of a property is unique among all
/// objects stored for the given entity.
///
/// Trying to put an Object with offending values will result in an exception.
///
/// Unique properties are based on an [Index], so the same restrictions apply.
/// It is supported to explicitly add the [Index] annotation to configure the
/// index type.
class Unique {
  /// Create a Unique annotation.
  const Unique();
}

/// Backlink annotation specifies a link in a reverse direction of another
/// relation.
///
/// This works as an "updatable view" of the original relation, and doesn't
/// cause any more data to be stored in the database. Changes made to the
/// backlink relation are reflected in the original direction.
///
/// Example - backlink based on a [ToOne] relation:
/// ```dart
/// class Order {
///   final customer = ToOne<Customer>();
/// }
/// class Customer {
///   @Backlink()
///   final orders = ToMany<Customer>();
/// }
/// ```
///
/// Example - backlink based on a [ToMany] relation:
/// ```dart
/// class Student {
///   final teachers = ToMany<Teacher>();
/// }
/// class Teacher {
///   @Backlink()
///   final students = ToMany<Student>();
/// }
/// ```
class Backlink {
  /// Target entity to which this backlink points. It's the entity that contains
  /// a [ToOne] or [ToMany] relation pointing to the current entity.
  final String to;

  /// If there are multiple relations pointing to the current entity, specify
  /// the field name of the desired source relation: Backlink('sourceField').
  const Backlink([this.to = '']);
}
