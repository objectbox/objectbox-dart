class Entity {
  final int /*?*/ uid;

  const Entity({this.uid});
}

/// A dart int value can map to different OBXPropertyTypes,
/// e.g. Short (Int16), Int (Int32), Long (Int64), all signed values.
/// Also a dart double can also map to e.g. Float and Double
///
/// Property allows the mapping to be specific. The defaults are
/// e.g. Int -> Int64, double -> Float64, bool -> Bool.
///
/// Use OBXPropertyType and OBXPropertyFlag values, resp. for type and flag.
class Property {
  final int /*?*/ uid, flag;

  /// Override dart type with an alternative ObjectBox property type
  final PropertyType /*?*/ type;

  const Property({this.type, this.flag, this.uid});
}

// Specify ObjectBox property type explicitly
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

class Id {
  final int /*?*/ uid; // TODO remove, use `Property(uid:)`

  const Id({this.uid});
}

class Transient {
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
  final IndexType /*?*/ type;

  const Index({this.type});
}

enum IndexType {
  value,
  hash,
  hash64,
}

/// Enforces that the value of a property is unique among all Objects in a Box
/// before an Object can be put.
///
/// Trying to put an Object with offending values will result in an exception.
///
/// Unique properties are based on an [Index], so the same restrictions apply.
/// It is supported to explicitly add the [Index] annotation to configure the
/// index type.
class Unique {
  const Unique();
}
