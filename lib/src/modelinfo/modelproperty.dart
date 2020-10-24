import 'package:objectbox/src/bindings/constants.dart';

import 'modelentity.dart';
import 'iduid.dart';

/// ModelProperty describes a single property of an entity, i.e. its id, name, type and flags.
class ModelProperty {
  IdUid id;
  String name;
  int type, flags;
  ModelEntity entity;
  String targetEntityName;
  IdUid relIndexId, relationId, targetEntityId;

  ModelProperty(this.id, this.name, this.type, this.flags, this.entity,
      {this.targetEntityName,
      this.relIndexId,
      this.relationId,
      this.targetEntityId}) {
    validate();
  }

  ModelProperty.fromMap(Map<String, dynamic> data, this.entity,
      {bool check = true}) {
    id = IdUid.fromString(data['id']);
    name = data['name'];
    type = data['type'];
    flags = data.containsKey('flags') ? data['flags'] : 0;

    // relations
    targetEntityName =
        data.containsKey('targetEntityName') ? data['targetEntityName'] : null;
    relIndexId = data.containsKey('relIndexId')
        ? IdUid.fromString(data['relIndexId'])
        : null;

    relationId = data.containsKey('relationId')
        ? IdUid.fromString(data['relationId'])
        : null;

    targetEntityId = data.containsKey('targetEntityId')
        ? IdUid.fromString(data['targetEntityId'])
        : null;

    if (check) validate();
  }

  void validate() {
    if (type == null || type < 0) {
      throw Exception('type must be defined and may not be < 0');
    }
    if (flags == null || flags < 0) {
      throw Exception('flags must be defined and may not be < 0');
    }
  }

  Map<String, dynamic> toMap() {
    final ret = <String, dynamic>{};
    ret['id'] = id.toString();
    ret['name'] = name;
    ret['type'] = type;
    if (targetEntityName != null) {
      ret['targetEntityName'] = targetEntityName;
    }
    if (relIndexId != null) {
      ret['relIndexId'] = relIndexId.toString();
    }
    if (targetEntityId != null) {
      ret['targetEntityId'] = targetEntityId.toString();
    }
    if (relationId != null) {
      ret['relationId'] = relationId.toString();
    }
    if (flags != 0) ret['flags'] = flags;
    return ret;
  }

  bool containsUid(int searched) {
    return id.uid == searched;
  }

  bool get isRelation => OBXPropertyType.Relation == type;
  bool get isOneToOne => isRelation && !targetEntityName.contains('<');
  bool get isManyToMany => isRelation && targetEntityName.contains('<');
  // bool get isIndexer => [
  //       OBXPropertyFlag.INDEXED,
  //       OBXPropertyFlag.UNIQUE,
  //       OBXPropertyFlag.INDEX_PARTIAL_SKIP_NULL,
  //       OBXPropertyFlag.INDEX_PARTIAL_SKIP_ZERO,
  //       OBXPropertyFlag.INDEX_HASH,
  //       OBXPropertyFlag.INDEX_HASH64
  //     ].any((i) => (i & flags) == i);
}
