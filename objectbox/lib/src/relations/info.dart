import 'to_one.dart';

/// Specifies a type of a relation field.
enum RelType {
  /// Many-to-many relation.
  toMany,

  /// Many-to-many backlink.
  toManyBacklink,

  /// One-to-many backlink.
  toOneBacklink,
}

/// Holds relation information for a field.
class RelInfo<SourceEntityT> {
  final RelType _type;

  /// source object ID (or target for backlinks)
  final int _objectId;

  /// either propertyId or relationId
  final int _id;

  // only for backlinks:
  final ToOne Function(SourceEntityT)? _getToOneSourceField;

  const RelInfo._(
      this._type, this._id, this._objectId, this._getToOneSourceField);

  /// Create info for a [ToMany] relation field.
  const RelInfo.toMany(int id, int objectId)
      : this._(RelType.toMany, id, objectId, null);

  /// Create info for a [ToOne] relation field backlink.
  const RelInfo.toOneBacklink(
      int id, int objectId, ToOne Function(SourceEntityT) srcFieldAccessor)
      : this._(RelType.toOneBacklink, id, objectId, srcFieldAccessor);

  /// Create info for a [ToMany] relation field backlink.
  const RelInfo.toManyBacklink(int id, int objectId)
      : this._(RelType.toManyBacklink, id, objectId, null);

  /// Relation or property ID (latter if ToOne relation).
  int get id => _id;

  /// Source or target object ID (latter if backlink).
  int get objectId => _objectId;

  /// Relation type.
  RelType get type => _type;

  /// Source field associated with this toOne relation backlink.
  ToOne toOneSourceField(SourceEntityT object) => _getToOneSourceField!(object);
}
