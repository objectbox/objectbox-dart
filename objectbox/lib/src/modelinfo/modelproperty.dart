import 'enums.dart';
import 'iduid.dart';
import 'model_hnsw_params.dart';
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
  ModelHnswParams? hnswParams;
  int? externalPropertyType;
  String? externalPropertyName;

  /// Type used in the source dart code - used by the code generator.
  /// Starts with [_fieldReadOnlyPrefix] if the field (currently IDs only) is
  /// read-only. Ends with `?` if the field is nullable.
  /// Note: must be included in to/fromMap to be handled `build_runner`.
  String? _dartFieldType;

  // whether the user requested UID information (started a rename process)
  final bool uidRequest;

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

  // Used to inform about an ID field that is read-only (needed for code-gen).
  // We're adding this prefix to [_dartFieldType] so that we don't have to do
  // the whole serialization-deserialization process for yet another field.
  static const _fieldReadOnlyPrefix = 'READ-ONLY ';

  bool get fieldIsReadOnly => _dartFieldType!.startsWith(_fieldReadOnlyPrefix);

  set fieldIsReadOnly(bool value) {
    if (fieldIsReadOnly == value) return;
    if (value) {
      _dartFieldType = _fieldReadOnlyPrefix + _dartFieldType!;
    } else {
      _dartFieldType = _dartFieldType!.substring(_fieldReadOnlyPrefix.length);
    }
  }

  String get fieldType => _dartFieldType!
      .replaceFirst('?', '', _dartFieldType!.length - 1)
      .replaceFirst(_fieldReadOnlyPrefix, '');

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

  // used in code generator
  ModelProperty.create(this.id, String? name, int? type,
      {int flags = 0,
      String? indexId,
      this.entity,
      String? dartFieldType,
      this.relationTarget,
      this.uidRequest = false})
      : _dartFieldType = dartFieldType {
    this.name = name;
    this.type = type;
    this.flags = flags;
    this.indexId = indexId == null ? null : IdUid.fromString(indexId);
  }

  // used in generated code
  ModelProperty(
      {required this.id,
      required String name,
      required int type,
      required int flags,
      IdUid? indexId,
      this.relationTarget,
      this.hnswParams,
      this.externalPropertyName,
      this.externalPropertyType})
      : _name = name,
        _type = type,
        _flags = flags,
        _indexId = indexId,
        uidRequest = false;

  ModelProperty.fromMap(Map<String, dynamic> data, this.entity)
      : id = IdUid.fromString(data['id'] as String?),
        relationTarget = data['relationTarget'] as String?,
        _dartFieldType = data['dartFieldType'] as String?,
        uidRequest = data['uidRequest'] as bool? ?? false,
        hnswParams = ModelHnswParams.fromMap(
            data['hnswParams'] as Map<String, dynamic>?),
        externalPropertyType = data['externalType'] as int?,
        externalPropertyName = data['externalName'] as String? {
    name = data['name'] as String?;
    type = data['type'] as int?;
    flags = data['flags'] as int? ?? 0;
    final indexId = data['indexId'] as String?;
    this.indexId = indexId == null ? null : IdUid.fromString(indexId);
  }

  Map<String, dynamic> toMap({bool forModelJson = false}) {
    final ret = <String, dynamic>{};
    ret['id'] = id.toString();
    ret['name'] = name;
    ret['type'] = type;
    if (flags != 0) ret['flags'] = flags;
    if (indexId != null) ret['indexId'] = indexId!.toString();
    if (relationTarget != null) ret['relationTarget'] = relationTarget;
    if (!forModelJson) {
      if (_dartFieldType != null) {
        ret['dartFieldType'] = _dartFieldType;
      }
      ret['uidRequest'] = uidRequest;
      if (hnswParams != null) {
        ret['hnswParams'] = hnswParams!.toMap();
      }
      if (externalPropertyType != null) {
        ret['externalType'] = externalPropertyType;
      }
      if (externalPropertyName != null) {
        ret['externalName'] = externalPropertyName;
      }
    }
    return ret;
  }

  bool hasFlag(int flag) => (flags & flag) == flag;

  bool hasIndexFlag() =>
      hasFlag(OBXPropertyFlags.INDEXED) ||
      hasFlag(OBXPropertyFlags.INDEX_HASH) ||
      hasFlag(OBXPropertyFlags.INDEX_HASH64);

  bool get isRelation => type == OBXPropertyType.Relation;

  bool get isSigned => !hasFlag(OBXPropertyFlags.UNSIGNED);

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
    if (!isSigned) result += ' unsigned';
    result += ' flags:$flags';

    if (hasIndexFlag() || hnswParams != null) {
      String type;
      if (hasFlag(OBXPropertyFlags.INDEXED)) {
        type = 'value';
      } else if (hasFlag(OBXPropertyFlags.INDEX_HASH)) {
        type = 'hash';
      } else if (hasFlag(OBXPropertyFlags.INDEX_HASH64)) {
        type = 'hash64';
      } else if (hnswParams != null) {
        type = 'hnsw';
      } else {
        type = 'unknown';
      }
      result += ' index:$type';
    }

    if (relationTarget != null) {
      result += ' relTarget:$relationTarget';
    }

    return result;
  }
}
