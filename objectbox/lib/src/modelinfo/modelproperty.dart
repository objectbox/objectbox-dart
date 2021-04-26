import 'enums.dart';
import 'iduid.dart';
import 'modelentity.dart';

// ignore_for_file: public_member_api_docs

/// ModelProperty describes a single property of an entity.
class ModelProperty {
  IdUid id;

  late String _name;

  late int _type, _flags;
  IdUid? _indexId;
  ModelEntity? entity;
  String? relationTarget;

  /// Type used in the source dart code - used by the code generator.
  /// Note: must be included in to/fromMap to be handled `build_runner`.
  String? _dartFieldType;

  String get name => _name;

  set name(String? value) {
    if (value == null || value.isEmpty) {
      throw ArgumentError('name must not be null or an empty string');
    }
    _name = value;
  }

  int get type => _type;

  set type(int? value) {
    if (value == null || value < 0) {
      throw ArgumentError('type must be defined and may not be < 0');
    }
    _type = value;
  }

  int get flags => _flags;

  set flags(int? value) {
    if (value == null || value < 0) {
      throw ArgumentError('flags must be defined and may not be < 0');
    }
    _flags = value;
  }

  String get dartFieldType => _dartFieldType!;

  set dartFieldType(String value) => _dartFieldType = value;

  String get fieldType =>
      _dartFieldType!.replaceFirst('?', '', _dartFieldType!.length - 1);

  bool get fieldIsNullable =>
      _dartFieldType!.substring(_dartFieldType!.length - 1) == '?';

  IdUid? get indexId => _indexId;

  set indexId(IdUid? value) {
    if (value != null) {
      if (value.id == 0 || value.uid == 0) {
        throw ArgumentError('indexId must contain valid ID & UID');
      }
    }
    _indexId = value;
  }

  ModelProperty(this.id, String? name, int? type,
      {int flags = 0,
      String? indexId,
      this.entity,
      String? dartFieldType,
      this.relationTarget})
      : _dartFieldType = dartFieldType {
    this.name = name;
    this.type = type;
    this.flags = flags;
    this.indexId = indexId == null ? null : IdUid.fromString(indexId);
  }

  ModelProperty.fromMap(Map<String, dynamic> data, ModelEntity? entity)
      : this(IdUid.fromString(data['id'] as String?), data['name'] as String?,
            data['type'] as int?,
            flags: data['flags'] as int? ?? 0,
            indexId: data['indexId'] as String?,
            entity: entity,
            dartFieldType: data['dartFieldType'] as String?,
            relationTarget: data['relationTarget'] as String?);

  Map<String, dynamic> toMap({bool forModelJson = false}) {
    final ret = <String, dynamic>{};
    ret['id'] = id.toString();
    ret['name'] = name;
    ret['type'] = type;
    if (flags != 0) ret['flags'] = flags;
    if (indexId != null) ret['indexId'] = indexId!.toString();
    if (relationTarget != null) ret['relationTarget'] = relationTarget;
    if (!forModelJson && _dartFieldType != null) {
      ret['dartFieldType'] = _dartFieldType;
    }
    return ret;
  }

  bool hasFlag(int flag) => (flags & flag) == flag;

  bool hasIndexFlag() =>
      hasFlag(OBXPropertyFlags.INDEXED) ||
      hasFlag(OBXPropertyFlags.INDEX_HASH) ||
      hasFlag(OBXPropertyFlags.INDEX_HASH64);

  bool get isRelation => type == OBXPropertyType.Relation;

  void removeIndex() {
    if (_indexId != null) {
      entity!.model.retiredIndexUids.add(_indexId!.uid);
      indexId = null;
    }
  }

  @override
  String toString() {
    var result = 'property $name($id)';
    result += ' type:${obxPropertyTypeToString(type)}';
    result += ' flags:$flags';

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
      result += ' relTarget: $relationTarget';
    }

    return result;
  }
}
