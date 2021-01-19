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
  String /*?*/ relationTarget;

  /// Type used in the source dart code - used by the code generator.
  /// Note: must be included in to/fromMap to be handled `build_runner`.
  String /*?*/ dartFieldType;

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
      {int flags = 0,
      String /*?*/ indexId,
      this.entity,
      this.dartFieldType,
      this.relationTarget}) {
    this.name = name;
    this.type = type;
    this.flags = flags;
    this.indexId = indexId == null ? null : IdUid.fromString(indexId);
  }

  ModelProperty.fromMap(Map<String, dynamic> data, ModelEntity /*?*/ entity)
      : this(IdUid.fromString(data['id']), data['name'], data['type'],
            flags: data['flags'] ?? 0,
            indexId: data['indexId'],
            entity: entity,
            dartFieldType: data['dartFieldType'],
            relationTarget: data['relationTarget']);

  Map<String, dynamic> toMap({bool forModelJson = false}) {
    final ret = <String, dynamic>{};
    ret['id'] = id.toString();
    ret['name'] = name;
    ret['type'] = type;
    if (flags != 0) ret['flags'] = flags;
    if (indexId != null) ret['indexId'] = indexId /*!*/ .toString();
    if (relationTarget != null) ret['relationTarget'] = relationTarget;
    if (!forModelJson && dartFieldType != null) {
      ret['dartFieldType'] = dartFieldType;
    }
    return ret;
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

    if (relationTarget != null) {
      result += ' relTarget: ${relationTarget}';
    }

    return result;
  }
}
