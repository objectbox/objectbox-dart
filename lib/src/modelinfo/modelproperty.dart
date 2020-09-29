import 'modelentity.dart';
import 'iduid.dart';
import '../util.dart';

/// ModelProperty describes a single property of an entity, i.e. its id, name, type and flags.
class ModelProperty {
  IdUid id, indexId;
  String name;
  int type, flags;
  ModelEntity entity;

  ModelProperty(this.id, this.name, this.type, this.flags, this.entity) {
    validate();
  }

  ModelProperty.fromMap(Map<String, dynamic> data, this.entity,
      {bool check = true}) {
    id = IdUid.fromString(data['id']);
    name = data['name'];
    type = data['type'];
    flags = data.containsKey('flags') ? data['flags'] : 0;
    if (flags.isIndexer) {
      indexId = IdUid.fromString(data['indexId']);
    }
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
    if (flags != 0) ret['flags'] = flags;
    if (flags.isIndexer) {
      ret['indexId'] = indexId.toString();
    }
    return ret;
  }

  bool containsUid(int searched) {
    return id.uid == searched;
  }
}
