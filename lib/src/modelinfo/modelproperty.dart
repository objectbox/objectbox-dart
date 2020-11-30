import '../bindings/bindings.dart';
import '../bindings/helpers.dart';
import 'modelentity.dart';
import 'iduid.dart';

/// ModelProperty describes a single property of an entity, i.e. its id, name, type and flags.
class ModelProperty {
  IdUid id;
  /*late*/ String _name;
  /*late*/ int _type, _flags;
  IdUid /*?*/ _indexId;
  ModelEntity /*?*/ entity;

  String get name => _name;

  set name(String /*?*/ value) {
    if (value == null || value.isEmpty) {
      throw Exception('name must not be null or an empty string');
    }
    _name = value /*!*/;
  }

  int get type => _type;

  set type(int /*?*/ value) {
    if (value == null || value < 0) {
      throw Exception('type must be defined and may not be < 0');
    }
    _type = value /*!*/;
  }

  int get flags => _flags;

  set flags(int /*?*/ value) {
    if (value == null || value < 0) {
      throw Exception('flags must be defined and may not be < 0');
    }
    _flags = value /*!*/;
  }

  IdUid /*?*/ get indexId => _indexId;

  set indexId(IdUid /*?*/ value) {
    if (value != null) {
      if (value.id == 0 || value.uid == 0) {
        throw Exception('indexId must contain valid ID & UID');
      }
    }
    _indexId = value /*!*/;
  }

  ModelProperty(this.id, String /*?*/ name, int /*?*/ type,
      {int flags = 0, String /*?*/ indexId, this.entity}) {
    this.name = name;
    this.type = type;
    this.flags = flags;
    this.indexId = indexId == null ? null : IdUid.fromString(indexId);
  }

  ModelProperty.fromMap(Map<String, dynamic> data, ModelEntity /*?*/ entity)
      : this(IdUid.fromString(data['id']), data['name'], data['type'],
            flags: data['flags'] ?? 0,
            indexId: data['indexId'],
            entity: entity);

  Map<String, dynamic> toMap() {
    final ret = <String, dynamic>{};
    ret['id'] = id.toString();
    ret['name'] = name;
    ret['type'] = type;
    if (flags != 0) ret['flags'] = flags;
    if (indexId != null) ret['indexId'] = indexId /*!*/ .toString();
    return ret;
  }

  bool containsUid(int searched) {
    return id.uid == searched;
  }

  bool hasFlag(int flag) {
    return (flags & flag) == flag;
  }

  bool hasIndexFlag() {
    return hasFlag(OBXPropertyFlags.INDEXED) ||
        hasFlag(OBXPropertyFlags.INDEX_HASH) ||
        hasFlag(OBXPropertyFlags.INDEX_HASH64);
  }

  void removeIndex() {
    if (_indexId != null) {
      entity.model.retiredIndexUids.add(_indexId.uid);
      indexId = null;
    }
  }

  @override
  String toString() {
    var result = 'property ${name}(${id})';
    result += ' type:${obxPropertyTypeToString(type)}';
    result += ' flags:${flags}';

    if (hasIndexFlag()) {
      result += ' index:' +
          (hasFlag(OBXPropertyFlags.INDEXED)
              ? 'value'
              : hasFlag(OBXPropertyFlags.INDEX_HASH)
                  ? 'hash'
                  : hasFlag(OBXPropertyFlags.INDEX_HASH64)
                      ? 'hash64'
                      : 'unknown');
    }

    return result;
  }
}
