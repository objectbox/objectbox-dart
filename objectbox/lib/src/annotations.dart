class Entity {
  final int uid;
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
  final int uid, type, flag;
  const Property({this.type, this.flag, this.uid});
}

class Id {
  final int uid;
  const Id({this.uid});
}
