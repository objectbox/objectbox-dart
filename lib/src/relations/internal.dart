import 'package:meta/meta.dart';

@internal
enum RelType {
  toMany,
  // toManyBacklink,
  // toOneBacklink,
}

@internal
class RelInfo {
  final RelType type;

  // "source" object ID
  final int objectId;

  // either propertyId or relationId
  final int id;

  RelInfo(this.objectId, this.id, this.type);
}
