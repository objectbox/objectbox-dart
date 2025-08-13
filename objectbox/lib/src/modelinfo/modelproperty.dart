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

  /// The optional [HnswIndex] parameters of this property.
  ModelHnswParams? hnswParams;

  /// The optional [ExternalName] of this property.
  String? externalName;

  /// The optional [ExternalType] of this property.
  int? externalType;

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
      this.externalName,
      this.externalType})
      : _name = name,
        _type = type,
        _flags = flags,
        _indexId = indexId,
        uidRequest = false;

  ModelProperty.fromMap(Map<String, dynamic> data, this.entity)
      : id = IdUid.fromString(data[ModelPropertyKey.id] as String?),
        relationTarget = data[ModelPropertyKey.relationTarget] as String?,
        _dartFieldType = data[ModelPropertyKey.dartFieldType] as String?,
        uidRequest = data[ModelPropertyKey.uidRequest] as bool? ?? false,
        hnswParams = ModelHnswParams.fromMap(
            data[ModelPropertyKey.hnswParams] as Map<String, dynamic>?),
        externalName = data[ModelPropertyKey.externalName] as String?,
        externalType = data[ModelPropertyKey.externalType] as int? {
    name = data[ModelPropertyKey.name] as String?;
    type = data[ModelPropertyKey.type] as int?;
    flags = data[ModelPropertyKey.flags] as int? ?? 0;
    final indexId = data[ModelPropertyKey.indexId] as String?;
    this.indexId = indexId == null ? null : IdUid.fromString(indexId);
  }

  /// See [ModelEntity.toMap] for important details.
  ///
  /// Note that the order in which keys are written defines the order in the
  /// generated model JSON.
  Map<String, dynamic> toMap({bool forModelJson = false}) {
    final ret = <String, dynamic>{};
    ret[ModelPropertyKey.id] = id.toString();
    ret[ModelPropertyKey.name] = name;
    if (indexId != null) ret[ModelPropertyKey.indexId] = indexId!.toString();
    ret[ModelPropertyKey.type] = type;
    if (externalName != null) ret[ModelPropertyKey.externalName] = externalName;
    if (externalType != null) ret[ModelPropertyKey.externalType] = externalType;
    if (flags != 0) ret[ModelPropertyKey.flags] = flags;
    if (relationTarget != null) {
      ret[ModelPropertyKey.relationTarget] = relationTarget;
    }
    if (!forModelJson) {
      if (_dartFieldType != null) {
        ret[ModelPropertyKey.dartFieldType] = _dartFieldType;
      }
      ret[ModelPropertyKey.uidRequest] = uidRequest;
      if (hnswParams != null) {
        ret[ModelPropertyKey.hnswParams] = hnswParams!.toMap();
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

/// Map keys for properties of this property.
class ModelPropertyKey {
  static const String id = 'id';
  static const String name = 'name';
  static const String indexId = 'indexId';
  static const String type = 'type';
  static const String flags = 'flags';
  static const String relationTarget = 'relationTarget';
  static const String dartFieldType = 'dartFieldType';
  static const String uidRequest = 'uidRequest';
  static const String hnswParams = 'hnswParams';
  static const String externalName = 'externalName';
  static const String externalType = 'externalType';
}
