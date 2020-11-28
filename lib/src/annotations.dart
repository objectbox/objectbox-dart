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
  final int /*?*/ uid, type, flag;

  const Property({this.type, this.flag, this.uid});
}

class Id {
  final int /*?*/ uid;

  const Id({this.uid});
}

class Transient {
  const Transient();
}

/// See Sync() in sync.dart.
/// Defining a class with the same name here would cause a duplicate export.
// class Sync {
//   const Sync();
// }

// TODO It's possible to pass the unique and index flags directly through Property,
// was it even intended to have a separate annotation for these?

/// Specifies that the property should be indexed.
///
/// It is highly recommended to index properties that are used in a Query to
/// improve query performance. To fine tune indexing of a property you can
/// override the default index type.
///
/// Note: indexes are currently not supported for ByteVector, Float or Double
/// properties.
class Index {
  final int flag;
  const Index({this.flag});
}

/// Enforces that the value of a property is unique among all Objects in a Box
/// before an Object can be put.
///
/// Trying to put an Object with offending values will result in an exception.
///
/// Unique properties are based on an [Index], so the same restrictions apply.
/// It is supported to explicitly add the [Index] annotation to configure the
/// index.
class Unique {
  const Unique();
}
