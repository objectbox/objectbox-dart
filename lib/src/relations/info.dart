import 'to_one.dart';

enum RelType {
  toMany,
  // toManyBacklink,
  toOneBacklink,
}

class RelInfo<SourceEntityT> {
  final RelType _type;

  /// source object ID (or target for backlinks)
  final int _objectId;

  /// either propertyId or relationId
  final int _id;

  // only for backlinks:
  final ToOne Function(SourceEntityT) /*?*/ _getToOneSourceField;

  const RelInfo._(
      this._type, this._id, this._objectId, this._getToOneSourceField);

  const RelInfo.toMany(int id, int objectId)
      : this._(RelType.toMany, id, objectId, null);

  const RelInfo.toOneBacklink(
      int id, int objectId, ToOne Function(SourceEntityT) srcFieldAccessor)
      : this._(RelType.toOneBacklink, id, objectId, srcFieldAccessor);

  int get id => _id;

  int get objectId => _objectId;

  RelType get type => _type;

  ToOne toOneSourceField(SourceEntityT object) => _getToOneSourceField(object);
}
