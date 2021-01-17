enum RelType {
  toMany,
  // toManyBacklink,
  // toOneBacklink,
}

class RelInfo {
  final RelType _type;

  // "source" object ID
  final int _objectId;

  // either propertyId or relationId
  final int _id;

  const RelInfo(this._type, this._id, this._objectId);

  int get id => _id;

  int get objectId => _objectId;

  RelType get type => _type;
}
