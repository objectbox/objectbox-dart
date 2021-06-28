import 'iduid.dart';

// ignore_for_file: public_member_api_docs

/// ModelRelation describes a standalone relation
class ModelRelation {
  IdUid id;

  late String _name;

  IdUid? _targetId;

  String? _targetName;

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
      {String? targetId, String? targetName, this.uidRequest = false}) {
    this.name = name;
    if (targetId != null) this.targetId = IdUid.fromString(targetId);
    if (targetName != null) this.targetName = targetName;
  }

  // used in generated code
  ModelRelation(
      {required this.id, required String name, required IdUid targetId})
      : _name = name,
        _targetId = targetId,
        uidRequest = false;

  ModelRelation.fromMap(Map<String, dynamic> data)
      : this.create(
            IdUid.fromString(data['id'] as String?), data['name'] as String?,
            targetId: data['targetId'] as String?,
            targetName: data['targetName'] as String?,
            uidRequest: data['uidRequest'] as bool? ?? false);

  Map<String, dynamic> toMap({bool forModelJson = false}) {
    final ret = <String, dynamic>{};
    ret['id'] = id.toString();
    ret['name'] = name;
    if (_targetId != null) ret['targetId'] = _targetId.toString();
    if (!forModelJson) {
      ret['targetName'] = _targetName;
      ret['uidRequest'] = uidRequest;
    }
    return ret;
  }

  @override
  String toString() =>
      'standalone relation $name($id) relTarget: $_targetName($_targetId)';
}
