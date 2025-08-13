import 'iduid.dart';

// ignore_for_file: public_member_api_docs

/// ModelRelation describes a standalone relation
class ModelRelation {
  IdUid id;

  late String _name;

  IdUid? _targetId;

  String? _targetName;

  /// The optional [ExternalName] of this relation.
  String? externalName;

  /// The optional [ExternalType] of this relation.
  int? externalType;

  // whether the user requested UID information (started a rename process)
  final bool uidRequest;

  String get name => _name;

  set name(String? value) {
    if (value == null || value.isEmpty) {
      throw ArgumentError('name must not be null or an empty string');
    }
    _name = value;
  }

  IdUid get targetId => _targetId!;

  set targetId(IdUid? value) {
    if (value == null || value.id == 0 || value.uid == 0) {
      throw ArgumentError('targetId must contain valid ID & UID');
    }
    _targetId = value;
  }

  String get targetName => _targetName!;

  set targetName(String? value) {
    if (value == null || value.isEmpty) {
      throw ArgumentError('targetName must not be null or an empty string');
    }
    _targetName = value;
  }

  // used in code generator
  ModelRelation.create(this.id, String? name,
      {String? targetId,
      String? targetName,
      String? externalName,
      int? externalType,
      this.uidRequest = false}) {
    this.name = name;
    if (targetId != null) this.targetId = IdUid.fromString(targetId);
    if (targetName != null) this.targetName = targetName;
    if (externalName != null) this.externalName = externalName;
    if (externalType != null) this.externalType = externalType;
  }

  // used in generated code
  ModelRelation(
      {required this.id,
      required String name,
      required IdUid targetId,
      this.externalName,
      this.externalType})
      : _name = name,
        _targetId = targetId,
        uidRequest = false;

  ModelRelation.fromMap(Map<String, dynamic> data)
      : this.create(IdUid.fromString(data[ModelRelationKey.id] as String?),
            data[ModelRelationKey.name] as String?,
            targetId: data[ModelRelationKey.targetId] as String?,
            targetName: data[ModelRelationKey.targetName] as String?,
            uidRequest: data[ModelRelationKey.uidRequest] as bool? ?? false,
            externalName: data[ModelRelationKey.externalName] as String?,
            externalType: data[ModelRelationKey.externalType] as int?);

  /// See [ModelEntity.toMap] for important details.
  ///
  /// Note that the order in which keys are written defines the order in the
  /// generated model JSON.
  Map<String, dynamic> toMap({bool forModelJson = false}) {
    final ret = <String, dynamic>{};
    ret[ModelRelationKey.id] = id.toString();
    ret[ModelRelationKey.name] = name;
    if (externalName != null) ret[ModelRelationKey.externalName] = externalName;
    if (externalType != null) ret[ModelRelationKey.externalType] = externalType;
    if (_targetId != null) {
      ret[ModelRelationKey.targetId] = _targetId.toString();
    }
    if (!forModelJson) {
      ret[ModelRelationKey.targetName] = _targetName;
      ret[ModelRelationKey.uidRequest] = uidRequest;
    }
    return ret;
  }

  @override
  String toString() =>
      'standalone relation $name($id) relTarget: $_targetName($_targetId)';
}

/// Map keys for properties of this relation.
class ModelRelationKey {
  static const String id = 'id';
  static const String name = 'name';
  static const String targetId = 'targetId';
  static const String targetName = 'targetName';
  static const String uidRequest = 'uidRequest';
  static const String externalType = 'externalType';
  static const String externalName = 'externalName';
}
